# UDFWebSocketsClient
SwiftUI-UDF WebSockets Client

UDFWebSocketsClient is a Swift-based library designed to facilitate WebSocket communication with reactive support using Combine. The library is built on top of `ActionCableSwift`, `NIO`, and `WebSocketKit`, allowing seamless WebSocket integration with a UDF (Unidirectional Data Flow) architecture.

## Features

- **WebSocket connection management**: Open and close WebSocket connections with ease.
- **Reactive WebSocket communication**: Support for Combine-based publishers to process incoming WebSocket messages.
- **ActionCable integration**: Leverage `ActionCableSwift` to interact with ActionCable servers.
- **Thread-safe state management**: Utilize atomic properties and ensure safe concurrent access to WebSocket resources.
- **Customizable Mappers**: Map WebSocket messages into specific outputs and corresponding actions based on your application state.
- **Debounce and Event Handling**: Control WebSocket message processing with built-in debouncing and isolated state handling.

## Installation

### Swift Package Manager

To add UDFWebSocketsClient to your project, add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/youarelaunched/UDFWebSocketsClient.git", from: "1.0.0")
]
```

## Getting Started

### Basic Usage

Here’s a simple example of how to use WSS (WebSocket Service) for managing WebSocket connections and sending/receiving messages.

#### Initialize the WebSocket Connection

# UDFWebSocketsClient Middleware Example

This example demonstrates how to implement and use a WebSocket client with UDF middleware to manage WebSocket connections, process incoming messages, and map them to actions in a SwiftUI-based application using the **UDF** architecture.

## WebSocketsMiddleware Overview

The `WebSocketsMiddleware` class handles WebSocket connections and channel subscriptions using the `SocketChannelEffect`. It manages WebSocket lifecycle events, including connecting and disconnecting clients and channels, and maps incoming messages into actions using the `outputMapper` and `actionMapper`.

The following example includes a `WebSocketsMiddleware` implementation with both a live environment for production and a test environment for testing purposes.

### WebSocketsMiddleware Implementation

*Middleware subscription:*

```swift
store.subscribeAsync(WebSocketsMiddleware.self, on: DispatchQueue(label: "WebSocketsMiddleware", qos: .background))
```
*Middleware example:*

```swift
import Foundation
import UDF
import Combine
import API
import UDFWebSocketsClient

final class WebSocketsMiddleware: BaseReducibleMiddleware<AppState> {
    enum Cancellation: Hashable {
        case socketChannelChats
        case socketChannelChat(Chat.ID)
    }

    struct Environment {
        var clientBuilder: (_ token: String) -> ACClient
        var channelBuilder: (_ client: ACClient?, _ name: String, _ identifier: [String: Any]?) -> ACChannel?
    }

    var environment: Environment!
    private var client: ACClient? = nil

    func reduce(_ action: some Action, for state: AppState) {
        switch action {
        case is Actions.Logout:
            cancelAll()
            client?.disconnect()
            client = nil

        case let action as Actions.DidReceiveCurrentUser:
            guard client == nil, let token = action.user.token else { break }
            client = environment.clientBuilder(token)
            client?.connect()

            runNotificationSocketEffects(state)

        case let action as Actions.UpdateAppStatus where action.appStatus == .active && client == nil && state.userForm.isLoggedIn == true:
            client = environment.clientBuilder(state.userForm.token)
            client?.connect()

            runNotificationSocketEffects(state)

        case let action as Actions.ConnectChat:
            run(
                SocketChannelEffect(
                    store: store,
                    channelBuilder: { [unowned self] in
                        self.environment.channelBuilder(
                            self.client,
                            SocketChannel.chat(),
                            [SocketChannel.Param.chatId(): String(action.id.value)]
                        )
                    },
                    outputMapper: ChatChannelOutputMapper(),
                    actionMapper: ChatChannelActionsMapper(),
                    flowId: WebSocketFlow.id,
                    queue: queue
                ),
                cancellation: Cancellation.socketChannelChat(action.id)
            )

        case let action as Actions.DisconnectChat:
            cancel(by: Cancellation.socketChannelChat(action.id))

        default:
            break
        }
    }

    func runNotificationSocketEffects(_ state: AppState) {
        run(
            SocketChannelEffect(
                store: store,
                channelBuilder: { [unowned self] in
                    environment.channelBuilder(client, SocketChannel.notification(), nil)
                },
                outputMapper: NotificationChannelOutputMapper(),
                actionMapper: NotificationChannelActionMapper(),
                flowId: WebSocketFlow.id,
                queue: queue
            ),
            cancellation: Cancellation.socketChannelChats
        )
    }
}

extension WebSocketsMiddleware {

    static func buildLiveEnvironment(for store: some Store<AppState>) -> Environment {
        Environment(
            clientBuilder: { token in
                let host: String = EnvironmentConfig.value(for: .baseAPIKey)
                let cableToken = token.dropFirst(7)
                let ws: WSS = .init(stringURL: "wss://\(host)/cable?token=\(cableToken)")
                let clientOptions: ACClientOptions = .init(debug: false, reconnect: true)
                return ACClient(ws: ws, options: clientOptions)
            },
            channelBuilder: { client, name, identifier in
                let channelOptions: ACChannelOptions = .init(buffering: false, autoSubscribe: true)
                return client?.makeChannel(name: name, identifier: identifier ?? [:], options: channelOptions)
            }
        )
    }

    static func buildTestEnvironment(for store: some Store<AppState>) -> Environment {
        Environment(
            clientBuilder: { token in
                let ws: WSS = .init(stringURL: "ws://localhost:3001/cable")
                let clientOptions: ACClientOptions = .init(debug: false, reconnect: true)
                return ACClient(ws: ws, options: clientOptions)
            },
            channelBuilder: { client, name, identifier in
                let channelOptions: ACChannelOptions = .init(buffering: false, autoSubscribe: true)
                return client?.makeChannel(name: name, identifier: identifier ?? [:], options: channelOptions)
            }
        )
    }
}

```

*ChannelActionsMapping implementation example:*
``` swift
import Foundation
import UDF
import UDFWebSocketsClient

struct NotificationChannelActionMapper: ChannelActionsMapping {
    func mapAction(from output: NotificationChannelOutput, state: AppState) -> any Action {
        let flowId = WebSocketFlow.id

        return ActionGroup {
            switch output {
            case .newChat(let chat):
                if let lastMessage = chat.lastMessage?.asMessage {
                    Actions.DidLoadItem(item: lastMessage, id: flowId)
                    Actions.DidLoadNestedItem(parentId: chat.id, item: lastMessage.id, id: flowId)
                }
                Actions.DidLoadItem(item: chat.asChat, id: flowId)
            case .updateChat(let chat):
                Actions.DidUpdateItem(item: chat.asChat, id: flowId)
                if (state.chatForm.chatId?.value != chat.id || !state.chatForm.isChatConnected),
                   let lastMessageRemote = chat.lastMessage {
                    let lastMessage = lastMessageRemote.asMessage
                    Actions.DidLoadItem(item: lastMessage, id: flowId)
                    Actions.DidLoadNestedItem(parentId: chat.asChat.id, item: lastMessage.id, id: flowId)
                    Actions.DidLoadItem(item: lastMessageRemote.user.asUser, id: flowId)
                }
            }
        }
    }
}
```
*ACCChannelOutputMapping implementation example:*
``` swift
import Foundation
import API
import UDFWebSocketsClient

struct NotificationChannelOutputMapper: ACCChannelOutputMapping {
    enum MessageType: String, Codable {
        case newChat = "new_chat"
        case updateChat = "update_chat"
    }

    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func map(from message: ACMessage) -> NotificationChannelOutput? {
        guard
            message.type == .message,
            let messageTypeValue = message.typeData,
            let messageType = decoder.decodeSafely(
                MessageType.self, from: messageTypeValue
            ),
            let textData = message.textData
        else {
            return nil
        }

        switch messageType {
        case .newChat:
            return decoder.decodeSafely(ChatRemote.self, from: textData).map(Output.newChat)
        case .updateChat:
            return decoder.decodeSafely(ChatRemote.self, from: textData).map(Output.updateChat)
        }
    }
}

```

## Error Handling

When errors occur (such as WebSocket disconnections or message parsing issues), SocketChannelEffect automatically maps these errors to actions and can be handled in your application’s state.

## License

This project is licensed under the MIT License. See the LICENSE file for more information.

## Contributing

Contributions are welcome! If you have any bug reports, feature requests, or suggestions, please open an issue or submit a pull request.

## Contact

For questions or support, feel free to contact us at youarelaunched.com.
