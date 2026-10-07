import EventKit
import Foundation

/// Compromissos de hoje (a partir de agora) e de amanhã, de todos os calendários do Mac.
final class CalendarModel: ObservableObject {
    enum Status { case unknown, denied, ready }

    @Published private(set) var status: Status = .unknown
    @Published private(set) var events: [EKEvent] = []

    /// Quanto tempo antes do início o notch recolhido começa a avisar.
    static let alertLead: TimeInterval = 5 * 60

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var ticker: Timer?

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

    /// Próximo compromisso com horário que começa em até 5 min (ou começou há menos de 5 min).
    func upcomingMeeting(at now: Date = .now) -> EKEvent? {
        events.first { event in
            !event.isAllDay
                && event.startDate.timeIntervalSince(now) <= Self.alertLead
                && now.timeIntervalSince(event.startDate) < Self.alertLead
        }
    }

    private func fetch() {
        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged, object: store, queue: .main
            ) { [weak self] _ in self?.fetch() }
        }
        if ticker == nil {
            // Relê a cada 30s: atualiza o "em X min" e faz o aviso aparecer/sumir na hora certa
            let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.fetch() }
            RunLoop.main.add(timer, forMode: .common)
            ticker = timer
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

extension EKEvent {
    /// Link de videochamada (Meet, Zoom, Teams, Webex...) no link, local ou notas do evento.
    var meetingURL: URL? {
        let hosts = ["meet.google.com", "zoom.us", "teams.microsoft.com", "teams.live.com",
                     "webex.com", "whereby.com", "facetime.apple.com", "discord.gg"]
        let candidates = [url?.absoluteString, location, notes].compactMap { $0 }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        for text in candidates {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                if let link = match.url, let host = link.host?.lowercased(),
                   hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
                    return link
                }
            }
        }
        return nil
    }
}
