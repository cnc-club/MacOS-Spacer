import Foundation

struct Entry: Identifiable, Hashable {
    let url: URL
    var size: Int64
    var children: [Entry]?
    var reason: String?
    var scanExcluded = false
    var isComplete = true

    func find(_ target: URL) -> Entry? {
        let path = target.path
        if id == path { return self }
        guard path.hasPrefix(id == "/" ? "/" : id + "/") else { return nil }
        return children?.first(where: { path == $0.id || path.hasPrefix($0.id + "/") })?.find(target)
    }

    func containsMatch(_ predicate: (Entry) -> Bool) -> Bool {
        predicate(self) || (children?.contains(where: { $0.containsMatch(predicate) }) ?? false)
    }
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

final class ScanControl: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    func cancel() { lock.lock(); stopped = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
}

struct ScanResult { let root: Entry; let skipped: Int; let excluded: Int }

enum Scanner {
    static func recommendation(_ url: URL, modified: Date?, now: Date = Date()) -> String? {
        let path = url.path
        let age = now.timeIntervalSince(modified ?? now) / 86400
        if path.contains("/Library/Caches/"), age > 30 { return "Cache unchanged for over 30 days. Quit the related app before cleanup." }
        if path.contains("/Library/Logs/"), age > 30 { return "Log older than 30 days. It may still be useful for troubleshooting." }
        if path.contains("/Downloads/"), age > 30, ["dmg", "pkg", "zip", "tar", "gz"].contains(url.pathExtension.lowercased()) { return "Old installer or archive in Downloads. Check that its contents are installed or saved." }
        return nil
    }
    static func excludedPaths(for root: URL) -> Set<String> {
        root.standardizedFileURL.path == "/" ? ["/dev", "/System/Volumes"] : []
    }
    static func preview(_ url: URL) -> Entry {
        let url = FolderNavigation.canonical(url)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey]
        let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys))) ?? []
        let entries = children.compactMap { child -> Entry? in
            guard let v = try? child.resourceValues(forKeys: keys) else { return nil }
            let directory = v.isDirectory == true && v.isSymbolicLink != true
            return Entry(url: child, size: directory ? 0 : Int64(v.fileSize ?? 0), children: directory && v.isPackage != true ? [] : nil,
                         reason: directory ? nil : recommendation(child, modified: v.contentModificationDate), isComplete: !directory)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return Entry(url: url, size: entries.reduce(0) { $0 + $1.size }, children: entries, isComplete: false)
    }
    static func scan(_ url: URL, cancelled: () -> Bool = { false }) -> ScanResult {
        let url = FolderNavigation.canonical(url)
        var skipped = 0
        var excluded = 0
        let exclusions = excludedPaths(for: url)
        let fm = FileManager.default
        func visit(_ url: URL) -> Entry {
            // The Data volume is already exposed through root firmlinks. Do not
            // count it twice or traverse the device filesystem during a disk scan.
            if exclusions.contains(url.path) {
                excluded += 1
                return Entry(url: url, size: 0, children: [], scanExcluded: true)
            }
            if cancelled() { return Entry(url: url, size: 0, children: nil, isComplete: false) }
            do {
                let v = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey])
                if v.isSymbolicLink == true { return Entry(url: url, size: 0, children: nil) }
                if v.isDirectory == true, v.isPackage != true {
                    let children = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey]).map(visit).sorted { $0.size > $1.size }
                    return Entry(url: url, size: children.reduce(0) { $0 + $1.size }, children: children, isComplete: !cancelled())
                }
                // Packages are atomic in the browser, but their contents still count.
                if v.isPackage == true, v.isDirectory == true {
                    var bytes: Int64 = 0
                    if let e = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isSymbolicLinkKey], options: [], errorHandler: { _, _ in skipped += 1; return true }) {
                        for case let child as URL in e {
                            if cancelled() { break }
                            let values: URLResourceValues
                            do { values = try child.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey, .isDirectoryKey]) }
                            catch { skipped += 1; continue }
                            if values.isSymbolicLink == true { e.skipDescendants() }
                            else if values.isDirectory != true { bytes += Int64(values.fileSize ?? 0) }
                        }
                    }
                    return Entry(url: url, size: bytes, children: nil)
                }
                return Entry(url: url, size: Int64(v.fileSize ?? 0), children: nil, reason: recommendation(url, modified: v.contentModificationDate))
            } catch { skipped += 1; return Entry(url: url, size: 0, children: nil) }
        }
        let entry = visit(url)
        return ScanResult(root: entry, skipped: skipped, excluded: excluded)
    }
    static func canTrash(_ url: URL, root: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let base = root.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(base == "/" ? "/" : base + "/") && path.hasPrefix(home + "/") && !["Library", "Documents", "Desktop", "Downloads", "Pictures", "Music", "Movies"].map { home + "/" + $0 }.contains(path) && !path.hasPrefix(home + "/Library/")
    }
}
func bytes(_ value: Int64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB", "PB"]
    var amount = Double(max(0, value)); var unit = 0
    while amount >= 1000 && unit < units.count - 1 { amount /= 1000; unit += 1 }
    let formatter = NumberFormatter(); formatter.locale = Locale(identifier: Localization.language)
    formatter.maximumFractionDigits = unit == 0 ? 0 : 1
    return (formatter.string(from: NSNumber(value: amount)) ?? String(amount)) + " " + T(units[unit])
}

enum FolderNavigation {
    static func canonical(_ url: URL) -> URL {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        // Foundation shortens /private/var to /var, whereas directory enumeration
        // returns /private/var. Use the same namespace for roots and descendants.
        let path = resolved.path
        if ["/var", "/tmp", "/etc"].contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return URL(fileURLWithPath: "/private" + path)
        }
        return resolved
    }
    static func ancestors(of url: URL) -> [URL] {
        var path = url.standardizedFileURL
        var result = [path]
        while path.path != "/" {
            path.deleteLastPathComponent()
            result.append(path)
        }
        return result.reversed()
    }
}


struct VolumeSpace {
    let name: String
    let total: Int64
    let available: Int64
    static func read(at url: URL) -> VolumeSpace? {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: url.path),
              let total = attributes[.systemSize] as? NSNumber,
              let free = attributes[.systemFreeSize] as? NSNumber else { return nil }
        let name = (try? url.resourceValues(forKeys: [.volumeNameKey]))?.volumeName ?? T("Disk")
        return VolumeSpace(name: name, total: total.int64Value, available: free.int64Value)
    }
}
