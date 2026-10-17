// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TVRemote",
    platforms: [.macOS(.v15), .iOS(.v17)],
    products: [
        .library(name: "TVRemoteProtocol", targets: ["TVRemoteProtocol"]),
        .executable(name: "TVRemoteMac", targets: ["TVRemoteMac"])
    ],
    targets: [
        .target(name: "TVRemoteProtocol"),
        .executableTarget(
            name: "TVRemoteMac",
            dependencies: ["TVRemoteProtocol"]
        ),
        .testTarget(
            name: "TVRemoteProtocolTests",
            dependencies: ["TVRemoteProtocol"]
        )
    ]
)
