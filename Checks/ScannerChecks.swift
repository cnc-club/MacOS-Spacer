import Foundation

@main struct ScannerChecks {
    static func main() throws {
        let fm = FileManager.default
        let root = FolderNavigation.canonical(fm.temporaryDirectory).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root.appendingPathComponent("sub"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try Data(repeating: 1, count: 123).write(to: root.appendingPathComponent("sub/file"))
        try Data(repeating: 2, count: 7).write(to: root.appendingPathComponent("small"))
        try fm.createSymbolicLink(at: root.appendingPathComponent("loop"), withDestinationURL: root)
        let result = Scanner.scan(root)
        precondition(result.root.size == 130, "Nested sizes or symlink handling failed")
        precondition(result.root.children?.first?.name == "sub", "Size sorting failed")
        precondition(result.skipped == 0)
        precondition(Scanner.scan(root, cancelled: { true }).root.size == 0)
        precondition(result.root.find(root.appendingPathComponent("sub/file"))?.size == 123)
        precondition(result.root.find(root.appendingPathComponent("missing")) == nil)
        precondition(result.root.find(root.appendingPathComponent("submarine/file")) == nil)
        let preview = Scanner.preview(root)
        precondition(!preview.isComplete && preview.children?.count == 3)
        precondition(preview.children?.first(where: { $0.name == "sub" })?.isComplete == false)
        precondition(result.root.containsMatch { $0.name == "file" })
        let space = VolumeSpace.read(at: root)
        precondition(space != nil && space!.total > 0 && space!.available >= 0 && space!.available <= space!.total)
        print("PASS: nested sizes, sorting, links, cancellation, path lookup, immediate listing, disk space")

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = now.addingTimeInterval(-86400 * 40)
        precondition(Scanner.recommendation(URL(fileURLWithPath: "/Users/test/Downloads/setup.dmg"), modified: old, now: now) != nil)
        precondition(Scanner.recommendation(URL(fileURLWithPath: "/Users/test/Documents/contract.zip"), modified: old, now: now) == nil)
        precondition(Scanner.recommendation(URL(fileURLWithPath: "/Users/test/Downloads/setup.dmg"), modified: now, now: now) == nil)
        precondition(Scanner.recommendation(URL(fileURLWithPath: "/Users/test/Downloads/setup.dmg"), modified: nil, now: now) == nil)
        print("PASS: recommendations require location and age; unknown dates are ignored")

        let ancestors = FolderNavigation.ancestors(of: URL(fileURLWithPath: "/Applications/Utilities"))
        precondition(ancestors.map(\.path) == ["/", "/Applications", "/Applications/Utilities"])
        precondition(FolderNavigation.ancestors(of: URL(fileURLWithPath: "/")).map(\.path) == ["/"])
        // The scan fixture is outside the home folder: analysis has no home restriction.
        precondition(!root.path.hasPrefix(fm.homeDirectoryForCurrentUser.path + "/"))
        precondition(result.root.size == 130 && result.excluded == 0)
        precondition(Scanner.excludedPaths(for: URL(fileURLWithPath: "/")) == ["/dev", "/System/Volumes"])
        precondition(Scanner.excludedPaths(for: URL(fileURLWithPath: "/System/Volumes/Data")).isEmpty)
        print("PASS: navigation ancestors, analysis outside home, full-disk exclusions")

        let home = fm.homeDirectoryForCurrentUser
        precondition(!Scanner.canTrash(home, root: home))
        precondition(!Scanner.canTrash(home.appendingPathComponent("Library/Keychains/key"), root: home))
        precondition(!Scanner.canTrash(URL(fileURLWithPath: "/System/test"), root: URL(fileURLWithPath: "/")))
        precondition(!Scanner.canTrash(home.appendingPathComponent("Downloads"), root: home))
        precondition(!Scanner.canTrash(home.appendingPathComponent("Documents/other"), root: home.appendingPathComponent("Downloads")))
        precondition(Scanner.canTrash(home.appendingPathComponent("Downloads/test.dmg"), root: home))
        print("PASS: protected paths and scan boundaries")
        let benchmark = root.appendingPathComponent("benchmark")
        for i in 0..<20 {
            let dir = benchmark.appendingPathComponent("folder\(i)")
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            for j in 0..<30 { try Data([1]).write(to: dir.appendingPathComponent("file\(j)")) }
        }
        var start = Date()
        let listing = Scanner.preview(benchmark)
        let listingTime = Date().timeIntervalSince(start)
        start = Date()
        let full = Scanner.scan(benchmark)
        let scanTime = Date().timeIntervalSince(start)
        precondition(listing.children?.count == 20 && full.root.size == 600)
        start = Date()
        for _ in 0..<1000 { precondition(full.root.find(benchmark.appendingPathComponent("folder19/file29"))?.size == 1) }
        print(String(format: "TIMING: 600 files: initial listing %.1f ms, full scan %.1f ms, 1000 cached lookups %.1f ms", listingTime * 1000, scanTime * 1000, Date().timeIntervalSince(start) * 1000))
    }
}
