//===--- WSS.swift -------------------------------------------------------===//
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
import NIO
import NIOHTTP1
import NIOWebSocket
import WebSocketKit
import ActionCableSwift

/// `WSS` is a WebSocket implementation that conforms to `ACWebSocketProtocol`.
/// It uses NIO and WebSocketKit to manage WebSocket connections and handle events.
public final class WSS: ACWebSocketProtocol {
    
    public var url: URL
    private var eventLoopGroup: EventLoopGroup
    @Atomic public var ws: WebSocket?
    
    public var onConnected: ((_ headers: [String : String]?) -> Void)?
    public var onDisconnected: ((_ reason: String?) -> Void)?
    public var onCancelled: (() -> Void)?
    public var onText: ((_ text: String) -> Void)?
    public var onBinary: ((_ data: Data) -> Void)?
    public var onPing: (() -> Void)?
    public var onPong: (() -> Void)?
    
    /// Initializes a new `WSS` instance with a URL and an optional core count.
    ///
    /// - Parameters:
    ///   - stringURL: The WebSocket URL as a string.
    ///   - coreCount: The number of threads for the `EventLoopGroup` (defaults to system core count).
    public init(stringURL: String, coreCount: Int = System.coreCount) {
        url = URL(string: stringURL)!
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: coreCount)
    }
    
    /// Connects to the WebSocket server with optional HTTP headers.
    ///
    /// - Parameter headers: A dictionary of HTTP headers to send during the WebSocket handshake.
    public func connect(headers: [String : String]?) {
        var httpHeaders: HTTPHeaders = .init()
        headers?.forEach { (name, value) in
            httpHeaders.add(name: name, value: value)
        }
        let promise: EventLoopPromise<Void> = eventLoopGroup.next().makePromise(of: Void.self)
        
        WebSocket.connect(to: url.absoluteString, headers: httpHeaders, on: eventLoopGroup) { ws in
            self.ws = ws
            
            // Handle ping
            ws.onPing { [weak self] (ws, _) in
                self?.onPing?()
            }
            
            // Handle pong
            ws.onPong { [weak self] (ws, _) in
                self?.onPong?()
            }
            
            // Handle close events
            ws.onClose.whenComplete { [weak self] (result) in
                switch result {
                case .success:
                    self?.onDisconnected?(nil)
                    self?.onCancelled?()
                case let .failure(error):
                    self?.onDisconnected?(error.localizedDescription)
                    self?.onCancelled?()
                }
            }
            
            // Handle text messages
            ws.onText { (ws, text) in
                self.onText?(text)
            }
            
            // Handle binary messages
            ws.onBinary { (ws, buffer) in
                var data: Data = Data()
                data.append(contentsOf: buffer.readableBytesView)
                self.onBinary?(data)
            }
        }.cascade(to: promise)
        
        // Trigger the connection callback on success
        promise.futureResult.whenSuccess { [weak self] (_) in
            self?.onConnected?(nil)
        }
    }
    
    /// Disconnects the WebSocket connection.
    public func disconnect() {
        ws?.close(promise: nil)
    }
    
    /// Sends binary data over the WebSocket.
    ///
    /// - Parameter data: The binary data to send.
    public func send(data: Data) {
        ws?.send([UInt8](data))
    }
    
    /// Sends binary data over the WebSocket with a completion handler.
    ///
    /// - Parameters:
    ///   - data: The binary data to send.
    ///   - completion: A closure called when the send operation completes.
    public func send(data: Data, _ completion: (() -> Void)?) {
        let promise: EventLoopPromise<Void>? = ws?.eventLoop.next().makePromise(of: Void.self)
        ws?.send([UInt8](data), promise: promise)
        promise?.futureResult.whenComplete { (_) in
            completion?()
        }
    }
    
    /// Sends a text message over the WebSocket.
    ///
    /// - Parameter text: The text message to send.
    public func send(text: String) {
        ws?.send(text)
    }
    
    /// Sends a text message over the WebSocket with a completion handler.
    ///
    /// - Parameters:
    ///   - text: The text message to send.
    ///   - completion: A closure called when the send operation completes.
    public func send(text: String, _ completion: (() -> Void)?) {
        let promise: EventLoopPromise<Void>? = ws?.eventLoop.next().makePromise(of: Void.self)
        ws?.send(text, promise: promise)
        promise?.futureResult.whenComplete { (_) in
            completion?()
        }
    }
}
