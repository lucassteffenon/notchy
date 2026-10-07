import Cocoa
import ApplicationServices

/// Engole todos os eventos de teclado via CGEventTap (requer permissão de Acessibilidade).
final class KeyboardBlocker {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private(set) var isLocked = false

    static func hasAccessibility(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    func lock() -> Bool {
        guard !isLocked else { return true }

        // keyDown, keyUp, modifiers e teclas de sistema (brilho, volume, mídia = NSSystemDefined 14)
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        var mask: CGEventMask = types.reduce(0) { $0 | (1 << $1.rawValue) }
        mask |= (1 << 14)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let refcon {
                    let blocker = Unmanaged<KeyboardBlocker>.fromOpaque(refcon).takeUnretainedValue()
                    if let tap = blocker.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                }
                return Unmanaged.passUnretained(event)
            }
            return nil // engole o evento
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isLocked = true
        return true
    }

    func unlock() {
        guard isLocked, let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
        isLocked = false
    }
}
