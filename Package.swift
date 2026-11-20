// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Spacer", defaultLocalization: "en", platforms: [.macOS(.v13)], products: [.executable(name: "Spacer", targets: ["Spacer"])], targets: [.executableTarget(name: "Spacer", resources: [.process("Resources")])])
