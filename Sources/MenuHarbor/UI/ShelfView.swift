import AppKit
import SwiftUI

struct ShelfView: View {
    @ObservedObject var model: AppModel
    let dismiss: () -> Void

    @FocusState private var searchFocused: Bool
    @State private var selectedIndex = 0

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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("MenuHarbor 图标港湾")
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
                Text(model.foldState == .folded ? "图标已安全收起" : "菜单栏已展开")
                    .font(.system(size: 12, weight: .medium))
            }

            Spacer(minLength: 8)

            searchField

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
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
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
        .frame(width: 170, height: 28)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(model.filteredItems.enumerated()), id: \.element.id) { index, item in
                        ShelfItemButton(
                            item: item,
                            image: model.snapshots[item.windowID],
                            selected: index == selectedIndex
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
        }
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(systemName: "arrow.left.and.line.vertical.and.arrow.right")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.teal)
            Text("把图标停靠到这里")
                .font(.system(size: 15, weight: .semibold))
            Text("先展开菜单栏，再按住 ⌘ 将图标拖到双箭头左侧")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("展开并开始整理") { model.expand() }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 132)
        .padding(.horizontal, 24)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let message = model.permissionMessage {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text(message)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button("开启") {
                    model.requestScreenCapture()
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
                Text("⌃⌥H 切换")
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
        let count = model.filteredItems.count
        guard count > 0 else { return }
        switch direction {
        case .left:
            selectedIndex = max(0, selectedIndex - 1)
        case .right:
            selectedIndex = min(count - 1, selectedIndex + 1)
        default:
            break
        }
    }

    private func activateSelected() {
        guard model.filteredItems.indices.contains(selectedIndex) else { return }
        let item = model.filteredItems[selectedIndex]
        dismiss()
        Task { await model.activate(item) }
    }
}

private struct ShelfItemButton: View {
    let item: MenuBarItemDescriptor
    let image: NSImage?
    let selected: Bool
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
        .accessibilityLabel("\(item.name)，来自 \(item.ownerName)")
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

