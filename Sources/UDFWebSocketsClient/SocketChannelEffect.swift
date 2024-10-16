//===--- SocketChannelEffect.swift ----------------------------------------===//
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
import Combine

/// `SocketChannelEffect` represents a reactive channel that listens to an ActionCable channel,
/// maps its output into actions, and dispatches those actions to a UDF store.
///
/// This effect allows for state-driven interaction with a WebSocket-like channel using Combine.
public struct SocketChannelEffect<FlowID: Hashable, OM: ACCChannelOutputMapping, AM: ChannelActionsMapping>: Effectable where OM.Output == AM.Output {
    
    unowned var store: any Store<AM.State>
    var channelBuilder: () -> ACChannel?
    var outputMapper: OM
    var actionMapper: AM
    var flowId: FlowID
    var queue: DispatchQueue
    var debounce: TimeInterval
    
    /// Initializes a new `SocketChannelEffect`.
    ///
    /// - Parameters:
    ///   - store: The UDF `Store` instance that manages the application state.
    ///   - channelBuilder: A closure to build the `ACChannel` to connect to.
    ///   - outputMapper: The mapper that translates the channel's output messages into a usable format.
    ///   - actionMapper: The mapper that translates the mapped output into UDF actions.
    ///   - flowId: A unique identifier for the flow, used for tracking errors or specific flows.
    ///   - queue: The dispatch queue on which the channel listens and the actions are dispatched.
    ///   - debounce: A time interval to debounce multiple outputs, default is `0.2` seconds.
    public init(
        store: any Store<AM.State>,
        channelBuilder: @escaping () -> ACChannel?,
        outputMapper: OM,
        actionMapper: AM,
        flowId: FlowID,
        queue: DispatchQueue,
        debounce: TimeInterval = 0.2
    ) {
        self.store = store
        self.channelBuilder = channelBuilder
        self.outputMapper = outputMapper
        self.actionMapper = actionMapper
        self.flowId = flowId
        self.debounce = debounce
        self.queue = queue
    }
    
    /// The `Publisher` that listens for channel outputs, maps them into actions, and dispatches them to the UDF store.
    public var upstream: AnyPublisher<any Action, Never> {
        Deferred {
            ACChannelPublisher(
                mapper: outputMapper,
                channelBuilder: channelBuilder
            )
            .debounce(for: .seconds(debounce), scheduler: queue)
        }
        .flatMap { output in
            Publishers.IsolatedState(from: store)
                .map { state in
                    actionMapper.mapAction(from: output, state: state)
                }
        }
        .catch { Just(Actions.Error(error: $0.localizedDescription, id: flowId)) }
        .eraseToAnyPublisher()
    }
}
