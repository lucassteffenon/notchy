import AppKit
import Combine
import EventKit
import SwiftUI

/// O que aparece nas laterais do notch recolhido.
enum CollapsedInfo {
    case battery, meeting(EKEvent), timerFinished, timer, music, shelf, caffeine
}

struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    /// Nome como o Finder mostra (respeita extensão oculta e nomes localizados).
    var name: String { FileManager.default.displayName(atPath: url.path) }

    /// Falso se o arquivo foi apagado ou levado para um lugar onde não dá para achar.
    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }
}

/// Estado compartilhado entre o painel (AppKit) e as views (SwiftUI).
final class NotchModel: ObservableObject {
    @Published var isExpanded = false
    @Published var tab: NotchTab = .home
    @Published var isDropTargeted = false
    @Published var items: [ShelfItem] = [] { didSet { saveShelf() } }
    @Published var isLocked = false
    @Published var secondsLeft = 0
    @Published var lockError: String?
    @Published var notchSize = CGSize(width: 190, height: 24)

    /// Tamanho do conteúdo (abaixo da linha do notch): compacto nas abas, maior nas configurações.
    /// A largura compacta é um mínimo; ela cresce se os ícones do cabeçalho precisarem.
    static let compactContent = CGSize(width: 520, height: 130)
    static let settingsContent = CGSize(width: 680, height: 170)

    // Medidas do cabeçalho, que divide os ícones dos dois lados do notch físico
    static let tabWidth: CGFloat = 26
    static let tabSpacing: CGFloat = 2
    static let batteryWidth: CGFloat = 58
    static let sidePadding: CGFloat = 18
    static let notchGap: CGFloat = 10
    let autoUnlockSeconds = 60

    let camera = CameraController()
    let nowPlaying = NowPlaying()
    let battery = BatteryMonitor()
    let calendar = CalendarModel()
    let timer = FocusTimer()
    let caffeine = Caffeine()
    let settings = NotchSettings()
    private let blocker = KeyboardBlocker()
    private var unlockTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private let shelfKey = "shelfBookmarks"

    init() {
        items = loadShelf()
        // Repassa mudanças dos módulos para quem observa o modelo (notch recolhido, abas)
        Publishers.MergeMany([
            nowPlaying.objectWillChange, battery.objectWillChange, timer.objectWillChange,
            caffeine.objectWillChange, settings.objectWillChange, calendar.objectWillChange,
        ])
        .sink { [weak self] _ in self?.objectWillChange.send() }
        .store(in: &cancellables)

        // O aviso de reunião precisa da agenda carregada mesmo sem abrir a aba
        if isEnabled(.calendar) { calendar.load() }
    }

    // MARK: Módulos e abas

    func isEnabled(_ module: NotchModule) -> Bool { settings.isEnabled(module) }

    /// Abas da esquerda: Início + módulos ligados.
    var tabs: [NotchTab] {
        [.home] + NotchModule.allCases.filter { $0.hasTab && isEnabled($0) }.map(NotchTab.module)
    }

    /// Aba exibida; volta para Início se o módulo da aba atual foi desligado.
    var currentTab: NotchTab {
        if case .module(let module) = tab, !isEnabled(module) { return .home }
        return tab
    }

    func setEnabled(_ module: NotchModule, _ on: Bool) {
        settings.setEnabled(module, on)
        guard !on else { return moduleTurnedOn(module) }
        // Desligar um módulo também encerra o que ele estiver fazendo
        switch module {
        case .timer: timer.reset()
        case .caffeine: caffeine.deactivate()
        case .keyboard: unlockKeyboard()
        default: break
        }
    }

    private func moduleTurnedOn(_ module: NotchModule) {
        switch module {
        case .calendar: calendar.load()
        default: break
        }
    }

    func showShelf() {
        if isEnabled(.shelf) { tab = .module(.shelf) }
    }

    /// Prioridade: aviso do carregador, reunião, timer, música, prateleira, cafeína.
    var collapsedInfo: CollapsedInfo? {
        if isEnabled(.battery) && battery.showsAlert { return .battery }
        if isEnabled(.calendar), let event = calendar.upcomingMeeting() { return .meeting(event) }
        if isEnabled(.timer) && timer.justFinished { return .timerFinished }
        if isEnabled(.timer) && timer.isActive { return .timer }
        if isEnabled(.music) && nowPlaying.isPlaying { return .music }
        if isEnabled(.shelf) && !items.isEmpty { return .shelf }
        if isEnabled(.caffeine) && caffeine.isActive { return .caffeine }
        return nil
    }

    var showsCollapsedInfo: Bool { collapsedInfo != nil }

    var collapsedWidth: CGFloat {
        notchSize.width + (showsCollapsedInfo ? 110 : 0)
    }

    /// Ícones do cabeçalho: abas + configurações, divididos entre os lados do notch.
    var headerTabs: [NotchTab] { tabs + [.settings] }
    var leftHeaderTabs: [NotchTab] { Array(headerTabs.prefix((headerTabs.count + 1) / 2)) }
    var rightHeaderTabs: [NotchTab] { Array(headerTabs.dropFirst((headerTabs.count + 1) / 2)) }

    private func iconsWidth(_ count: Int) -> CGFloat {
        CGFloat(count) * Self.tabWidth + CGFloat(max(0, count - 1)) * Self.tabSpacing
    }

    /// Largura mínima para que nenhum ícone fique escondido atrás do notch.
    private var headerWidth: CGFloat {
        let left = iconsWidth(leftHeaderTabs.count)
        let right = iconsWidth(rightHeaderTabs.count) + (isEnabled(.battery) ? Self.batteryWidth : 0)
        return notchSize.width + 2 * (max(left, right) + Self.sidePadding + Self.notchGap)
    }

    var expandedSize: CGSize { size(for: currentTab) }

    /// Maior tamanho possível; o painel tem esse tamanho e a forma preta anima dentro dele.
    var maxExpandedSize: CGSize { size(for: .settings) }

    private func size(for tab: NotchTab) -> CGSize {
        let content = tab == .settings ? Self.settingsContent : Self.compactContent
        return CGSize(width: max(content.width, headerWidth), height: notchSize.height + content.height)
    }

    // MARK: Prateleira

    func add(urls: [URL]) {
        for url in urls {
            // O Finder às vezes entrega URLs de referência (file:///.file/id=...), sem o nome real
            let resolved = ((url as NSURL).filePathURL ?? url).standardizedFileURL
            if !items.contains(where: { $0.url == resolved }) {
                items.append(ShelfItem(url: resolved))
            }
        }
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearShelf() {
        items.removeAll()
    }

    /// Salva bookmarks (e não só caminhos): assim o arquivo é encontrado mesmo se for movido ou renomeado.
    private func saveShelf() {
        let bookmarks = items.compactMap { try? $0.url.bookmarkData() }
        UserDefaults.standard.set(bookmarks, forKey: shelfKey)
    }

    private func loadShelf() -> [ShelfItem] {
        let bookmarks = UserDefaults.standard.array(forKey: shelfKey) as? [Data] ?? []
        return bookmarks.compactMap { data in
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else { return nil }
            return ShelfItem(url: url.standardizedFileURL)
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard isEnabled(.shelf) else { return false }
        tab = .module(.shelf)
        var accepted = false
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            accepted = true
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                guard let url, url.isFileURL else { return }
                DispatchQueue.main.async { self?.add(urls: [url]) }
            }
        }
        return accepted
    }

    // MARK: Bloqueio do teclado

    func lockKeyboard() {
        guard KeyboardBlocker.hasAccessibility(prompt: true) else {
            lockError = "Ative o Notchy em Ajustes → Privacidade e Segurança → Acessibilidade."
            return
        }
        guard blocker.lock() else {
            lockError = "Não deu para travar. Reabra o app depois de dar a permissão."
            return
        }
        lockError = nil
        isLocked = true
        secondsLeft = autoUnlockSeconds

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.secondsLeft -= 1
            if self.secondsLeft <= 0 { self.unlockKeyboard() }
        }
        RunLoop.main.add(timer, forMode: .common)
        unlockTimer = timer
    }

    func unlockKeyboard() {
        unlockTimer?.invalidate()
        unlockTimer = nil
        blocker.unlock()
        isLocked = false
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
