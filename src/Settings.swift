import Foundation
import ServiceManagement

/// Cada função do Notchy é um módulo que pode ser ligado/desligado nas configurações.
enum NotchModule: String, CaseIterable, Identifiable {
    case music, calendar, timer, shelf, camera, keyboard, caffeine, battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: "Música"
        case .calendar: "Calendário"
        case .timer: "Timer"
        case .shelf: "Arquivos"
        case .camera: "Câmera"
        case .keyboard: "Teclado"
        case .caffeine: "Cafeína"
        case .battery: "Bateria"
        }
    }

    var icon: String {
        switch self {
        case .music: "music.note"
        case .calendar: "calendar"
        case .timer: "timer"
        case .shelf: "tray.full"
        case .camera: "video"
        case .keyboard: "keyboard"
        case .caffeine: "cup.and.saucer"
        case .battery: "battery.75"
        }
    }

    /// A bateria só aparece no cabeçalho e nos avisos; não tem aba própria.
    var hasTab: Bool { self != .battery }

    /// Módulos que têm um mini-widget para a aba Início.
    var hasWidget: Bool {
        switch self {
        case .music, .calendar, .timer, .camera, .keyboard, .caffeine: true
        case .shelf, .battery: false
        }
    }
}

enum NotchTab: Hashable {
    case home, module(NotchModule), settings

    var icon: String {
        switch self {
        case .home: "house"
        case .module(let module): module.icon
        case .settings: "gearshape"
        }
    }
}

/// Preferências salvas no UserDefaults.
final class NotchSettings: ObservableObject {
    static let maxHomeWidgets = 3

    @Published private(set) var enabled: Set<NotchModule> { didSet { save() } }
    @Published private(set) var homeWidgets: [NotchModule] { didSet { save() } }
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var launchAtLoginNote: String?

    private let defaults = UserDefaults.standard
    private let enabledKey = "enabledModules"
    private let homeKey = "homeWidgets"

    init() {
        if let saved = defaults.stringArray(forKey: enabledKey) {
            enabled = Set(saved.compactMap(NotchModule.init(rawValue:)))
        } else {
            enabled = Set(NotchModule.allCases)
        }
        if let saved = defaults.stringArray(forKey: homeKey) {
            homeWidgets = saved.compactMap(NotchModule.init(rawValue:))
        } else {
            homeWidgets = [.timer, .camera, .calendar]
        }
    }

    func isEnabled(_ module: NotchModule) -> Bool { enabled.contains(module) }

    func isOnHome(_ module: NotchModule) -> Bool { homeWidgets.contains(module) }

    var canAddToHome: Bool { homeWidgets.filter(isEnabled).count < Self.maxHomeWidgets }

    /// Widgets que aparecem na Início (só de módulos ligados), na ordem escolhida.
    var visibleWidgets: [NotchModule] {
        Array(homeWidgets.filter(isEnabled).prefix(Self.maxHomeWidgets))
    }

    /// Widgets que ainda podem ser adicionados à Início.
    var availableWidgets: [NotchModule] {
        NotchModule.allCases.filter { $0.hasWidget && isEnabled($0) && !isOnHome($0) }
    }

    /// Reordena a Início: coloca `module` na posição de `target`.
    func moveHome(_ module: NotchModule, before target: NotchModule) {
        guard module != target, let from = homeWidgets.firstIndex(of: module) else { return }
        var widgets = homeWidgets
        widgets.remove(at: from)
        let to = widgets.firstIndex(of: target) ?? widgets.endIndex
        widgets.insert(module, at: from <= to ? to + 1 : to)
        homeWidgets = widgets
    }

    func setEnabled(_ module: NotchModule, _ on: Bool) {
        if on { enabled.insert(module) } else { enabled.remove(module) }
    }

    func toggleHome(_ module: NotchModule) {
        if let index = homeWidgets.firstIndex(of: module) {
            homeWidgets.remove(at: index)
        } else if canAddToHome && module.hasWidget {
            homeWidgets.append(module)
        }
    }

    /// Registra o Notchy como item de login do macOS.
    func setLaunchAtLogin(_ on: Bool) {
        let service = SMAppService.mainApp
        do {
            if on { try service.register() } else { try service.unregister() }
        } catch {
            launchAtLoginNote = "Não deu: \(error.localizedDescription)"
        }
        launchAtLogin = service.status == .enabled
        if service.status == .requiresApproval {
            launchAtLoginNote = "Aprove o Notchy em Ajustes → Geral → Itens de Início"
            SMAppService.openSystemSettingsLoginItems()
        } else if launchAtLogin || !on {
            launchAtLoginNote = nil
        }
    }

    private func save() {
        defaults.set(enabled.map(\.rawValue), forKey: enabledKey)
        defaults.set(homeWidgets.map(\.rawValue), forKey: homeKey)
    }
}
