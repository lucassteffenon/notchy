import SwiftUI

/// Aba Início: mini-widgets escolhidos nas configurações.
struct HomePane: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        let widgets = model.settings.visibleWidgets
        if widgets.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2").font(.system(size: 26))
                Text("Escolha os widgets da Início nas configurações").font(.callout)
                Button("Abrir configurações") { model.tab = .settings }
                    .controlSize(.small)
            }
            .foregroundStyle(.white.opacity(0.7))
        } else {
            HStack(spacing: 10) {
                ForEach(widgets) { widget(for: $0) }
            }
        }
    }

    @ViewBuilder
    private func widget(for module: NotchModule) -> some View {
        switch module {
        case .music: MusicWidget(nowPlaying: model.nowPlaying)
        case .calendar: CalendarWidget(calendar: model.calendar)
        case .timer: TimerWidget(timer: model.timer)
        case .camera: CameraWidget(camera: model.camera)
        case .keyboard: KeyboardWidget(model: model)
        case .caffeine: CaffeineWidget(caffeine: model.caffeine)
        case .shelf, .battery: EmptyView()
        }
    }
}

private struct WidgetCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct MusicWidget: View {
    @ObservedObject var nowPlaying: NowPlaying

    var body: some View {
        WidgetCard {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ArtworkView(image: nowPlaying.artwork, size: 38, radius: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(nowPlaying.hasTrack ? nowPlaying.title : "Nada tocando")
                            .font(.caption.weight(.semibold)).lineLimit(1)
                        Text(nowPlaying.artist)
                            .font(.caption2).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 4) {
                    button("backward.fill", size: 13) { nowPlaying.send(.previous) }
                    button(nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 20) {
                        nowPlaying.send(.playPause)
                    }
                    button("forward.fill", size: 13) { nowPlaying.send(.next) }
                }
            }
        }
        .onAppear { nowPlaying.refresh() }
    }

    private func button(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(width: 30, height: 28)
        }
        .buttonStyle(IconButtonStyle())
    }
}

private struct CalendarWidget: View {
    @ObservedObject var calendar: CalendarModel

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day()).capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                switch calendar.status {
                case .unknown:
                    ProgressView().controlSize(.small)
                case .denied:
                    Text("Sem acesso ao calendário").font(.caption)
                case .ready where calendar.events.isEmpty:
                    Text("Agenda livre 🎉").font(.caption)
                case .ready:
                    TimelineView(.everyMinute) { context in
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(calendar.events.prefix(2), id: \.calendarItemIdentifier) { event in
                                EventRow(event: event, now: context.date)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { calendar.load() }
    }
}

private struct TimerWidget: View {
    @ObservedObject var timer: FocusTimer

    var body: some View {
        WidgetCard {
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: timer.progress)
                        .stroke(timer.justFinished ? Color.green : Color.orange,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(timer.justFinished ? "Fim!" : timer.text)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                }
                .frame(width: 54, height: 54)

                HStack(spacing: 6) {
                    Button { timer.isRunning ? timer.pause() : timer.start() } label: {
                        Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                            .frame(width: 32, height: 26)
                    }
                    Button { timer.reset() } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 32, height: 26)
                    }
                    .disabled(!timer.isActive)
                }
                .buttonStyle(IconButtonStyle())
                .font(.system(size: 15))
            }
        }
    }
}

private struct CameraWidget: View {
    @ObservedObject var camera: CameraController

    var body: some View {
        CameraBox(camera: camera, compact: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct KeyboardWidget: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        WidgetCard {
            VStack(spacing: 8) {
                Image(systemName: model.isLocked ? "lock.fill" : "keyboard")
                    .font(.system(size: 26))
                if model.isLocked {
                    Text("Destrava em \(model.secondsLeft)s").font(.caption).monospacedDigit()
                    Button("Destravar") { model.unlockKeyboard() }
                } else if model.lockError != nil {
                    Text("Precisa de permissão").font(.caption).foregroundStyle(.orange)
                    Button("Ver detalhes") { model.tab = .module(.keyboard) }
                } else {
                    Text("Limpar teclado").font(.caption)
                    Button("Travar") { model.lockKeyboard() }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

private struct CaffeineWidget: View {
    @ObservedObject var caffeine: Caffeine

    var body: some View {
        WidgetCard {
            Button { caffeine.toggle() } label: {
                VStack(spacing: 6) {
                    Image(systemName: caffeine.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .font(.system(size: 30))
                        .foregroundStyle(caffeine.isActive ? CaffeinePane.tint : .white.opacity(0.7))
                    Text(caffeine.isActive ? "Acordado" : "Cafeína").font(.caption.weight(.semibold))
                    TimelineView(.everyMinute) { context in
                        Text(caffeine.isActive ? caffeine.shortRemaining(at: context.date) : "desligada")
                            .font(.caption2).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
