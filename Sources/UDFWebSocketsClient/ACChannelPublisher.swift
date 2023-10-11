
import Foundation
import Combine
import ActionCableSwift

public struct ACChannelPublisher<Mapper: ACCChannelOutputMapping>: Publisher {
    public typealias Failure = Error
    public typealias Output = Mapper.Output

    public var mapper: Mapper
    public var channelBuilder: () -> ACChannel?

    public init(mapper: Mapper, channelBuilder: @escaping () -> ACChannel?) {
        self.mapper = mapper
        self.channelBuilder = channelBuilder
    }

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        subscriber.receive(
            subscription: ChannelSubscription(
                subscriber: subscriber,
                channelBuilder: channelBuilder,
                mapper: mapper
            )
        )
    }

    private final class ChannelSubscription<S: Subscriber>: NSObject, Subscription where S.Input == Output, S.Failure == Failure {
        var subscriber: S?

        var channel: ACChannel?
        var mapper: Mapper
        var channelBuilder: () -> ACChannel?

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

            guard let channel = channelBuilder() else {
                return
            }

            let channelName = channel.channelName

            channel.addOnMessage({ [weak self] ch, message in
                guard ch.channelName == channelName, let message else {
                    return
                }

                if let output = self?.mapper.map(from: message) {
                    _ = self?.subscriber?.receive(output)
                }
            })

            channel.addOnUnsubscribe { ch, _ in
                guard ch.channelName == channelName, channel.options.autoSubscribe else {
                    return
                }

                try? channel.subscribe()
            }

            self.channel = channel
            if !channel.options.autoSubscribe {
                try? channel.subscribe()
            }
        }

        func cancel() {
            do {
                try channel?.unsubscribe()
            } catch {
                _ = subscriber?.receive(completion: .failure(error))
            }
            subscriber = nil
        }
    }
}
