import EventKit
import Foundation

/// Compromissos de hoje (a partir de agora) e de amanhã, de todos os calendários do Mac.
final class CalendarModel: ObservableObject {
    enum Status { case unknown, denied, ready }

    @Published private(set) var status: Status = .unknown
    @Published private(set) var events: [EKEvent] = []

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?

    /// Pede permissão na primeira vez e carrega os eventos.
    func load() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            status = .ready
            fetch()
        case .notDetermined:
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.status = granted ? .ready : .denied
                    if granted { self?.fetch() }
                }
            }
        default:
            status = .denied
        }
    }

    private func fetch() {
        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged, object: store, queue: .main
            ) { [weak self] _ in self?.fetch() }
        }

        let calendar = Calendar.current
        let now = Date()
        guard let end = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now)) else { return }
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
    }
}
