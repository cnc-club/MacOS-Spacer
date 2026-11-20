import SwiftUI

struct Folder: Identifiable {
    let url: URL
    var id: String { url.path }
    var name: String { url.path == "/" ? T("Disk /") : url.lastPathComponent }
}

@MainActor final class FolderBrowser: ObservableObject {
    @Published var children: [String: [Folder]] = [:]
    @Published var errors: [String: String] = [:]
    private var loading = Set<String>()

    func load(_ url: URL) {
        let key = url.path
        guard children[key] == nil, !loading.contains(key), errors[key] == nil else { return }
        loading.insert(key)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
                .filter { child in
                    guard let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]) else { return false }
                    return values.isDirectory == true && values.isSymbolicLink != true && values.isPackage != true
                }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { Folder(url: $0) }
            }
            DispatchQueue.main.async {
                self.loading.remove(key)
                switch result {
                case .success(let folders): self.children[key] = folders
                case .failure(let error): self.errors[key] = error.localizedDescription
                }
            }
        }
    }
}

struct FolderSidebar: View {
    @AppStorage("appLanguage") private var language = "en"
    let currentURL: URL?
    let disabled: Bool
    let navigate: (URL) -> Void
    @StateObject private var browser = FolderBrowser()
    @State private var expanded: Set<String> = ["/"]
    @State private var selectedPath = "/"
    @FocusState private var treeFocused: Bool

    private var visibleFolders: [Folder] {
        func rows(_ folder: Folder) -> [Folder] {
            [folder] + (expanded.contains(folder.id) ? (browser.children[folder.id] ?? []).flatMap(rows) : [])
        }
        return rows(Folder(url: URL(fileURLWithPath: "/")))
    }

    private func move(_ direction: MoveCommandDirection) {
        let url = URL(fileURLWithPath: selectedPath)
        switch direction {
        case .left:
            if expanded.contains(selectedPath) { expanded.remove(selectedPath) }
            else if selectedPath != "/" { select(url.deletingLastPathComponent()) }
        case .right:
            if !expanded.contains(selectedPath) { expanded.insert(selectedPath); browser.load(url) }
            else if let child = browser.children[selectedPath]?.first { select(child.url) }
        case .up, .down:
            let rows = visibleFolders
            if let index = rows.firstIndex(where: { $0.id == selectedPath }) {
                let next = direction == .up ? index - 1 : index + 1
                if rows.indices.contains(next) { select(rows[next].url) }
            }
        default: break
        }
    }
    private func select(_ url: URL) {
        selectedPath = url.path; treeFocused = true; navigate(url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(T("Folders")).font(.headline)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) { folderRow(Folder(url: URL(fileURLWithPath: "/")), depth: 0) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onReceive(browser.$children) { _ in
                    if let currentURL { DispatchQueue.main.async { proxy.scrollTo(currentURL.path, anchor: .center) } }
                }
                .onChange(of: selectedPath) { path in proxy.scrollTo(path, anchor: .center) }
                .onChange(of: currentURL) { _ in reveal(); if let currentURL { proxy.scrollTo(currentURL.path, anchor: .center) } }
            }
            Divider()
            Text(T("Some folders require macOS permission. Add Spacer in Privacy & Security → Full Disk Access if needed."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12).frame(minWidth: 200, idealWidth: 240, maxWidth: 320)
        .focusable()
        .focused($treeFocused)
        .onMoveCommand(perform: move)
        .onAppear(perform: reveal)
    }

    private func reveal() {
        selectedPath = currentURL?.path ?? "/"
        let ancestors = FolderNavigation.ancestors(of: currentURL ?? URL(fileURLWithPath: "/"))
        for url in ancestors { expanded.insert(url.path); browser.load(url) }
    }

    private func folderRow(_ folder: Folder, depth: Int) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Button {
                    selectedPath = folder.id; treeFocused = true
                    if expanded.contains(folder.id) { expanded.remove(folder.id) }
                    else { expanded.insert(folder.id); browser.load(folder.url) }
                } label: {
                    Image(systemName: expanded.contains(folder.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold)).frame(width: 14, height: 24)
                }.buttonStyle(.plain).accessibilityLabel(T(expanded.contains(folder.id) ? "Collapse %@" : "Expand %@", folder.name))
                Button { select(folder.url) } label: {
                    Label(folder.name, systemImage: folder.id == "/" ? "internaldrive" : "folder")
                        .lineLimit(1).truncationMode(.middle).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).disabled(disabled).help(folder.url.path)
            }
            .padding(.leading, CGFloat(depth) * 12).padding(.horizontal, 4)
            .background((treeFocused ? selectedPath : currentURL?.path) == folder.id ? Color.accentColor.opacity(0.2) : .clear).cornerRadius(5)
            .id(folder.id)
            if expanded.contains(folder.id) {
                if let children = browser.children[folder.id] {
                    ForEach(children) { child in folderRow(child, depth: depth + 1) }
                } else if browser.errors[folder.id] != nil {
                    Text(T("Access denied")).font(.caption).foregroundStyle(.secondary).padding(.leading, CGFloat(depth + 1) * 12)
                } else {
                    ProgressView().controlSize(.small).padding(.leading, CGFloat(depth + 1) * 12)
                }
            }
        })
    }
}
