import AppKit
import Combine
import SwiftUI

/// Hosting view que aceita o primeiro clique mesmo com o painel inativo.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Posiciona o painel sobre o notch e expande/recolhe conforme o mouse.
final class NotchController {
    let model = NotchModel()
    private let panel: NSPanel
    private var monitors: [Any] = []
    private var screenObserver: NSObjectProtocol?
    private var collapseWork: DispatchWorkItem?
    private var cancellables: Set<AnyCancellable> = []

    /// Tempo que o notch espera depois que o mouse sai antes de fechar.
    private let collapseDelay: TimeInterval = 0.6

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = FirstMouseHostingView(rootView: NotchRootView(model: model))

        model.settings.$hideInFullscreen
            .sink { [weak self] hide in self?.applySpaceBehavior(hideInFullscreen: hide) }
            .store(in: &cancellables)

        layout()
        panel.orderFrontRegardless()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.layout() }

        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] event in
            self?.handleMouse(dragFromOtherApp: event.type == .leftMouseDragged)
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            self?.handleMouse(dragFromOtherApp: false)
            return event
        }) {
            monitors.append(local)
        }
    }

    deinit {
        monitors.forEach(NSEvent.removeMonitor)
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    /// Sem `.fullScreenAuxiliary`, o macOS não mostra o painel nos espaços de tela cheia.
    private func applySpaceBehavior(hideInFullscreen: Bool) {
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if !hideInFullscreen { behavior.insert(.fullScreenAuxiliary) }
        panel.collectionBehavior = behavior
        if hideInFullscreen && model.isExpanded && !panel.isOnActiveSpace { setExpanded(false) }
    }

    /// Tela com notch (MacBook) ou, na falta dela, a principal.
    private var targetScreen: NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func layout() {
        let screen = targetScreen
        let frame = screen.frame
        var notch = CGSize(width: 190, height: NSStatusBar.system.thickness)
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notch = CGSize(width: frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
        }
        model.notchSize = notch

        let size = model.maxExpandedSize
        panel.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height,
                              width: size.width, height: size.height), display: true)
    }

    /// Área sensível ao mouse com o notch recolhido.
    private var hotZone: NSRect {
        let frame = targetScreen.frame
        let width = model.collapsedWidth + 20
        let height = model.notchSize.height + 4
        return NSRect(x: frame.midX - width / 2, y: frame.maxY - height, width: width, height: height + 2)
    }

    private func handleMouse(dragFromOtherApp: Bool) {
        let point = NSEvent.mouseLocation
        // Em tela cheia o painel não está no espaço atual: não abre (nem vibra) à toa
        guard panel.isOnActiveSpace else { return }
        if model.isExpanded {
            if shouldStayOpen(at: point) {
                cancelCollapse()
            } else if collapseWork == nil {
                scheduleCollapse()
            }
        } else if hotZone.contains(point) {
            if dragFromOtherApp { model.showShelf() }
            setExpanded(true)
        }
    }

    private func shouldStayOpen(at point: NSPoint) -> Bool {
        model.isLocked || model.isDropTargeted || expandedRect.insetBy(dx: -8, dy: -8).contains(point)
    }

    /// Área da forma aberta na tela (muda de tamanho conforme a aba).
    private var expandedRect: NSRect {
        let frame = targetScreen.frame
        let size = model.expandedSize
        return NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height,
                      width: size.width, height: size.height)
    }

    /// Fecha depois de um tempo, se o mouse não voltar para o notch nesse meio-tempo.
    private func scheduleCollapse() {
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.collapseWork = nil
            if !self.shouldStayOpen(at: NSEvent.mouseLocation) { self.setExpanded(false) }
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDelay, execute: work)
    }

    private func cancelCollapse() {
        collapseWork?.cancel()
        collapseWork = nil
    }

    private func setExpanded(_ expanded: Bool) {
        cancelCollapse()
        // Toque leve no trackpad (Force Touch) ao abrir
        if expanded && !model.isExpanded {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        panel.ignoresMouseEvents = !expanded
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            model.isExpanded = expanded
        }
    }
}
