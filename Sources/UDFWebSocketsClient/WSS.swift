
import Foundation
import ActionCableSwift
import Starscream

class WSS: ACWebSocketProtocol, WebSocketDelegate {
    var url: URL
    var ws: WebSocket

    init(stringURL: String) {
        url = URL(string: stringURL)!
        ws = WebSocket(request: URLRequest(url: url))
        ws.delegate = self
    }

    var onConnected: ((_ headers: [String : String]?) -> Void)?
    var onDisconnected: ((_ reason: String?) -> Void)?
    var onCancelled: (() -> Void)?
    var onText: ((_ text: String) -> Void)?
    var onBinary: ((_ data: Data) -> Void)?
    var onPing: (() -> Void)?
    var onPong: (() -> Void)?

    func connect(headers: [String : String]?) {
        ws.request.allHTTPHeaderFields = headers
        ws.connect()
    }

    func disconnect() {
        ws.disconnect()
    }

    func send(data: Data) {
        ws.write(data: data)
    }

    func send(data: Data, _ completion: (() -> Void)?) {
        ws.write(data: data, completion: completion)
    }

    func send(text: String) {
        ws.write(string: text)
    }

    func send(text: String, _ completion: (() -> Void)?) {
        ws.write(string: text, completion: completion)
    }

    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            onConnected?(headers)
        case .disconnected(let reason, let code):
            onDisconnected?(reason)
        case .text(let string):
            onText?(string)
        case .binary(let data):
            onBinary?(data)
        case .ping(_):
            onPing?()
        case .pong(_):
            onPong?()
        case .cancelled:
            onCancelled?()
        default: break
        }
    }
}

//public final class WSS: ACWebSocketProtocol {
//
//    public var url: URL
//    private var eventLoopGroup: EventLoopGroup
//    @Atomic public var ws: WebSocket?
//
//    public var onConnected: ((_ headers: [String : String]?) -> Void)?
//    public var onDisconnected: ((_ reason: String?) -> Void)?
//    public var onCancelled: (() -> Void)?
//    public var onText: ((_ text: String) -> Void)?
//    public var onBinary: ((_ data: Data) -> Void)?
//    public var onPing: (() -> Void)?
//    public var onPong: (() -> Void)?
//
//    public init(stringURL: String, coreCount: Int = System.coreCount) {
//        url = URL(string: stringURL)!
//        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: coreCount)
//    }
//
//    public func connect(headers: [String : String]?) {
//
//        var httpHeaders: HTTPHeaders = .init()
//        headers?.forEach({ (name, value) in
//            httpHeaders.add(name: name, value: value)
//        })
//        let promise: EventLoopPromise<Void> = eventLoopGroup.next().makePromise(of: Void.self)
//
//        WebSocket.connect(to: url.absoluteString,
//                          headers: httpHeaders,
//                          on: eventLoopGroup
//        ) { ws in
//            self.ws = ws
//
//            ws.onPing { [weak self] (ws, _) in
//                self?.onPing?()
//            }
//
//            ws.onPong { [weak self] (ws, _) in
//                self?.onPong?()
//            }
//
//            ws.onClose.whenComplete { [weak self] (result) in
//                switch result {
//                case .success:
//                    self?.onDisconnected?(nil)
//                    self?.onCancelled?()
//                case let .failure(error):
//                    self?.onDisconnected?(error.localizedDescription)
//                    self?.onCancelled?()
//                }
//            }
//
//            ws.onText { (ws, text) in
//                self.onText?(text)
//            }
//
//            ws.onBinary { (ws, buffer) in
//                var data: Data = Data()
//                data.append(contentsOf: buffer.readableBytesView)
//                self.onBinary?(data)
//            }
//
//        }.cascade(to: promise)
//
//        promise.futureResult.whenSuccess { [weak self] (_) in
//            guard let self = self else { return }
//            self.onConnected?(nil)
//        }
//    }
//
//    public func disconnect() {
//        ws?.close(promise: nil)
//    }
//
//    public func send(data: Data) {
//        ws?.send([UInt8](data))
//    }
//
//    public func send(data: Data, _ completion: (() -> Void)?) {
//        let promise: EventLoopPromise<Void>? = ws?.eventLoop.next().makePromise(of: Void.self)
//        ws?.send([UInt8](data), promise: promise)
//        promise?.futureResult.whenComplete { (_) in
//            completion?()
//        }
//    }
//
//    public func send(text: String) {
//        ws?.send(text)
//    }
//
//    public func send(text: String, _ completion: (() -> Void)?) {
//        let promise: EventLoopPromise<Void>? = ws?.eventLoop.next().makePromise(of: Void.self)
//        ws?.send(text, promise: promise)
//        promise?.futureResult.whenComplete { (_) in
//            completion?()
//        }
//    }
//}
