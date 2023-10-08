
import Foundation
import ActionCableSwift

public extension ACMessage {
    var typeData: Data? {
        (message?["type"] as? String)?.data(using: .utf8)
    }

    var textData: Data? {
        (message?["data"] as? String)?.data(using: .utf8)
    }
}
