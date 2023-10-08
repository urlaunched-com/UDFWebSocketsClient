
import ActionCableSwift

public protocol ACCChannelOutputMapping {
    associatedtype Output

    func map(from message: ACMessage) -> Output?
}
