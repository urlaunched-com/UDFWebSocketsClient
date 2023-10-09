
import Foundation
import ActionCableSwift

public extension ACMessage {
    var typeData: Data? {
        (try? message?.toJSONData())?.unwrapJSONDataBy(key: "type")
    }

    var textData: Data? {
        (try? message?.toJSONData())?.unwrapJSONDataBy(key: "data")
    }
}

private extension Data {
    func unwrapJSONDataBy(key: String) -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: self, options: []) as? [String: Any] else {
            return self
        }

        guard let jsonByKey = json[key] else {
            return self
        }

        guard let newData = try? JSONSerialization.data(withJSONObject: jsonByKey, options: .fragmentsAllowed) else {
            return self
        }

        return newData
    }
}
