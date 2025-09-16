//===--- Atomic.swift ---------------------------------------------------===//
//
// This source file is part of the UDFWebSocketsClient open source project
//
// Copyright (c) 2024 You are launched
// Licensed under MIT License
//
// See https://opensource.org/licenses/MIT for license information
//
//===----------------------------------------------------------------------===//

import Foundation
import os

/// A thread-safe property wrapper to guarantee atomic access and mutation of a value.
///
/// The underlying value is protected by an `NSLock` to ensure that reads and writes are thread-safe.
@propertyWrapper
public struct Atomic<Value> {
    /// The lock that holds the protected value.
    private let lock: OSAllocatedUnfairLock<Value>

    /// Initializes the wrapper with the provided initial value.
    ///
    /// - Parameter wrappedValue: The initial value to store inside the lock.
    public init(wrappedValue: Value) {
        // Initialize the lock with the initial state
        self.lock = OSAllocatedUnfairLock(initialState: wrappedValue)
    }

    /// Provides thread-safe access and mutation.
    public var wrappedValue: Value {
        get {
            lock.withLock { $0 }
        }
        set {
            lock.withLock { state in
                state = newValue
            }
        }
    }

    /// Performs an in-place modification of the wrapped value in a single critical section.
    ///
    /// - Parameter block: A closure that receives an inout value to modify.
    /// - Returns: The result of the closure.
    @discardableResult
    public func mutate<T>(_ block: (inout Value) throws -> T) rethrows -> T {
        try lock.withLock { value in
            try block(&value)
        }
    }
}
