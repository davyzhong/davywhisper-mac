import AppKit
import SwiftUI
import Combine

/// Hosting view that accepts first mouse click without requiring a prior activation click.
private class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Floating panel for the Overlay Indicator mode, anchored bottom-center.
class OverlayIndicatorPanel: NSPanel {
    private static let panelWidth: CGFloat = 500
    private static let panelHeight: CGFloat = 300

    private var cancellables = Set<AnyCancellable>()
    private var cachedScreen: NSScreen?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        ignoresMouseEvents = true

        let hostingView = FirstMouseHostingView(rootView: OverlayIndicatorView())
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func startObserving() {
        let vm = DictationViewModel.shared

        vm.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateVisibility(state: state, vm: vm)
            }
            .store(in: &cancellables)

        vm.$notchIndicatorVisibility
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateVisibility(state: vm.state, vm: vm)
            }
            .store(in: &cancellables)

        vm.$notchIndicatorDisplay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.cachedScreen = nil
                self?.updateVisibility(state: vm.state, vm: vm)
            }
            .store(in: &cancellables)
    }

    func updateVisibility(state: DictationViewModel.State, vm: DictationViewModel) {
        guard vm.indicatorStyle == .overlay else {
            dismiss()
            return
        }

        switch vm.notchIndicatorVisibility {
        case .always:
            show()
        case .duringActivity:
            switch state {
            case .recording, .processing, .inserting, .error:
                show()
            case .idle, .promptSelection, .promptProcessing:
                dismiss()
            }
        case .never:
            dismiss()
        }
    }

    func show() {
        let screen: NSScreen
        if let cached = cachedScreen, isVisible {
            screen = cached
        } else {
            screen = resolveScreen()
            cachedScreen = screen
        }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame // Excludes dock

        let dockHeight = screenFrame.height - visibleFrame.height - visibleFrame.origin.y + screenFrame.origin.y
        let bottomOffset: CGFloat = max(dockHeight + 24, 24)

        let x = screenFrame.midX - Self.panelWidth / 2
        let y = screenFrame.origin.y + bottomOffset

        setFrame(NSRect(x: x, y: y, width: Self.panelWidth, height: Self.panelHeight), display: true)
        orderFrontRegardless()
    }

    private func resolveScreen() -> NSScreen {
        let display = DictationViewModel.shared.notchIndicatorDisplay
        switch display {
        case .activeScreen:
            let mouseLocation = NSEvent.mouseLocation
            return NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main ?? NSScreen.screens[0]
        case .primaryScreen:
            return NSScreen.main ?? NSScreen.screens[0]
        case .builtInScreen:
            return NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        }
    }

    func dismiss() {
        cachedScreen = nil
        orderOut(nil)
    }
}
