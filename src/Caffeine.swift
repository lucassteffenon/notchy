import Foundation
import IOKit.pwr_mgt

/// Impede o Mac de dormir/apagar a tela enquanto estiver ativa (sem tempo ou por um período).
final class Caffeine: ObservableObject {
    static let durations: [(label: String, minutes: Int?)] = [
        ("Sem limite", nil), ("30 min", 30), ("1 h", 60), ("2 h", 120),
    ]

    @Published private(set) var isActive = false
    @Published private(set) var endDate: Date?

    private var assertion: IOPMAssertionID = 0
    private var stopWork: DispatchWorkItem?

    deinit { deactivate() }

    func activate(minutes: Int?) {
        deactivate()
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Notchy: Cafeína ativa" as CFString,
            &assertion)
        guard result == kIOReturnSuccess else { return }
        isActive = true

        if let minutes {
            endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
            let work = DispatchWorkItem { [weak self] in self?.deactivate() }
            stopWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(minutes * 60), execute: work)
        }
    }

    func deactivate() {
        stopWork?.cancel()
        stopWork = nil
        if isActive { IOPMAssertionRelease(assertion) }
        isActive = false
        endDate = nil
    }

    func toggle() {
        isActive ? deactivate() : activate(minutes: nil)
    }

    /// Texto curto do tempo restante: "∞", "45m", "1h30".
    func shortRemaining(at now: Date) -> String {
        guard let endDate else { return "∞" }
        let minutes = max(0, Int((endDate.timeIntervalSince(now) / 60).rounded(.up)))
        if minutes < 60 { return "\(minutes)m" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60)h" : String(format: "%dh%02d", minutes / 60, rest)
    }
}
