import Foundation
import DavyWhisperPluginSDK
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DavyWhisper", category: "EventBus")

@MainActor
final class EventBus: EventBusProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var shared: EventBus!

    private struct Subscription: Sendable {
        let id: UUID
        let handler: @Sendable (DavyWhisperEvent) async -> Void
    }

    private nonisolated(unsafe) var subscriptions: [Subscription] = []
    private nonisolated(unsafe) let lock = NSLock()

    @discardableResult
    nonisolated func subscribe(handler: @escaping @Sendable (DavyWhisperEvent) async -> Void) -> UUID {
        let id = UUID()
        let subscription = Subscription(id: id, handler: handler)
        lock.lock()
        subscriptions.append(subscription)
        lock.unlock()
        return id
    }

    nonisolated func unsubscribe(id: UUID) {
        lock.lock()
        subscriptions.removeAll { $0.id == id }
        lock.unlock()
    }

    func emit(_ event: DavyWhisperEvent) {
        let handlers: [(UUID, @Sendable (DavyWhisperEvent) async -> Void)]
        lock.lock()
        handlers = subscriptions.map { ($0.id, $0.handler) }
        lock.unlock()
        for (_, handler) in handlers {
            Task.detached {
                await handler(event)
            }
        }
        logger.debug("Emitted event to \(handlers.count) subscriber(s)")
    }
}
