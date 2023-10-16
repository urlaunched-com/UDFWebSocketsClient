// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UDFWebSocketsClient",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "UDFWebSocketsClient",
            targets: ["UDFWebSocketsClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Maks-Jago/SwiftUI-UDF", from: "1.4.1-alpha.6"),
        .package(url: "https://github.com/nerzh/Action-Cable-Swift", from: "0.4.0"),
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0")
//        .package(url: "https://github.com/vapor/websocket-kit", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "UDFWebSocketsClient",
            dependencies: [
                .product(name: "UDF", package: "SwiftUI-UDF"),
                .product(name: "ActionCableSwift", package: "Action-Cable-Swift"),
                .product(name: "Starscream", package: "Starscream")
//                .product(name: "WebSocketKit", package: "websocket-kit")
            ]
        )
    ]
)
