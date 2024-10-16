//===--- ACMessage+Extensions.swift -----------------------------------===//
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
import ActionCableSwift

/// Extension for ACMessage to easily extract specific data fields from JSON message payloads.
public extension ACMessage {
    
    /// Extracts the data for the "type" key from the message JSON.
    ///
    /// - Returns: The `Data` associated with the "type" key, if it exists, otherwise returns `nil`.
    var typeData: Data? {
        (try? message?.toJSONData())?.unwrapJSONDataBy(key: "type")
    }
    
    /// Extracts the data for the "data" key from the message JSON.
    ///
    /// - Returns: The `Data` associated with the "data" key, if it exists, otherwise returns `nil`.
    var textData: Data? {
        (try? message?.toJSONData())?.unwrapJSONDataBy(key: "data")
    }
}

/// Private extension for Data to help with unwrapping JSON by key.
private extension Data {
    
    /// Unwraps the JSON data and extracts the value associated with a specific key.
    ///
    /// - Parameter key: The key whose associated value should be extracted.
    /// - Returns: The `Data` corresponding to the value found by the key, or the original `Data` if any extraction fails.
    func unwrapJSONDataBy(key: String) -> Data {
        // Attempt to deserialize the JSON object
        guard let json = try? JSONSerialization.jsonObject(with: self, options: []) as? [String: Any] else {
            return self
        }
        
        // Check if the key exists in the deserialized JSON object
        guard let jsonByKey = json[key] else {
            return self
        }
        
        // Serialize the value associated with the key back to Data
        guard let newData = try? JSONSerialization.data(withJSONObject: jsonByKey, options: .fragmentsAllowed) else {
            return self
        }
        
        return newData
    }
}
