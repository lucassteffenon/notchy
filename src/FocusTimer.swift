import AppKit

/// Timer regressivo (estilo Pomodoro) que toca um som ao terminar.
final class FocusTimer: ObservableObject {
    static let presets = [5, 15, 25, 45]

    @Published private(set) var total: TimeInterval = 25 * 60
    @Published private(set) var remaining: TimeInterval = 25 * 60
    @Published private(set) var isRunning = false
    @Published private(set) var justFinished = false

    private var endDate: Date?
    private var ticker: Timer?

    /// Rodando ou pausado no meio: aparece no notch recolhido.
    var isActive: Bool { isRunning || remaining < total }
    var progress: Double { total > 0 ? 1 - remaining / total : 0 }
    var text: String { Self.format(remaining) }

    func set(minutes: Int) {
        stopTicker()
        total = TimeInterval(minutes * 60)
        remaining = total
        isRunning = false
        justFinished = false
    }

    func start() {
        guard !isRunning, remaining > 0 else { return }
        justFinished = false
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        let ticker = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    func pause() {
        tick()
        stopTicker()
        isRunning = false
    }

    func reset() {
        set(minutes: Int(total / 60))
    }

    private func tick() {
        guard let endDate else { return }
        let left = max(0, endDate.timeIntervalSinceNow)
        // Só publica quando o segundo exibido muda, para não redesenhar à toa
        if left.rounded(.up) != remaining.rounded(.up) { remaining = left.rounded(.up) }
        if left == 0 { finish() }
    }

    private func finish() {
        stopTicker()
        isRunning = false
        justFinished = true
        NSSound(named: "Glass")?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            guard let self, self.justFinished else { return }
            self.justFinished = false
            self.remaining = self.total
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
    }

    static func format(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
