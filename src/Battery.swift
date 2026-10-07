import Foundation
import IOKit.ps

/// Lê a bateria interna e avisa (por alguns segundos) quando o carregador é conectado/desconectado.
final class BatteryMonitor: ObservableObject {
    @Published private(set) var hasBattery = false
    @Published private(set) var percent = 0
    @Published private(set) var isCharging = false
    @Published private(set) var isPluggedIn = false
    @Published private(set) var showsAlert = false

    private var source: CFRunLoopSource?
    private var hideAlert: DispatchWorkItem?

    var symbol: String {
        if isPluggedIn { return "battery.100percent.bolt" }
        switch percent {
        case 88...: return "battery.100"
        case 63..<88: return "battery.75"
        case 38..<63: return "battery.50"
        case 13..<38: return "battery.25"
        default: return "battery.0"
        }
    }

    init() {
        update(notify: false)
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue().update(notify: true)
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            self.source = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    deinit {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    }

    private func update(notify: Bool) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return }

        for powerSource in list {
            guard let desc = IOPSGetPowerSourceDescription(info, powerSource)?.takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }

            let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let plugged = desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue

            hasBattery = true
            percent = max > 0 ? current * 100 / max : current
            isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            if notify && plugged != isPluggedIn { flashAlert() }
            isPluggedIn = plugged
        }
    }

    private func flashAlert() {
        hideAlert?.cancel()
        showsAlert = true
        let work = DispatchWorkItem { [weak self] in self?.showsAlert = false }
        hideAlert = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }
}
