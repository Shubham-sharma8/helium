import Foundation

/// A lightweight async-friendly mutual exclusion primitive for Swift concurrency.
public final class AsyncLock: @unchecked Sendable {
    private let lock = NSLock()
    private var isLocked = false
    private var waiters: [(id: UUID, continuation: CheckedContinuation<Void, any Error>)] = []

    public init() {}

    public func acquire() async {
        let waiterId = UUID()
        try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            lock.lock()
            if !isLocked {
                isLocked = true
                lock.unlock()
                continuation.resume()
            } else {
                waiters.append((id: waiterId, continuation: continuation))
                lock.unlock()
            }
        }
    }

    public func acquireCheckingCancellation() async throws {
        let waiterId = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                lock.lock()
                if Task.isCancelled {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                } else if !isLocked {
                    isLocked = true
                    lock.unlock()
                    continuation.resume()
                } else {
                    waiters.append((id: waiterId, continuation: continuation))
                    lock.unlock()
                }
            }
        } onCancel: {
            cancelWaiter(id: waiterId)
        }
    }

    private func cancelWaiter(id: UUID) {
        lock.lock()
        if let idx = waiters.firstIndex(where: { $0.id == id }) {
            let entry = waiters.remove(at: idx)
            lock.unlock()
            entry.continuation.resume(throwing: CancellationError())
        } else {
            lock.unlock()
        }
    }

    public func release() {
        lock.lock()
        if let next = waiters.first {
            waiters.removeFirst()
            lock.unlock()
            next.continuation.resume()
        } else {
            isLocked = false
            lock.unlock()
        }
    }

    public func withLock<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }
}

/// An async gate that can suspend callers until opened.
public final class AsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var openState: Bool
    private var waiters: [(id: UUID, continuation: CheckedContinuation<Void, Never>)] = []

    public init(initiallyOpen: Bool = true) {
        self.openState = initiallyOpen
    }

    public var isOpen: Bool {
        lock.lock()
        defer { lock.unlock() }
        return openState
    }

    public func open() {
        lock.lock()
        openState = true
        let pending = waiters
        waiters.removeAll()
        lock.unlock()
        for waiter in pending {
            waiter.continuation.resume()
        }
    }

    public func close() {
        lock.lock()
        openState = false
        lock.unlock()
    }

    public func wait() async {
        let waiterId = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                lock.lock()
                if openState {
                    lock.unlock()
                    continuation.resume()
                } else {
                    waiters.append((id: waiterId, continuation: continuation))
                    lock.unlock()
                }
            }
        } onCancel: {
            cancelWaiter(id: waiterId)
        }
    }

    private func cancelWaiter(id: UUID) {
        lock.lock()
        if let idx = waiters.firstIndex(where: { $0.id == id }) {
            let entry = waiters.remove(at: idx)
            lock.unlock()
            entry.continuation.resume()
        } else {
            lock.unlock()
        }
    }
}

/// A counting semaphore for bounding concurrent async operations.
public final class AsyncSemaphore: @unchecked Sendable {
    private let lock = NSLock()
    private var permits: Int
    private var waiters: [(id: UUID, continuation: CheckedContinuation<Void, any Error>)] = []

    public init(value: Int) {
        self.permits = max(1, value)
    }

    public func wait() async {
        let waiterId = UUID()
        try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            lock.lock()
            if permits > 0 {
                permits -= 1
                lock.unlock()
                continuation.resume()
            } else {
                waiters.append((id: waiterId, continuation: continuation))
                lock.unlock()
            }
        }
    }

    public func waitCheckingCancellation() async throws {
        let waiterId = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                lock.lock()
                if Task.isCancelled {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                } else if permits > 0 {
                    permits -= 1
                    lock.unlock()
                    continuation.resume()
                } else {
                    waiters.append((id: waiterId, continuation: continuation))
                    lock.unlock()
                }
            }
        } onCancel: {
            cancelWaiter(id: waiterId)
        }
    }

    private func cancelWaiter(id: UUID) {
        lock.lock()
        if let idx = waiters.firstIndex(where: { $0.id == id }) {
            let entry = waiters.remove(at: idx)
            lock.unlock()
            entry.continuation.resume(throwing: CancellationError())
        } else {
            lock.unlock()
        }
    }

    public func signal() {
        lock.lock()
        if let next = waiters.first {
            waiters.removeFirst()
            lock.unlock()
            next.continuation.resume()
        } else {
            permits += 1
            lock.unlock()
        }
    }

    public func withPermit<T: Sendable>(_ body: @Sendable () async throws -> T) async rethrows -> T {
        await wait()
        defer { signal() }
        return try await body()
    }
}

/// Tracks whether a series of transient failures has crossed a time window to become a user-visible lasting failure.
public struct LastingFailure: Sendable {
    public let window: TimeInterval
    private var firstAt: Date?
    public private(set) var message: String?

    public init(window: TimeInterval = 15.0) {
        self.window = window
    }

    public mutating func recordFailure(_ errorDescription: String, now: Date = Date()) -> Bool {
        if let first = firstAt {
            if now.timeIntervalSince(first) >= window {
                message = errorDescription
                return true
            }
            return false
        } else {
            firstAt = now
            return false
        }
    }

    public mutating func clear() {
        firstAt = nil
        message = nil
    }
}
