import AppKit
import SwiftUI
import Combine

/// Height of each content region in the overlay panel.
private enum OverlayContent {
    static let statusBar: CGFloat = 48
    static let expandedText: CGFloat = 100
    static let actionFeedback: CGFloat = 40
    static let bottomPadding: CGFloat = 8
}

/// Floating panel for the Overlay Indicator mode.
class OverlayIndicatorPanel: NSPanel {
    private static let panelWidth: CGFloat = 500

    private var cancellables = Set<AnyCancellable>()
    private var cachedScreen: NSScreen?
    /// Current panel height — updated dynamically based on content.
    private var currentHeight: CGFloat = OverlayContent.statusBar + OverlayContent.bottomPadding

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: OverlayContent.statusBar + OverlayContent.bottomPadding),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        ignoresMouseEvents = true

        // Use NSVisualEffectView for reliable translucent dark background on all displays
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 24
        visualEffectView.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: OverlayIndicatorView())
        hostingView.sizingOptions = []
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        visualEffectView.addSubview(hostingView)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
        ])

        contentView = visualEffectView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func startObserving() {
        let vm = DictationViewModel.shared

        vm.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateVisibility(state: state, vm: vm)
                self?.updatePanelHeight()
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

        // Observe partialText changes to resize panel when streaming text arrives
        vm.$partialText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePanelHeight()
            }
            .store(in: &cancellables)

        vm.$overlayPosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isVisible else { return }
                self.show()
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

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - Self.panelWidth / 2

        // Position at bottom of screen, hugging the Dock / menu bar area
        let y: CGFloat = screenFrame.origin.y + 20

        setFrame(NSRect(x: x, y: y, width: Self.panelWidth, height: currentHeight), display: true)
        orderFrontRegardless()
    }

    /// Recalculates panel height from current view model state and updates the frame.
    private func updatePanelHeight() {
        let vm = DictationViewModel.shared
        var height = OverlayContent.statusBar

        // Expanded text adds to height (only in recording state)
        if vm.state == .recording && !vm.partialText.isEmpty {
            height += OverlayContent.expandedText
        }

        // Action feedback banner adds to height (inserting state)
        if vm.state == .inserting && vm.actionFeedbackMessage != nil {
            height += OverlayContent.actionFeedback
        }

        height += OverlayContent.bottomPadding

        if height != currentHeight {
            currentHeight = height
            guard isVisible else { return }
            guard let screen = cachedScreen ?? NSScreen.main else { return }
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - Self.panelWidth / 2
            let y = screenFrame.origin.y + 20
            setFrame(NSRect(x: x, y: y, width: Self.panelWidth, height: currentHeight), display: true)
        }
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
