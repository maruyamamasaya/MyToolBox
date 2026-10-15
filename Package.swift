// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "MyToolBox", platforms: [.macOS(.v14)], products: [
    .library(name: "MonitorKit", targets: ["MonitorKit"]),
    .executable(name: "monitor-probe", targets: ["Probe"])
], targets: [
    .target(name: "MonitorKit", linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("Metal"), .linkedFramework("SystemConfiguration"), .linkedLibrary("sqlite3")]),
    .executableTarget(name: "Probe", dependencies: ["MonitorKit"]),
    .testTarget(name: "MonitorKitTests", dependencies: ["MonitorKit"])
])
