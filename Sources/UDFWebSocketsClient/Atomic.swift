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

/// A thread-safe property wrapper to guarantee atomic access and mutation of a value.
///
/// The underlying value is protected by an `NSLock` to ensure that reads and writes are thread-safe.
@propertyWrapper
public struct Atomic<Value> {
    
    private var value: Value
    private let lock = NSLock()
    
    /// Initializes the atomic wrapper with the provided initial value.
    ///
    /// - Parameter wrappedValue: The initial value to store in the atomic property.
    public init(wrappedValue value: Value) {
        self.value = value
    }
    
    /// The wrapped value which provides thread-safe access and mutation.
    ///
    /// - Getter: Returns the current value, locking access to ensure thread safety.
    /// - Setter: Stores the new value, locking access to ensure thread safety.
    public var wrappedValue: Value {
        get { return load() }
        set { store(newValue: newValue) }
    }
    
    /// Loads the current value in a thread-safe manner.
    ///
    /// - Returns: The current value after acquiring the lock.
    private func load() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
    
    /// Stores a new value in a thread-safe manner.
    ///
    /// - Parameter newValue: The new value to store, protected by the lock.
    private mutating func store(newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}
