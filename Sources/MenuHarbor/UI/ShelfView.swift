import AppKit
import SwiftUI

struct ShelfView: View {
    @ObservedObject var model: AppModel
    let dismiss: () -> Void

    @FocusState private var searchFocused: Bool
    /// 收纳模式下的快速聚焦入口：刘海真正挡住的项目通常只占一小部分，
    /// 先看它们比在整条菜单栏里找更快。这个筛选只在港湾打开期间生效。
    @State private var showAtRiskOnly = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.55)
            content
            footer
        }
        .background(VisualEffect(material: .popover, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
        .onExitCommand(perform: dismiss)
        .onMoveCommand(perform: moveSelection)
        .onChange(of: model.shelfFocusRequest) {
            // ShelfPanel 复用同一个 hosting view；每次重新打开都从“全部”开始，
            // 避免用户上次临时筛选状态悄悄影响下一次查找。
            showAtRiskOnly = false
            focusSearch()
        }
        .onChange(of: model.shelfSelectionIndex) { _, _ in clampShelfSelection() }
        .onChange(of: model.query) { _, _ in clampShelfSelection() }
        .onChange(of: model.atRiskItemIDs) { _, _ in clampShelfSelection() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("MenuHarbor 图标港湾")
        .onAppear { clampShelfSelection() }
    }

    private func focusSearch() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            searchFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.teal.gradient)
                Image(systemName: "rectangle.bottomhalf.inset.filled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text("HARBOR")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
            }

            Spacer(minLength: 8)

            if canFilterAtRisk {
                riskFilterButton
            }

            searchField

            if !model.isCollectOnlyMode {
                Button {
                    model.foldState == .folded ? model.expand() : model.fold()
                } label: {
                    Label(
                        model.foldState == .folded ? "展开" : "收起",
                        systemImage: model.foldState == .folded ? "arrow.right.to.line" : "arrow.left.to.line"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityHint("切换原生菜单栏图标的显示状态")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var statusText: String {
        if model.isCollectOnlyMode {
            if model.atRiskItemIDs.isEmpty {
                return "刘海安全 · \(model.items.count) 个图标可搜索"
            }
            return "刘海安全 · \(model.atRiskItemIDs.count) 个溢出图标已收纳"
        }
        return model.foldState == .folded ? "图标已安全收起" : "菜单栏已展开"
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索图标", text: $model.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit(activateSelected)
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 9)
        .frame(width: canFilterAtRisk ? 136 : 170, height: 28)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var canFilterAtRisk: Bool {
        model.isCollectOnlyMode && (!filteredAtRiskItems.isEmpty || showAtRiskOnly)
    }

    private var filteredAtRiskItems: [MenuBarItemDescriptor] {
        model.filteredItems.filter { model.atRiskItemIDs.contains($0.windowID) }
    }

    private var visibleItems: [MenuBarItemDescriptor] {
        guard showAtRiskOnly, model.isCollectOnlyMode else { return model.filteredItems }
        return filteredAtRiskItems
    }

    private var selectedItemID: UInt32? {
        guard model.filteredItems.indices.contains(model.shelfSelectionIndex) else { return nil }
        return model.filteredItems[model.shelfSelectionIndex].windowID
    }

    private var riskFilterButton: some View {
        Button {
            showAtRiskOnly.toggle()
            clampShelfSelection()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("\(filteredAtRiskItems.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(showAtRiskOnly ? Color.white : Color.orange)
            .frame(minWidth: 38, minHeight: 28)
            .background(
                showAtRiskOnly ? Color.orange : Color.orange.opacity(0.13),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.orange.opacity(showAtRiskOnly ? 0 : 0.35), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .help(showAtRiskOnly ? "显示全部菜单栏图标" : "只看可能被刘海挡住的图标")
        .accessibilityLabel(showAtRiskOnly ? "显示全部菜单栏图标" : "只看可能被刘海挡住的图标")
        .accessibilityValue("\(filteredAtRiskItems.count) 个匹配图标")
        .accessibilityAddTraits(showAtRiskOnly ? .isSelected : [])
    }

    @ViewBuilder
    private var content: some View {
        if model.items.isEmpty {
            emptyState
        } else if model.filteredItems.isEmpty {
            ContentUnavailableView(
                "没有找到图标",
                systemImage: "magnifyingglass",
                description: Text("换一个名称或应用名试试")
            )
            .frame(maxWidth: .infinity, minHeight: 132)
        } else if visibleItems.isEmpty {
            ContentUnavailableView(
                "没有溢出图标",
                systemImage: "checkmark.circle",
                description: Text("当前搜索结果都没有被刘海挡住")
            )
            .frame(maxWidth: .infinity, minHeight: 132)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                    ForEach(visibleItems) { item in
                        ShelfItemButton(
                            item: item,
                            image: model.snapshots[item.windowID],
                            selected: selectedItemID == item.windowID,
                            isAlwaysHidden: model.alwaysHiddenItemIDs.contains(item.windowID),
                            isAtRisk: model.atRiskItemIDs.contains(item.windowID)
                        ) {
                            dismiss()
                            Task { await model.activate(item) }
                        }
                    }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                }
                .defaultScrollAnchor(.trailing)
                .frame(minHeight: 132)
                .onChange(of: model.shelfSelectionIndex) { _, index in
                    guard model.filteredItems.indices.contains(index) else { return }
                    guard visibleItems.contains(where: { $0.id == model.filteredItems[index].id }) else { return }
                    proxy.scrollTo(model.filteredItems[index].id, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.isCollectOnlyMode {
            VStack(spacing: 9) {
                Image(systemName: "rectangle.and.text.magnifyingglass")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.teal)
                Text("暂时没有找到菜单栏图标")
                    .font(.system(size: 15, weight: .semibold))
                Text("菜单栏变化后，重新扫描即可更新刘海下方的港湾")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重新扫描") { model.refreshShelf(force: true) }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, minHeight: 132)
            .padding(.horizontal, 24)
        } else {
            VStack(spacing: 9) {
                Image(systemName: "arrow.left.and.line.vertical.and.arrow.right")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.teal)
                Text("把图标停靠到这里")
                    .font(.system(size: 15, weight: .semibold))
                Text("先显示全部图标，再按住 ⌘ 将图标拖到双箭头左侧")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("显示全部并开始整理") { model.restore() }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, minHeight: 132)
            .padding(.horizontal, 24)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let message = model.permissionMessage {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text(message)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button(model.missingPermission == .accessibility ? "开启辅助功能" : "开启屏幕录制") {
                    model.requestMissingPermission()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.teal)
            } else if let notice = model.notice {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.teal)
                Text(notice).lineLimit(1)
                Spacer()
            } else {
                Text("← → 选择")
                Text("↩︎ 打开")
                Spacer()
                Text(model.isCollectOnlyMode ? "\(model.preferences.shortcutDisplay) 打开港湾" : "\(model.preferences.shortcutDisplay) 切换")
            }
            Text("esc 关闭")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(Color.primary.opacity(0.035))
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        if showAtRiskOnly, model.isCollectOnlyMode {
            let items = visibleItems
            guard !items.isEmpty else { return }
            let currentIndex = selectedItemID.flatMap { selected in
                items.firstIndex(where: { $0.windowID == selected })
            } ?? (direction == .left ? items.count : -1)
            let nextIndex: Int
            switch direction {
            case .left:
                nextIndex = max(0, currentIndex - 1)
            case .right:
                nextIndex = min(items.count - 1, currentIndex + 1)
            default:
                return
            }
            guard let fullIndex = model.filteredItems.firstIndex(where: { $0.windowID == items[nextIndex].windowID }) else { return }
            model.shelfSelectionIndex = fullIndex
            return
        }

        switch direction {
        case .left:
            model.moveShelfSelection(by: -1)
        case .right:
            model.moveShelfSelection(by: 1)
        default:
            break
        }
    }

    private func activateSelected() {
        guard model.filteredItems.indices.contains(model.shelfSelectionIndex) else { return }
        let item = model.filteredItems[model.shelfSelectionIndex]
        dismiss()
        Task { await model.activate(item) }
    }

    /// Panel 里的本地方向键监视器直接修改 model 的索引；筛选开启时，
    /// 把它落到非溢出项目上会让视觉上没有选中项，因此在状态变化后就近回到
    /// 第一个仍可见的溢出项目。
    private func clampShelfSelection() {
        guard !model.filteredItems.isEmpty else {
            model.shelfSelectionIndex = 0
            return
        }

        guard showAtRiskOnly, model.isCollectOnlyMode else {
            model.shelfSelectionIndex = min(model.shelfSelectionIndex, model.filteredItems.count - 1)
            return
        }

        if let selectedItemID,
           model.atRiskItemIDs.contains(selectedItemID) {
            return
        }

        let riskIndices = model.filteredItems.indices.filter { index in
            model.atRiskItemIDs.contains(model.filteredItems[index].windowID)
        }
        guard !riskIndices.isEmpty else {
            showAtRiskOnly = false
            model.shelfSelectionIndex = min(model.shelfSelectionIndex, model.filteredItems.count - 1)
            return
        }

        let currentIndex = min(max(model.shelfSelectionIndex, 0), model.filteredItems.count - 1)
        model.shelfSelectionIndex = riskIndices.min {
            abs($0 - currentIndex) < abs($1 - currentIndex)
        } ?? riskIndices[0]
    }
}

private struct ShelfItemButton: View {
    let item: MenuBarItemDescriptor
    let image: NSImage?
    let selected: Bool
    let isAlwaysHidden: Bool
    let isAtRisk: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Group {
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                    } else if let appIcon = NSRunningApplication(processIdentifier: item.ownerPID)?.icon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "menubar.rectangle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 28, height: 28)
                .overlay(alignment: .topTrailing) {
                    if isAlwaysHidden {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.teal)
                            .padding(2)
                            .help("始终隐藏：展开菜单栏时它也保持收起")
                    } else if isAtRisk {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(2)
                            .help("可能被刘海或菜单栏溢出遮挡")
                    }
                }

                Text(item.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .frame(width: 56)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                selected ? Color.teal.opacity(0.16) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("\(item.name) · \(item.ownerName)")
        .accessibilityLabel("\(item.name)，来自 \(item.ownerName)\(isAlwaysHidden ? "，始终隐藏" : "")\(isAtRisk ? "，可能被刘海遮挡" : "")")
        .accessibilityHint("打开原菜单栏项目")
    }
}

private struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
