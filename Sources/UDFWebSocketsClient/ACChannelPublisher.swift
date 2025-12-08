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
        var isCancelled = false

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

        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else {
                return
            }

            // Do not process any demand if subscription was cancelled
            guard !isCancelled else {
                return
            }

            // If the channel is already set up, we don't need to configure it again
            if channel != nil {
                return
            }

            guard let channel = channelBuilder() else {
                return
            }

            let channelName = channel.channelName

            // Listen for messages from the channel
            channel.addOnMessage { [weak self] ch, message in
                guard
                    let self,
                    !self.isCancelled,
                    ch.channelName == channelName,
                    let message
                else {
                    return
                }

                // Map the message and send the output to the subscriber
                if let output = self.mapper.map(from: message) {
                    _ = self.subscriber?.receive(output)
                }
            }

            // Handle automatic re-subscription upon unsubscription
            let autoSubscribe = channel.options.autoSubscribe
            channel.addOnUnsubscribe { [weak self] ch, _ in
                guard
                    let self,
                    !self.isCancelled,
                    ch.channelName == channelName,
                    autoSubscribe,
                    self.subscriber != nil
                else {
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
            // Mark the subscription as cancelled so callbacks won't act on it anymore
            isCancelled = true

            // Best-effort unsubscribe from the channel; ignore errors here
            try? channel?.unsubscribe()

            // Drop references to allow deallocation and break retain cycles
            subscriber = nil
            channel = nil
        }
    }
}
