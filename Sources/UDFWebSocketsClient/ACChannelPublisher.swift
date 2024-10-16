//===--- ACChannelPublisher.swift ----------------------------------------===//
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
import Combine
import ActionCableSwift

/// A Combine `Publisher` that wraps an `ACChannel` and emits values based on a mapped output from the channel's messages.
public struct ACChannelPublisher<Mapper: ACCChannelOutputMapping>: Publisher {
    public typealias Failure = Error
    public typealias Output = Mapper.Output
    
    public var mapper: Mapper
    public var channelBuilder: () -> ACChannel?
    
    /// Initializes a new `ACChannelPublisher` with the provided mapper and channel builder.
    ///
    /// - Parameters:
    ///   - mapper: The `ACCChannelOutputMapping` instance used to map messages to outputs.
    ///   - channelBuilder: A closure that provides an `ACChannel` instance when needed.
    public init(mapper: Mapper, channelBuilder: @escaping () -> ACChannel?) {
        self.mapper = mapper
        self.channelBuilder = channelBuilder
    }
    
    /// Subscribes the provided `Subscriber` to this publisher.
    ///
    /// - Parameter subscriber: The subscriber that will receive values from the channel.
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        subscriber.receive(
            subscription: ChannelSubscription(
                subscriber: subscriber,
                channelBuilder: channelBuilder,
                mapper: mapper
            )
        )
    }
    
    /// A subscription that manages the connection to the ActionCable channel and handles message mapping.
    private final class ChannelSubscription<S: Subscriber>: NSObject, Subscription where S.Input == Output, S.Failure == Failure {
        var subscriber: S?
        var channel: ACChannel?
        var mapper: Mapper
        var channelBuilder: () -> ACChannel?
        
        /// Initializes the subscription with the subscriber, channel builder, and mapper.
        ///
        /// - Parameters:
        ///   - subscriber: The subscriber that will receive values.
        ///   - channelBuilder: A closure to build an `ACChannel` instance.
        ///   - mapper: The mapper responsible for transforming messages into outputs.
        init(subscriber: S, channelBuilder: @escaping () -> ACChannel?, mapper: Mapper) {
            self.channelBuilder = channelBuilder
            self.mapper = mapper
            super.init()
            self.subscriber = subscriber
        }
        
        /// Requests a certain demand for values from the channel.
        ///
        /// - Parameter demand: The number of values the subscriber is ready to receive.
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else {
                return
            }
            
            guard let channel = channelBuilder() else {
                return
            }
            
            let channelName = channel.channelName
            
            // Listen for messages from the channel
            channel.addOnMessage({ [weak self] ch, message in
                guard ch.channelName == channelName, let message else {
                    return
                }
                
                // Map the message and send the output to the subscriber
                if let output = self?.mapper.map(from: message) {
                    _ = self?.subscriber?.receive(output)
                }
            })
            
            // Handle automatic re-subscription upon unsubscription
            let autoSubscribe = channel.options.autoSubscribe
            channel.addOnUnsubscribe { [weak self] ch, _ in
                guard ch.channelName == channelName, autoSubscribe, self?.subscriber != nil else {
                    return
                }
                
                try? ch.subscribe()
            }
            
            self.channel = channel
            if !channel.options.autoSubscribe {
                try? channel.subscribe()
            }
        }
        
        /// Cancels the subscription and unsubscribes from the channel.
        func cancel() {
            do {
                try channel?.unsubscribe()
                subscriber?.receive(completion: .finished)
            } catch {
                subscriber?.receive(completion: .failure(error))
            }
            subscriber = nil
        }
    }
}
