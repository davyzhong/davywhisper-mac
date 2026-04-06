import Foundation
import AppKit

/// Manages advanced settings state: CLI tool installation and integration detection.
/// Extracted from AdvancedSettingsView to enable unit testing.
@MainActor
final class AdvancedSettingsViewModel: ObservableObject {

    // MARK: - CLI State

    #if !APPSTORE
    @Published var cliInstalled = false
    @Published var cliSymlinkTarget = ""

    static let symlinkPath = "/usr/local/bin/davywhisper"

    var cliBinaryPath: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/davywhisper-cli").path
    }

    func checkCLIInstallation() {
        let fm = FileManager.default
        guard let dest = try? fm.destinationOfSymbolicLink(atPath: Self.symlinkPath) else {
            cliInstalled = false
            return
        }
        cliSymlinkTarget = dest
        cliInstalled = dest == cliBinaryPath
    }

    func installCLI() {
        let target = cliBinaryPath
        let link = Self.symlinkPath
        let script = """
            do shell script "mkdir -p /usr/local/bin && ln -sf '\(target)' '\(link)'" with administrator privileges
            """
        runOsascript(script) { [weak self] in
            self?.checkCLIInstallation()
        }
    }

    func uninstallCLI() {
        let link = Self.symlinkPath
        let script = """
            do shell script "rm -f '\(link)'" with administrator privileges
            """
        runOsascript(script) { [weak self] in
            self?.checkCLIInstallation()
        }
    }

    private func runOsascript(_ source: String, completion: @escaping @MainActor @Sendable () -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        process.terminationHandler = { _ in
            Task { @MainActor in completion() }
        }
        try? process.run()
    }
    #endif

    // MARK: - HuggingFace Mirror

    var hfMirrorEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: UserDefaultsKeys.useHuggingFaceMirror) }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.useHuggingFaceMirror) }
    }
}
