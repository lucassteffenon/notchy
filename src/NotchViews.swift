import SwiftUI

/// Retângulo com as quinas de baixo arredondadas, colado no topo da tela.
struct NotchShape: Shape {
    var radius: CGFloat

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - radius))
        p.addQuadCurve(to: CGPoint(x: r.maxX - radius, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - radius), control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Botão de ícone: o retângulo inteiro em volta do ícone é clicável, com um fundo leve
/// ao passar o mouse (e ao clicar) para mostrar a área de clique.
struct IconButtonStyle: ButtonStyle {
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        IconButtonLabel(configuration: configuration, isSelected: isSelected)
    }
}

private struct IconButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    @State private var isHovering = false

    private var fill: Double {
        if configuration.isPressed { return 0.26 }
        if isSelected { return 0.18 }
        return isHovering ? 0.1 : 0
    }

    var body: some View {
        configuration.label
            .background(Color.white.opacity(fill), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: fill)
    }
}

struct NotchRootView: View {
    @ObservedObject var model: NotchModel

    private var size: CGSize {
        if model.isExpanded { return model.expandedSize }
        return CGSize(width: model.collapsedWidth, height: model.notchSize.height)
    }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(radius: model.isExpanded ? 24 : 10)
                .fill(Color.black)

            if model.isExpanded {
                ExpandedView(model: model)
                    .transition(.opacity)
            } else if let info = model.collapsedInfo {
                CollapsedView(model: model, info: info)
                    .frame(height: model.notchSize.height)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onDrop(of: [.fileURL], isTargeted: $model.isDropTargeted) { model.handleDrop($0) }
        .onChange(of: model.isDropTargeted) { _, targeted in
            if targeted { model.showShelf() }
        }
        .environment(\.colorScheme, .dark)
    }
}

/// Laterais do notch recolhido: um ícone à esquerda e um valor à direita.
private struct CollapsedView: View {
    @ObservedObject var model: NotchModel
    let info: CollapsedInfo

    var body: some View {
        HStack {
            switch info {
            case .battery:
                Image(systemName: model.battery.symbol)
                    .foregroundStyle(model.battery.isPluggedIn ? .green : .white)
                Spacer()
                Text("\(model.battery.percent)%").monospacedDigit()
            case .timerFinished:
                Image(systemName: "bell.fill")
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, isActive: true)
                Spacer()
                Text("0:00").monospacedDigit().foregroundStyle(.orange)
            case .timer:
                Image(systemName: model.timer.isRunning ? "timer" : "pause.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Text(model.timer.text).monospacedDigit()
            case .music:
                ArtworkView(image: model.nowPlaying.artwork, size: 18, radius: 4)
                Spacer()
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, isActive: true)
            case .shelf:
                Image(systemName: "tray.full.fill")
                Spacer()
                Text("\(model.items.count)").monospacedDigit()
            case .caffeine:
                Image(systemName: "cup.and.saucer.fill").foregroundStyle(.brown)
                Spacer()
                TimelineView(.everyMinute) { context in
                    Text(model.caffeine.shortRemaining(at: context.date)).monospacedDigit()
                }
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 12)
    }
}

private struct ExpandedView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        VStack(spacing: 0) {
            // Linha do notch: ícones dos dois lados, com o meio livre para o notch físico
            HStack(spacing: 0) {
                HStack(spacing: NotchModel.tabSpacing) {
                    ForEach(model.leftHeaderTabs, id: \.self) { tabButton($0) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Color.clear.frame(width: model.notchSize.width + 2 * NotchModel.notchGap)

                HStack(spacing: NotchModel.tabSpacing) {
                    ForEach(model.rightHeaderTabs, id: \.self) { tabButton($0) }
                    if model.isEnabled(.battery) {
                        BatteryIndicator(battery: model.battery)
                            .padding(.leading, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: model.notchSize.height)
            .font(.system(size: 13, weight: .medium))

            Group {
                switch model.currentTab {
                case .home: HomePane(model: model)
                case .settings: SettingsPane(model: model)
                case .module(.music): MusicPane(nowPlaying: model.nowPlaying)
                case .module(.calendar): CalendarPane(calendar: model.calendar)
                case .module(.timer): TimerPane(timer: model.timer)
                case .module(.shelf): ShelfView(model: model)
                case .module(.camera): CameraPane(camera: model.camera)
                case .module(.keyboard): KeyboardPane(model: model)
                case .module(.caffeine): CaffeinePane(caffeine: model.caffeine)
                case .module(.battery): EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 8)
        }
        .padding(.horizontal, NotchModel.sidePadding)
        .padding(.bottom, 12)
        .foregroundStyle(.white)
    }

    private func tabButton(_ tab: NotchTab) -> some View {
        Button {
            // As configurações são maiores: anima a troca de tamanho
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { model.tab = tab }
        } label: {
            Image(systemName: tab.icon)
                .frame(width: NotchModel.tabWidth, height: 24)
        }
        .buttonStyle(IconButtonStyle(isSelected: model.currentTab == tab))
    }
}

// MARK: - Música

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

private struct MusicPane: View {
    @ObservedObject var nowPlaying: NowPlaying

    var body: some View {
        HStack(spacing: 18) {
            ArtworkView(image: nowPlaying.artwork, size: 100, radius: 12)

            VStack(alignment: .leading, spacing: 4) {
                if nowPlaying.hasTrack {
                    Text(nowPlaying.title).font(.headline).lineLimit(1)
                    Text(nowPlaying.artist).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    Text(nowPlaying.player?.displayName ?? "")
                        .font(.caption).foregroundStyle(.white.opacity(0.4))
                } else {
                    Text("Nada tocando").font(.headline)
                    Text("Abra o Spotify ou o Música").foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 4)
                HStack(spacing: 10) {
                    controlButton("backward.fill", size: 16) { nowPlaying.send(.previous) }
                    controlButton(nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 24) {
                        nowPlaying.send(.playPause)
                    }
                    controlButton("forward.fill", size: 16) { nowPlaying.send(.next) }
                }
            }
            Spacer(minLength: 0)
        }
        .onAppear { nowPlaying.refresh() }
    }

    private func controlButton(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(width: 38, height: 32)
        }
        .buttonStyle(IconButtonStyle())
    }
}

// MARK: - Prateleira de arquivos

private struct ShelfView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        if model.items.isEmpty {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundStyle(model.isDropTargeted ? .white : .white.opacity(0.35))
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc").font(.system(size: 26))
                        Text("Arraste arquivos para cá").font(.callout)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
        } else {
            HStack(alignment: .top, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.items) { item in
                            ShelfItemView(item: item) { model.remove(item) }
                        }
                    }
                    .padding(.top, 6)
                }
                Button("Limpar") { model.clearShelf() }
                    .controlSize(.small)
            }
        }
    }
}

private struct ShelfItemView: View {
    let item: ShelfItem
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 44, height: 44)
            Text(item.name)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 70)
        }
        .padding(6)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(5)
            }
            .buttonStyle(IconButtonStyle())
            .offset(x: 10, y: -10)
        }
        .onDrag {
            // Entrega o próprio arquivo (file URL), assim o destino recebe o nome original
            let provider = NSItemProvider(object: item.url as NSURL)
            provider.suggestedName = item.url.lastPathComponent
            return provider
        }
        .contextMenu {
            Button("Mostrar no Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Button("Remover da prateleira", action: onRemove)
        }
    }
}

// MARK: - Câmera

private struct CameraPane: View {
    @ObservedObject var camera: CameraController

    var body: some View {
        CameraBox(camera: camera)
            .frame(width: 180)
    }
}

// MARK: - Teclado

private struct KeyboardPane: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        VStack(spacing: 6) {
            if model.isLocked {
                Text("🧽 Teclado travado — pode limpar").font(.headline)
                Text("Destrava sozinho em \(model.secondsLeft)s")
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
                Button("Destravar agora") { model.unlockKeyboard() }
                    .buttonStyle(.borderedProminent)
            } else {
                Text("Travar o teclado para limpar").font(.headline)
                Text("Destrava sozinho em \(model.autoUnlockSeconds)s ou clicando aqui")
                    .foregroundStyle(.white.opacity(0.6))
                Button("Travar teclado") { model.lockKeyboard() }
                    .buttonStyle(.borderedProminent)
                if let error = model.lockError {
                    HStack {
                        Text(error).font(.caption).foregroundStyle(.orange)
                        Button("Abrir Ajustes") { model.openAccessibilitySettings() }
                            .controlSize(.small)
                    }
                }
            }
        }
    }
}
