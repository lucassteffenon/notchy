import SwiftUI

// MARK: - Configurações

enum SettingsSection: CaseIterable {
    case modules, home, general

    var title: String {
        switch self {
        case .modules: "Módulos"
        case .home: "Início"
        case .general: "Geral"
        }
    }

    var icon: String {
        switch self {
        case .modules: "square.grid.2x2"
        case .home: "house"
        case .general: "gearshape"
        }
    }
}

extension NotchModule {
    /// Cor de destaque de cada módulo nas configurações.
    var tint: Color {
        switch self {
        case .music: .pink
        case .calendar: .red
        case .timer: .orange
        case .shelf: .blue
        case .camera: .green
        case .keyboard: .teal
        case .caffeine: CaffeinePane.tint
        case .battery: .mint
        }
    }
}

struct SettingsPane: View {
    @ObservedObject var model: NotchModel
    @State private var section: SettingsSection

    init(model: NotchModel, section: SettingsSection = .modules) {
        self.model = model
        _section = State(initialValue: section)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(SettingsSection.allCases, id: \.self) { item in
                    Button { section = item } label: {
                        Label(item.title, systemImage: item.icon)
                            .font(.callout.weight(section == item ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(section == item ? Color.white.opacity(0.13) : .clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(section == item ? .white : .white.opacity(0.6))
                }
                Spacer(minLength: 0)
            }
            .frame(width: 108)

            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)

            Group {
                switch section {
                case .modules: ModulesSection(model: model)
                case .home: HomeSection(settings: model.settings)
                case .general: GeneralSection(settings: model.settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).font(.callout.weight(.semibold))
            Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.45))
        }
    }
}

// MARK: Módulos

private struct ModulesSection: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Módulos", subtitle: "Toque para ligar ou desligar")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(NotchModule.allCases) { module in
                    ModuleTile(module: module, isOn: model.isEnabled(module)) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            model.setEnabled(module, !model.isEnabled(module))
                        }
                    }
                }
            }
        }
    }
}

private struct ModuleTile: View {
    let module: NotchModule
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: module.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isOn ? module.tint : .white.opacity(0.4))
                    .frame(height: 20)
                Text(module.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isOn ? .white : .white.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isOn ? module.tint.opacity(0.16) : Color.white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isOn ? module.tint.opacity(0.5) : Color.white.opacity(0.08))
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(isOn ? Color.green : Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)
                    .padding(7)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isOn ? "Desligar \(module.title)" : "Ligar \(module.title)")
    }
}

// MARK: Início

private struct HomeSection: View {
    @ObservedObject var settings: NotchSettings

    var body: some View {
        let widgets = settings.visibleWidgets
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Widgets da Início",
                          subtitle: "\(widgets.count) de \(NotchSettings.maxHomeWidgets) · arraste para reordenar")

            HStack(spacing: 8) {
                ForEach(0..<NotchSettings.maxHomeWidgets, id: \.self) { index in
                    if index < widgets.count {
                        HomeSlot(module: widgets[index], settings: settings)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(.white.opacity(0.2))
                            .frame(height: 50)
                            .overlay { Text("Vazio").font(.caption).foregroundStyle(.white.opacity(0.3)) }
                    }
                }
            }

            if !settings.availableWidgets.isEmpty {
                HStack(spacing: 6) {
                    Text("Adicionar").font(.caption).foregroundStyle(.white.opacity(0.45))
                    ForEach(settings.availableWidgets) { module in
                        Button { settings.toggleHome(module) } label: {
                            Label(module.title, systemImage: "plus")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!settings.canAddToHome)
                        .opacity(settings.canAddToHome ? 1 : 0.4)
                    }
                }
            }
        }
    }
}

private struct HomeSlot: View {
    let module: NotchModule
    @ObservedObject var settings: NotchSettings

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: module.icon).foregroundStyle(module.tint)
            Text(module.title).font(.caption.weight(.medium)).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(module.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(module.tint.opacity(0.5)) }
        .overlay(alignment: .topTrailing) {
            Button { settings.toggleHome(module) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(4)
            }
            .buttonStyle(IconButtonStyle())
            .padding(1)
            .help("Tirar da Início")
        }
        .draggable(module.rawValue)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let dragged = NotchModule(rawValue: raw) else { return false }
            withAnimation(.easeOut(duration: 0.15)) { settings.moveHome(dragged, before: module) }
            return true
        }
    }
}

// MARK: Geral

private struct GeneralSection: View {
    @ObservedObject var settings: NotchSettings

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingCard(icon: "power", tint: .green, title: "Abrir ao iniciar o Mac",
                        subtitle: settings.launchAtLoginNote ?? "O Notchy abre sozinho quando você liga o Mac",
                        warning: settings.launchAtLoginNote != nil) {
                Toggle("", isOn: Binding(get: { settings.launchAtLogin },
                                         set: { settings.setLaunchAtLogin($0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            SettingCard(icon: "sparkles", tint: .purple, title: "Notchy \(version)",
                        subtitle: "Seu notch, com superpoderes") {
                Button("Sair do Notchy") { NSApp.terminate(nil) }
                    .controlSize(.small)
            }
        }
    }
}

private struct SettingCard<Trailing: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    var warning = false
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(warning ? Color.orange : Color.white.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Cafeína

struct CaffeinePane: View {
    static let tint = Color(red: 0.86, green: 0.62, blue: 0.38)

    @ObservedObject var caffeine: Caffeine

    var body: some View {
        HStack(spacing: 24) {
            Button { caffeine.toggle() } label: {
                Image(systemName: caffeine.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 36))
                    .foregroundStyle(caffeine.isActive ? Self.tint : .white.opacity(0.7))
                    .frame(width: 90, height: 90)
                    .background(Color.white.opacity(caffeine.isActive ? 0.14 : 0.07), in: Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text(caffeine.isActive ? "O Mac não vai dormir" : "Cafeína desligada")
                    .font(.headline)
                Text(subtitle).foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 8) {
                    ForEach(Caffeine.durations, id: \.label) { option in
                        Button(option.label) { caffeine.activate(minutes: option.minutes) }
                            .controlSize(.small)
                    }
                    if caffeine.isActive {
                        Button("Desligar") { caffeine.deactivate() }
                            .controlSize(.small)
                            .tint(.red)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        guard caffeine.isActive else { return "Mantém a tela acesa e o Mac acordado" }
        guard let end = caffeine.endDate else { return "Sem limite de tempo" }
        return "Até \(end.formatted(date: .omitted, time: .shortened))"
    }
}
