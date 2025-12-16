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
import os

/// `WSS` is a WebSocket implementation that conforms to `ACWebSocketProtocol`.
/// It uses NIO and WebSocketKit to manage WebSocket connections and handle events.
public final class WSS: ACWebSocketProtocol {
    
    public var url: URL
    private var eventLoopGroup: EventLoopGroup

    private var _ws: OSAllocatedUnfairLock<WebSocket?> = .init(initialState: nil)
    public var ws: WebSocket? {
        get { _ws.withLock { $0 } }
        set { _ws.withLock { $0 = newValue } }
    }

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

        let future = WebSocket.connect(to: url.absoluteString, headers: httpHeaders, on: eventLoopGroup) { [weak self] ws in
            guard let self = self else { return }
            self.ws = ws

            // Handle ping
            ws.onPing { [weak self] (_, _) in
                if let onPing = self?.onPing { onPing() }
            }

            // Handle pong
            ws.onPong { [weak self] (_, _) in
                if let onPong = self?.onPong { onPong() }
            }

            // Handle text messages
            ws.onText { [weak self] (_, text) in
                guard let self = self else { return }
                if let onText = self.onText { onText(text) }
            }

            // Handle binary messages
            ws.onBinary { [weak self] (_, buffer) in
                guard let self = self else { return }
                let data = Data(buffer.readableBytesView)
                if let onBinary = self.onBinary { onBinary(data) }
            }

            // Handle close events
            ws.onClose.whenComplete { [weak self] (result) in
                guard let self = self else { return }
                switch result {
                case .success:
                    if let onDisconnected = self.onDisconnected { onDisconnected(nil) }
                case let .failure(error):
                    if let onDisconnected = self.onDisconnected { onDisconnected(error.localizedDescription) }
                }
                if let onCancelled = self.onCancelled { onCancelled() }
            }
        }

        future.whenComplete { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                if let onConnected = self.onConnected { onConnected(nil) }
            case .failure(let error):
                if let onDisconnected = self.onDisconnected { onDisconnected(error.localizedDescription) }
                if let onCancelled = self.onCancelled { onCancelled() }
            }
        }
    }
    
    /// Disconnects the WebSocket connection.
    public func disconnect() {
        guard let socket = self.ws else { return }
        self.ws = nil
        socket.close(promise: nil)
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
        guard let ws = self.ws else {
            completion?()
            return
        }
        let promise = ws.eventLoop.makePromise(of: Void.self)
        ws.send([UInt8](data), promise: promise)
        promise.futureResult.whenComplete { _ in
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
        guard let ws = self.ws else {
            completion?()
            return
        }
        let promise = ws.eventLoop.makePromise(of: Void.self)
        ws.send(text, promise: promise)
        promise.futureResult.whenComplete { _ in
            completion?()
        }
    }

    deinit {
        // Ensure the WebSocket is closed if still open
        ws?.close(promise: nil)
        ws = nil

        // Shutdown the EventLoopGroup gracefully to avoid thread/resource leaks
        eventLoopGroup.shutdownGracefully { _ in }
    }
}
