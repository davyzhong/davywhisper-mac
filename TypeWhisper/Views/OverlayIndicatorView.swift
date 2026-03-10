import SwiftUI

/// Pill-shaped overlay indicator that appears centered at the bottom of the screen.
struct OverlayIndicatorView: View {
    @ObservedObject private var viewModel = DictationViewModel.shared
    @State private var textExpanded = false
    @State private var dotPulse = false

    private let contentPadding: CGFloat = 20
    private var closedWidth: CGFloat { 280 }

    private var hasActionFeedback: Bool {
        viewModel.state == .inserting && viewModel.actionFeedbackMessage != nil
    }

    private var isExpanded: Bool {
        textExpanded || hasActionFeedback
    }

    private var currentWidth: CGFloat {
        if textExpanded { return max(closedWidth, 400) }
        if hasActionFeedback { return max(closedWidth, 340) }
        return closedWidth
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Action feedback banner (top area when expanded)
            if hasActionFeedback {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.actionFeedbackIcon ?? "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 16))
                    Text(viewModel.actionFeedbackMessage ?? "")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, contentPadding)
                
                Divider().background(Color.white.opacity(0.1))
            }
            
            // Expandable partial text area
            if viewModel.state == .recording {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(viewModel.partialText)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, contentPadding)
                            .padding(.vertical, 14)
                            .id("bottom")
                    }
                    .frame(height: textExpanded ? 100 : 0)
                    .clipped()
                    .onChange(of: viewModel.partialText) {
                        if !viewModel.partialText.isEmpty, !textExpanded {
                            withAnimation(.easeOut(duration: 0.25)) {
                                textExpanded = true
                            }
                        }
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .transaction { $0.disablesAnimations = true }
            }

            // Status bar (bottom area, always visible)
            statusBar
                .frame(height: 48)
                .frame(maxWidth: .infinity)
        }
        .frame(width: currentWidth)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.3), value: textExpanded)
        .animation(.easeInOut(duration: 0.2), value: viewModel.state)
        .animation(.easeOut(duration: 0.08), value: viewModel.audioLevel)
        .onChange(of: viewModel.state) {
            if viewModel.state == .recording {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    dotPulse = true
                }
            } else {
                dotPulse = false
                textExpanded = false
            }
        }
        .animation(.easeInOut(duration: 1.0), value: dotPulse)
    }

    @ViewBuilder
    private var statusBar: some View {
        HStack(spacing: 12) {
            leftIndicator

            if case .recording = viewModel.state {
                recordingContent(for: viewModel.notchIndicatorLeftContent)
            }
            
            Spacer()

            if case .recording = viewModel.state {
                recordingContent(for: viewModel.notchIndicatorRightContent)
            } else if case .processing = viewModel.state {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var leftIndicator: some View {
        switch viewModel.state {
        case .idle, .promptSelection, .promptProcessing:
            Color.clear.frame(width: 0, height: 0)
        case .recording:
            if let icon = viewModel.activeAppIcon {
                appIconView(icon)
            } else {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(1.0 + CGFloat(viewModel.audioLevel) * 0.8)
                    .shadow(color: .yellow.opacity(dotPulse ? 0.8 : 0.2), radius: dotPulse ? 6 : 2)
            }
        case .processing:
            if let icon = viewModel.activeAppIcon {
                appIconView(icon)
            } else {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
            }
        case .inserting:
            if hasActionFeedback {
                Color.clear.frame(width: 0, height: 0)
            } else if let icon = viewModel.activeAppIcon {
                appIconView(icon)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
            }
        case .error:
            if let icon = viewModel.activeAppIcon {
                appIconView(icon, borderColor: .red)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 14))
            }
        }
    }

    private func appIconView(_ icon: NSImage, borderColor: Color? = nil) -> some View {
        Image(nsImage: icon)
            .resizable()
            .frame(width: 18, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(borderColor ?? .clear, lineWidth: 1.5)
            )
    }

    @ViewBuilder
    private func recordingContent(for content: NotchIndicatorContent) -> some View {
        switch content {
        case .indicator:
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(1.0 + CGFloat(viewModel.audioLevel) * 0.8)
                .shadow(color: .yellow.opacity(dotPulse ? 0.8 : 0.2), radius: dotPulse ? 6 : 2)
        case .timer:
            Text(formatDuration(viewModel.recordingDuration))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
        case .waveform:
            AudioWaveformView(
                audioLevel: viewModel.audioLevel,
                isSetup: viewModel.recordingDuration < 0.5 && viewModel.audioLevel < 0.05,
                compact: true
            )
        case .profile:
            if let name = viewModel.activeProfileName {
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.2), in: Capsule())
            } else {
                Color.clear
            }
        case .none:
            Color.clear
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
