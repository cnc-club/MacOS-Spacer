import SwiftUI
import AppKit
import Darwin

@main struct SpacerApp: App {
    init() {
        if CommandLine.arguments.contains("--verify-bundle") {
            let resources = Bundle.main.resourceURL
            let expected = resources?.appendingPathComponent("Spacer_Spacer.bundle")
            let packaged = expected.flatMap { Bundle(path: $0.path) }
            let en = packaged?.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
            let ru = packaged?.path(forResource: "ru", ofType: "lproj").flatMap(Bundle.init(path:))
            let valid = Bundle.main.bundleURL.pathExtension == "app"
                && packaged != nil
                && Localization.resourceBundle.bundleURL == packaged?.bundleURL
                && en?.localizedString(forKey: "Language", value: nil, table: nil) == "Language"
                && ru?.localizedString(forKey: "Language", value: nil, table: nil) == "Язык"
                && resources.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent("LICENSE.txt").path) } == true
            print(valid ? "PASS: standalone app, bundled English/Russian resources and MIT license" : "FAIL: app resources are missing or depend on the build folder")
            exit(valid ? 0 : 1)
        }
    }
    var body: some Scene { WindowGroup { ContentView().frame(minWidth: 1200, minHeight: 680) } }
}

struct Ring: Shape {
    let start: Double; let end: Double; let inner: Double; let outer: Double
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY), r = min(rect.width, rect.height) / 2
        var p = Path()
        p.addArc(center: c, radius: r * outer, startAngle: .degrees(start - 90), endAngle: .degrees(end - 90), clockwise: false)
        p.addArc(center: c, radius: r * inner, startAngle: .degrees(end - 90), endAngle: .degrees(start - 90), clockwise: true)
        p.closeSubpath(); return p
    }
}
struct Segment: Identifiable { let entry: Entry; let start: Double; let end: Double; let inner: Double; let outer: Double; let color: Color; var id: String { entry.id + String(inner) } }
struct ContentView: View {
    @AppStorage("appLanguage") private var language = "en"
    @State private var root: Entry?
    @State private var scanID = UUID()
    @State private var cache: [String: Entry] = [:]
    @State private var volume: VolumeSpace?
    @State private var expandedEntries = Set<String>()
    @State private var current: Entry?
    @State private var selection = Set<String>()
    @State private var scanning = false
    @State private var scanControl = ScanControl()
    @State private var status = LocalizedMessage("Choose a folder to scan")
    @State private var query = ""
    @State private var onlySuggested = false
    @State private var confirm = false
    @State private var hover: Entry?
    private let palette: [Color] = [.blue, .purple, .teal, .orange, .pink, .indigo, .green, .cyan]
    var selectedEntries: [Entry] { guard !selection.isEmpty else { return [] }; return selection.filter { path in !selection.contains(where: { path.hasPrefix($0 + "/") }) }.compactMap { root?.find(URL(fileURLWithPath: $0)) } }
    func segments(_ entry: Entry) -> [Segment] {
        guard entry.size > 0 else { return [] }
        var result: [Segment] = []; var angle = 0.0
        for (i, child) in (entry.children ?? []).enumerated() where child.size > 0 {
            let end = angle + Double(child.size) / Double(entry.size) * 360
            let color = palette[i % palette.count]
            result.append(Segment(entry: child, start: angle, end: end, inner: 0.34, outer: 0.66, color: color))
            var sub = angle
            for item in child.children ?? [] where item.size > 0 {
                let next = sub + Double(item.size) / Double(entry.size) * 360
                result.append(Segment(entry: item, start: sub, end: next, inner: 0.68, outer: 0.98, color: color.opacity(0.65)))
                sub = next
            }
            angle = end
        }
        return result
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "internaldrive.fill").font(.title).foregroundStyle(.blue)
                VStack(alignment: .leading) { Text("Spacer").font(.title2.bold()); Text(T("A simple, free disk space utility for macOS")).foregroundStyle(.secondary) }
                Spacer()
                Picker(T("Language"), selection: $language) {
                    Text("English").tag("en")
                    Text("Русский").tag("ru")
                }.labelsHidden().frame(width: 95).help(T("Language"))
                if let volume {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(T("Free %@ of %@", bytes(volume.available), bytes(volume.total))).font(.callout.bold())
                        Text(volume.name).font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: Double(max(0, volume.total - volume.available)), total: Double(max(1, volume.total))).frame(width: 180)
                    }.accessibilityElement(children: .combine)
                }
                Button(T("Scan disk")) { scan(URL(fileURLWithPath: "/")) }.disabled(scanning)
                Button(T("Choose folder…"), action: choose).disabled(scanning)
                Button(action: { if let current { cache.removeAll(); scan(current.url) } }) { Image(systemName: "arrow.clockwise") }.help(T("Refresh")).disabled(root == nil || scanning)
            }.padding(20)
            Divider()
            HSplitView {
                FolderSidebar(currentURL: current?.url, disabled: false, navigate: navigate)
                VStack(spacing: 0) {
            if let current {
                HStack {
                    Button { navigate(current.url.deletingLastPathComponent()) } label: { Image(systemName: "arrow.up") }.help(T("Parent folder")).disabled(current.url.path == "/")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(FolderNavigation.ancestors(of: current.url), id: \.path) { folder in
                                if folder.path != "/" { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                                Button(folder.path == "/" ? T("Disk /") : folder.lastPathComponent) { navigate(folder) }
                                    .buttonStyle(.plain).help(folder.path)
                            }
                        }.font(.callout)
                    }

                    Spacer(); Text(current.isComplete ? bytes(current.size) : (scanning ? T("Calculating…") : T("Incomplete: %@", bytes(current.size)))).font(.title3.bold())
                }.padding()
                HSplitView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { TextField(T("Search by name or path"), text: $query); Toggle(T("Suggestions"), isOn: $onlySuggested).toggleStyle(.checkbox) }
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(current.children ?? []) { entry in row(entry, depth: 0) }
                            }
                        }
                    }.padding().frame(minWidth: 440)
                    VStack(spacing: 16) {
                        Text(T("Space usage")).font(.title3.bold())
                        ZStack {
                            ForEach(current.isComplete ? segments(current) : []) { segment in
                                Ring(start: segment.start, end: segment.end, inner: segment.inner, outer: segment.outer).fill(segment.color).onTapGesture { if segment.entry.children != nil { navigate(segment.entry.url) } else { NSWorkspace.shared.activateFileViewerSelecting([segment.entry.url]) } }.onHover { hover = $0 ? segment.entry : nil }.help("\(segment.entry.name) · \(bytes(segment.entry.size))")
                            }
                            VStack { Text(hover?.name ?? current.name).lineLimit(2); Text(current.isComplete ? bytes(hover?.size ?? current.size) : (scanning ? T("Calculating…") : T("Incomplete"))).bold() }.frame(width: 110).allowsHitTesting(false)
                        }.frame(maxWidth: 400, maxHeight: 400).aspectRatio(1, contentMode: .fit)
                        Text(T("Inner ring: this folder’s contents.\nOuter ring: one level deeper. Click to explore.")).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Text(T("Logical sizes. APFS, compression and cloud files can affect the space actually recovered.")).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }.padding(24).frame(minWidth: 340)
                }
            } else {
                Spacer(); Image(systemName: "chart.pie.fill").font(.system(size: 72)).foregroundStyle(.blue)
                Text(T("Make room for what matters")).font(.largeTitle.bold()).padding(.top)
                Text(T("See your folders, explore disk usage and review cleanup suggestions.")).foregroundStyle(.secondary)
                Button(T("Choose folder…"), action: choose).padding(); Spacer()
            }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            HStack {
                if scanning { ProgressView().controlSize(.small); Button(T("Stop")) { scanControl.cancel() } }
                Text(status.text).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
                Text(T("Selected: %@ · %@", String(selectedEntries.count), bytes(selectedEntries.reduce(0) { $0 + $1.size }))).font(.caption)
                Button(T("Move to Trash…")) { confirm = true }.disabled(selection.isEmpty || scanning)
            }.padding()
        }
        .environment(\.locale, Locale(identifier: language))
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in refreshVolume() }
        .onAppear {
            refreshVolume()
            let args = CommandLine.arguments
            if let index = args.firstIndex(of: "--scan"), args.indices.contains(index + 1), root == nil {
                let url = URL(fileURLWithPath: args[index + 1])
                var directory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &directory), directory.boolValue { scan(url) }
            }
        }
        .alert(T("Move selected items to Trash?"), isPresented: $confirm) {
            Button(T("Cancel"), role: .cancel) {}
            Button(T("Move to Trash"), role: .destructive, action: trash)
        } message: { Text(T("%@ items, %@. Restore items from Trash if needed. Space is freed after you empty Trash.", String(selectedEntries.count), bytes(selectedEntries.reduce(0) { $0 + $1.size }))) }
    }
    func matches(_ entry: Entry) -> Bool { (query.isEmpty || entry.url.path.localizedCaseInsensitiveContains(query)) && (!onlySuggested || entry.reason != nil) }
    @ViewBuilder func row(_ entry: Entry, depth: Int) -> some View {
        if matches(entry) || (entry.children != nil && (query.isEmpty && !onlySuggested || entry.containsMatch(matches))) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Toggle("", isOn: Binding(get: { selection.contains(entry.id) }, set: { if $0 { selection.insert(entry.id) } else { selection.remove(entry.id) } })).labelsHidden().disabled(root.map { !Scanner.canTrash(entry.url, root: $0.url) } ?? true)
                    Image(systemName: entry.children != nil ? "folder.fill" : "doc").foregroundStyle(entry.children != nil ? .blue : .secondary)
                    Button(entry.name) { if entry.children != nil { navigate(entry.url) } else { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) } }.buttonStyle(.plain).lineLimit(1)
                    Spacer(); Text(entry.isComplete ? bytes(entry.size) : "…").monospacedDigit().foregroundStyle(.secondary)
                    Button { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) } label: { Image(systemName: "magnifyingglass") }.buttonStyle(.borderless).help(T("Show in Finder"))
                }
                if entry.scanExcluded { Text(T("Excluded from the full-disk scan. Open to scan separately.")).font(.caption).foregroundStyle(.secondary).padding(.leading, 28) }
                if let reason = entry.reason { Text(T(reason)).font(.caption).foregroundStyle(.orange).padding(.leading, 28) }
                if entry.children != nil {
                    DisclosureGroup(T("Contents"), isExpanded: Binding(get: { expandedEntries.contains(entry.id) }, set: { if $0 { expandedEntries.insert(entry.id) } else { expandedEntries.remove(entry.id) } })) {
                        if expandedEntries.contains(entry.id) {
                            AnyView(LazyVStack(alignment: .leading) { ForEach(entry.children ?? []) { row($0, depth: depth + 1) } })
                        }
                    }.font(.caption).padding(.leading, 22)
                }
            }.padding(8).background(selection.contains(entry.id) ? Color.accentColor.opacity(0.1) : Color.clear).cornerRadius(8)
        }
    }
    func refreshVolume() {
        let url = current?.url ?? FileManager.default.homeDirectoryForCurrentUser
        DispatchQueue.global(qos: .utility).async {
            let space = VolumeSpace.read(at: url)
            DispatchQueue.main.async { if (current?.url ?? FileManager.default.homeDirectoryForCurrentUser) == url { volume = space } }
        }
    }
    func navigate(_ url: URL) {
        let url = FolderNavigation.canonical(url)
        hover = nil
        let local = root?.find(url)
        let cached = (local?.isComplete == true && local?.scanExcluded == false ? local : nil) ?? cache.values.lazy.compactMap { $0.find(url) }.first(where: { $0.isComplete && !$0.scanExcluded })
        if let cached, cached.children != nil, cached.isComplete, !cached.scanExcluded {
            scanControl.cancel(); scanID = UUID(); scanning = false
            if root?.find(url)?.isComplete != true { root = cached; selection.removeAll() }
            current = cached; refreshVolume(); status = LocalizedMessage("Opened from memory. Click Refresh to update sizes.")
        } else { scan(url) }
    }
    func choose() { let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.prompt = T("Scan"); panel.directoryURL = current?.url ?? URL(fileURLWithPath: "/"); if panel.runModal() == .OK, let url = panel.url { scan(url) } }
    func scan(_ url: URL, notice: LocalizedMessage? = nil) {
        let url = FolderNavigation.canonical(url)
        scanControl.cancel()
        let id = UUID(); scanID = id
        hover = nil
        let control = ScanControl(); scanControl = control
        scanning = true; selection.removeAll(); expandedEntries.removeAll()
        // Show a lightweight listing before traversing the entire subtree.
        current = Entry(url: url, size: 0, children: [], isComplete: false)
        status = LocalizedMessage("Opening %@…", url.path)
        refreshVolume()
        DispatchQueue.global(qos: .userInitiated).async {
            let preview = Scanner.preview(url)
            DispatchQueue.main.async {
                guard scanID == id else { return }
                root = preview; current = preview; status = LocalizedMessage("Calculating sizes in %@… You can browse other folders.", url.path)
            }
            let result = Scanner.scan(url, cancelled: { control.isCancelled })
            DispatchQueue.main.async {
                guard scanID == id else { return }
                root = result.root; current = result.root; scanning = false
                if !control.isCancelled { cache[url.path] = result.root }
                status = .joined([notice, LocalizedMessage(control.isCancelled ? "Scan stopped. Sizes are incomplete." : "Scan complete."), LocalizedMessage("Inaccessible items: %@. Excluded system branches: %@. Review suggestions before cleanup.", String(result.skipped), String(result.excluded))].compactMap { $0 })
                refreshVolume()
            }
        }
    }
    func trash() {
        guard let root else { return }
        let chosen = selectedEntries
        let top = chosen.filter { entry in !chosen.contains { entry.id.hasPrefix($0.id + "/") } }
        var errors: [String] = []
        for entry in top {
            guard Scanner.canTrash(entry.url, root: root.url), entry.url.resolvingSymlinksInPath().path == entry.url.standardizedFileURL.path else { errors.append(entry.name + ": " + T("Protected path")); continue }
            do { try FileManager.default.trashItem(at: entry.url, resultingItemURL: nil) } catch { errors.append(entry.name + ": " + error.localizedDescription) }
        }
        cache.removeAll()
        scan(root.url, notice: errors.isEmpty ? LocalizedMessage("Selected items moved to Trash") : LocalizedMessage("Could not move: %@", errors.joined(separator: "; ")))
    }
}
