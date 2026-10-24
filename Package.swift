// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AppleTVRemote",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "work/itsytv-core")
    ],
    targets: [
        .executableTarget(
            name: "AppleTVRemote",
            dependencies: [
                .product(name: "ItsytvCore", package: "itsytv-core")
            ],
            exclude: ["Info.plist"]
        ),
        .executableTarget(
            name: "AppleTVConnectionCheck",
            dependencies: [
                .product(name: "ItsytvCore", package: "itsytv-core")
            ]
        )
    ]
)
