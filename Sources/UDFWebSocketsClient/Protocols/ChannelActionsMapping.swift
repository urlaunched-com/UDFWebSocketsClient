
import Foundation
import UDF

public protocol ChannelActionsMapping {
    associatedtype Output
    associatedtype State: AppReducer

    func mapAction(from output: Output, state: State) -> any Action
}
