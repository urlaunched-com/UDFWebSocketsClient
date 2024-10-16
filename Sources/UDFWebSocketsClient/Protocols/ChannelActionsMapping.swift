//===--- ChannelActionsMapping.swift -------------------------------------===//
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
import UDF

/// Protocol defining a mapping from an output to an action within a specific state in the UDF architecture.
///
/// Types conforming to this protocol are responsible for translating an `Output` into an `Action`
/// based on the current state of the application, represented by the `State` type.
public protocol ChannelActionsMapping {
    
    /// The associated type representing the output to be mapped to an action.
    associatedtype Output
    
    /// The associated type representing the state of the application.
    associatedtype State: AppReducer
    
    /// Maps an output to a corresponding action based on the current state.
    ///
    /// - Parameters:
    ///   - output: The output to be mapped to an action.
    ///   - state: The current application state, which influences the resulting action.
    /// - Returns: An `Action` that should be triggered based on the output and the state.
    func mapAction(from output: Output, state: State) -> any Action
}
