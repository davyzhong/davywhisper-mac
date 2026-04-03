import Foundation

// MARK: - Event Bus Protocol

public protocol EventBusProtocol: Sendable {
    @discardableResult
    func subscribe(handler: @escaping @Sendable (DavyWhisperEvent) async -> Void) -> UUID
    func unsubscribe(id: UUID)
}

// MARK: - Events

public enum DavyWhisperEvent: Sendable {
    case recordingStarted(RecordingStartedPayload)
    case recordingStopped(RecordingStoppedPayload)
    case transcriptionCompleted(TranscriptionCompletedPayload)
    case transcriptionFailed(TranscriptionFailedPayload)
    case textInserted(TextInsertedPayload)
    case partialTranscriptionUpdate(PartialTranscriptionPayload)
}

// MARK: - Payloads

public struct RecordingStartedPayload: Sendable, Codable {
    public let timestamp: Date
    public let appName: String?
    public let bundleIdentifier: String?

    public init(timestamp: Date = Date(), appName: String? = nil, bundleIdentifier: String? = nil) {
        self.timestamp = timestamp
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct RecordingStoppedPayload: Sendable, Codable {
    public let timestamp: Date
    public let durationSeconds: Double

    public init(timestamp: Date = Date(), durationSeconds: Double) {
        self.timestamp = timestamp
        self.durationSeconds = durationSeconds
    }
}

public struct TranscriptionCompletedPayload: Sendable, Codable {
    public let timestamp: Date
    public let rawText: String
    public let finalText: String
    public let language: String?
    public let engineUsed: String
    public let modelUsed: String?
    public let durationSeconds: Double
    public let appName: String?
    public let bundleIdentifier: String?
    public let url: String?
    public let profileName: String?

    public init(
        timestamp: Date = Date(),
        rawText: String,
        finalText: String,
        language: String? = nil,
        engineUsed: String,
        modelUsed: String? = nil,
        durationSeconds: Double,
        appName: String? = nil,
        bundleIdentifier: String? = nil,
        url: String? = nil,
        profileName: String? = nil
    ) {
        self.timestamp = timestamp
        self.rawText = rawText
        self.finalText = finalText
        self.language = language
        self.engineUsed = engineUsed
        self.modelUsed = modelUsed
        self.durationSeconds = durationSeconds
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.profileName = profileName
    }
}

public struct TranscriptionFailedPayload: Sendable, Codable {
    public let timestamp: Date
    public let error: String
    public let appName: String?
    public let bundleIdentifier: String?

    public init(timestamp: Date = Date(), error: String, appName: String? = nil, bundleIdentifier: String? = nil) {
        self.timestamp = timestamp
        self.error = error
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct TextInsertedPayload: Sendable, Codable {
    public let timestamp: Date
    public let text: String
    public let appName: String?
    public let bundleIdentifier: String?

    public init(timestamp: Date = Date(), text: String, appName: String? = nil, bundleIdentifier: String? = nil) {
        self.timestamp = timestamp
        self.text = text
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct PartialTranscriptionPayload: Sendable, Codable {
    public let timestamp: Date
    public let text: String
    public let isFinal: Bool
    public let elapsedSeconds: Double

    public init(timestamp: Date = Date(), text: String, isFinal: Bool = false, elapsedSeconds: Double = 0) {
        self.timestamp = timestamp
        self.text = text
        self.isFinal = isFinal
        self.elapsedSeconds = elapsedSeconds
    }
}
