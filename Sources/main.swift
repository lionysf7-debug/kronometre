// Kronometre — menü çubuğunda geçen süreyi gösteren küçük kronometre.
//   Sol tık  → başlat / duraklat
//   Sağ tık  → menü (Sıfırla, Açılışta başlat, Çık)
import AppKit
import ServiceManagement

@MainActor
final class Stopwatch {
    private let defaults = UserDefaults.standard
    // Süre, sayaç artırılarak değil "başlama anı"ndan hesaplanır: uyku ve yeniden
    // başlatmalar süreyi bozmaz.
    private(set) var startDate: Date? { didSet { save() } }
    private(set) var accumulated: TimeInterval { didSet { save() } }

    // Kayıtlı değerler bozuksa (NaN, sonsuz, 100 yıldan uzun) Int'e çevirirken çökmesin diye sıfırlanır.
    private static let maxInterval: TimeInterval = 100 * 365 * 24 * 3600

    init() {
        startDate = defaults.object(forKey: "startDate") as? Date
        let saved = defaults.double(forKey: "accumulated")
        accumulated = (0...Self.maxInterval).contains(saved) ? saved : 0
    }

    var isRunning: Bool { startDate != nil }
    // Saat geri alınırsa başlama anı gelecekte kalır; süre eksiye düşmesin.
    var elapsed: TimeInterval {
        min(Self.maxInterval, max(0, accumulated + (startDate.map { Date().timeIntervalSince($0) } ?? 0)))
    }

    func toggle() {
        if startDate != nil {
            accumulated = elapsed   // sınırlanmış değer kaydedilir: saat geri alınsa da eksiye düşmez
            startDate = nil
        } else {
            startDate = Date()
        }
    }

    func reset() {
        startDate = nil
        accumulated = 0
    }

    private func save() {
        defaults.set(startDate, forKey: "startDate")
        defaults.set(accumulated, forKey: "accumulated")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let stopwatch = Stopwatch()
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var ticker: Timer?
    private var lastTitle = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeading
        button.toolTip = "Sol tık: başlat/duraklat · Sağ tık: menü"

        menu.delegate = self
        refresh()
        if stopwatch.isRunning { startTicker() }
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            item.menu = menu
            item.button?.performClick(nil)
        } else {
            toggle()
        }
    }

    @objc private func toggle() {
        stopwatch.toggle()
        stopwatch.isRunning ? startTicker() : stopTicker()
        refresh()
    }

    @objc private func reset() {
        stopwatch.reset()
        stopTicker()
        refresh()
    }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Açılışta başlatma ayarlanamadı"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: Menü

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: stopwatch.isRunning ? "Duraklat" : "Başlat", action: #selector(toggle), keyEquivalent: "")
        menu.addItem(withTitle: "Sıfırla", action: #selector(reset), keyEquivalent: "")
            .isEnabled = stopwatch.elapsed > 0
        menu.addItem(.separator())
        let login = menu.addItem(withTitle: "Açılışta başlat", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Kronometre'den Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            .target = NSApp
        for entry in menu.items where entry.target == nil && entry.action != nil { entry.target = self }
    }

    // Menü kapanınca sol tık yeniden başlat/duraklat olsun diye menüyü çıkarıyoruz.
    func menuDidClose(_ menu: NSMenu) {
        item.menu = nil
    }

    // MARK: Görünüm

    private func startTicker() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 0.2, repeats: true) { _ in
            MainActor.assumeIsolated { self.refresh() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common) // menü açıkken de akmaya devam etsin
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func refresh() {
        guard let button = item.button else { return }
        let running = stopwatch.isRunning
        let elapsed = stopwatch.elapsed
        let symbol = running ? "stopwatch.fill" : (elapsed > 0 ? "pause.circle" : "stopwatch")
        let title = elapsed > 0 || running ? " " + Self.format(elapsed) : ""
        let key = symbol + title
        guard key != lastTitle else { return }
        lastTitle = key

        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Kronometre")
        image?.isTemplate = true
        button.image = image
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: running ? NSColor.labelColor : NSColor.secondaryLabelColor,
        ])
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

@main
struct KronometreApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // Dock'ta simge yok
        app.run()
    }
}
