//===--- ACCChannelOutputMapping.swift -----------------------------------===//
//
// This source file is part of the UDFWebSocketsClient open source project
//
// Copyright (c) 2024 You are launched
// Licensed under MIT License
//
// See https://opensource.org/licenses/MIT for license information
//
//===----------------------------------------------------------------------===//

import ActionCableSwift

/// Protocol defining a mapping from `ACMessage` to a specific output type.
///
/// Conforming types should implement the `map(from:)` function,
/// which takes an `ACMessage` and transforms it into an optional output of type `Output`.
public protocol ACCChannelOutputMapping {
    
    /// The associated type representing the output after mapping.
    associatedtype Output
    
    /// Maps an `ACMessage` to an optional `Output`.
    ///
    /// - Parameter message: The `ACMessage` that needs to be mapped.
    /// - Returns: An optional `Output` that results from processing the message.
    func map(from message: ACMessage) -> Output?
}
