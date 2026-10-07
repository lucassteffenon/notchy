import EventKit
import SwiftUI

// MARK: - Bateria

struct BatteryIndicator: View {
    @ObservedObject var battery: BatteryMonitor

    var body: some View {
        if battery.hasBattery {
            HStack(spacing: 4) {
                Text("\(battery.percent)%").monospacedDigit()
                Image(systemName: battery.symbol)
                    .foregroundStyle(battery.isPluggedIn ? .green : battery.percent <= 20 ? .red : .white)
            }
            .font(.system(size: 11, weight: .medium))
        }
    }
}

// MARK: - Calendário

struct CalendarPane: View {
    @ObservedObject var calendar: CalendarModel

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Date.now.formatted(.dateTime.weekday(.wide)).capitalized)
                    .font(.callout).foregroundStyle(.red)
                Text(Date.now.formatted(.dateTime.day()))
                    .font(.system(size: 38, weight: .semibold))
                Text(Date.now.formatted(.dateTime.month(.wide)).capitalized)
                    .font(.callout).foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 84, alignment: .leading)

            Group {
                switch calendar.status {
                case .unknown:
                    ProgressView().controlSize(.small)
                case .denied:
                    Text("Permita o acesso em Ajustes → Privacidade e Segurança → Calendários")
                        .font(.callout).foregroundStyle(.white.opacity(0.7))
                case .ready where calendar.events.isEmpty:
                    Text("Nada na agenda hoje nem amanhã 🎉")
                        .font(.callout).foregroundStyle(.white.opacity(0.7))
                case .ready:
                    eventList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear { calendar.load() }
    }

    private var eventList: some View {
        // Atualiza o "em X min" a cada minuto
        TimelineView(.everyMinute) { context in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(calendar.events, id: \.calendarItemIdentifier) { event in
                        EventRow(event: event, now: context.date)
                    }
                }
            }
        }
    }
}

struct EventRow: View {
    let event: EKEvent
    let now: Date

    private var dayLabel: String? {
        Calendar.current.isDateInToday(event.startDate) ? nil : "Amanhã"
    }

    private var timeLabel: String {
        if event.isAllDay { return "Dia todo" }
        if event.startDate <= now { return "Agora" }
        let minutes = Int(event.startDate.timeIntervalSince(now) / 60)
        if minutes < 60 && dayLabel == nil { return "em \(minutes + 1) min" }
        return event.startDate.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(nsColor: event.calendar.color))
                .frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "Sem título").font(.callout.weight(.medium)).lineLimit(1)
                Text([dayLabel, timeLabel].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(timeLabel == "Agora" ? .green : .white.opacity(0.6))
            }
        }
    }
}

// MARK: - Timer

struct TimerPane: View {
    @ObservedObject var timer: FocusTimer

    var body: some View {
        HStack(spacing: 22) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(timer.justFinished ? Color.green : Color.orange,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: timer.progress)
                Text(timer.justFinished ? "Acabou!" : timer.text)
                    .font(.system(size: 19, weight: .semibold).monospacedDigit())
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(FocusTimer.presets, id: \.self) { minutes in
                        Button("\(minutes) min") { timer.set(minutes: minutes) }
                            .controlSize(.small)
                    }
                }
                HStack(spacing: 10) {
                    Button(timer.isRunning ? "Pausar" : "Iniciar") {
                        timer.isRunning ? timer.pause() : timer.start()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(timer.isRunning ? .gray : .orange)
                    Button("Zerar") { timer.reset() }
                        .disabled(!timer.isActive)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
