
import Foundation
import UDF
import Combine

public struct SocketChannelEffect<FlowID: Hashable, OM: ACCChannelOutputMapping, AM: ChannelActionsMapping>: Effectable where OM.Output == AM.Output {
    unowned var store: any Store<AM.State>
    var channelBuilder: () -> ACChannel?
    var outputMapper: OM
    var actionMapper: AM
    var flowId: FlowID
    var queue: DispatchQueue
    var debounce: TimeInterval

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
