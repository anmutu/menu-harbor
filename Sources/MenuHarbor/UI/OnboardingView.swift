import SwiftUI

// MARK: - 引导主视图

/// 六步交互式使用教程：左侧步骤栏可随时跳转，键盘 ←/→ 翻页。
struct OnboardingView: View {
    @ObservedObject var model: AppModel
    let finish: () -> Void

    @State private var step = 0
    /// +1 前进 / -1 后退，决定页面切换的滑动方向。
    @State private var travel = 1
    @State private var visited: Set<Int> = [0]

    private static let titles = ["欢迎", "打开港湾", "搜索与打开", "增强模式", "整理图标", "更多技巧"]

    var body: some View {
        HStack(spacing: 0) {
            stepRail
            Divider()
            VStack(spacing: 0) {
                topBar
                ZStack {
                    page
                        .id(step)
                        .transition(.asymmetric(
                            insertion: .move(edge: travel > 0 ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: travel > 0 ? .leading : .trailing).combined(with: .opacity)
                        ))
                }
                .clipped()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.32, dampingFraction: 0.9), value: step)
                bottomBar
            }
        }
        .frame(width: 720, height: 500)
        .background(.background)
        .onAppear {
            model.startPermissionPolling()
            // 演示深链：设置 TOUR_STEP=n 可直接从第 n 步开始（仅在引导本身会展示时生效）。
            if let raw = ProcessInfo.processInfo.environment["TOUR_STEP"],
               let index = Int(raw), Self.titles.indices.contains(index) {
                step = index
                visited = Set(0...index)
            }
        }
        .onDisappear { model.stopPermissionPolling() }
        .onMoveCommand { direction in
            switch direction {
            case .left where step > 0: goTo(step - 1)
            case .right where step < Self.titles.count - 1: goTo(step + 1)
            default: break
            }
        }
    }

    // MARK: 步骤栏

    private var stepRail: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("使用教程")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 7)
            ForEach(Self.titles.indices, id: \.self) { index in
                railButton(index)
            }
            Spacer(minLength: 12)
            Text("← → 翻页")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
        }
        .padding(14)
        .frame(width: 150, alignment: .topLeading)
        .background(Color.primary.opacity(0.03))
    }

    private func railButton(_ index: Int) -> some View {
        let isCurrent = index == step
        let isVisited = visited.contains(index)
        return Button {
            goTo(index)
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isCurrent ? AnyShapeStyle(Color.teal) : isVisited ? AnyShapeStyle(Color.teal.opacity(0.15)) : AnyShapeStyle(Color.primary.opacity(0.09)))
                        .frame(width: 21, height: 21)
                    if isCurrent {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    } else if isVisited {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.teal)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(Self.titles[index])
                    .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? .primary : .secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.teal.opacity(0.1))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 顶栏与底栏

    private var topBar: some View {
        HStack {
            Label("MENUHARBOR", systemImage: "rectangle.bottomhalf.inset.filled")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(.teal)
            Spacer()
            Text("\(step + 1) / \(Self.titles.count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }

    private var bottomBar: some View {
        HStack {
            Button("稍后再说") {
                model.completeOnboarding()
                finish()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Spacer()
            if step > 0 {
                Button("上一步") { goTo(step - 1) }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            Button(step == Self.titles.count - 1 ? "开始使用" : "继续") { advance() }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private func goTo(_ target: Int) {
        guard Self.titles.indices.contains(target) else { return }
        travel = target >= step ? 1 : -1
        step = target
        visited.insert(target)
    }

    private func advance() {
        if step == Self.titles.count - 1 {
            model.completeOnboarding()
            finish()
        } else {
            goTo(step + 1)
        }
    }

    // MARK: 各步骤

    @ViewBuilder
    private var page: some View {
        switch step {
        case 0: WelcomePage()
        case 1: EntryPage(hasNotch: model.isNotchAwareScreen, shortcut: model.preferences.shortcutDisplay)
        case 2: SearchPlaygroundPage(shortcut: model.preferences.shortcutDisplay)
        case 3: PermissionPage(model: model)
        case 4: ArrangePage(isNotch: model.isNotchAwareScreen)
        default: FinishPage(shortcut: model.preferences.shortcutDisplay)
        }
    }
}

// MARK: - 第 1 步：欢迎（动画舞台）

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 0) {
            NotchTheater()
                .padding(.top, 6)
            VStack(spacing: 9) {
                Text("图标被刘海挡住？\n把它们停进港湾。")
                    .font(.system(size: 23, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("MenuHarbor 把当前屏幕的菜单栏图标集中到刘海下方的安全港湾：点一下入口即可搜索、点击，原生菜单栏保持稳定。基础收纳不需要任何权限。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 420)
            }
            .padding(.top, 16)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }
}

/// 循环小剧场：图标被刘海吞掉 → 刘海下方浮出港湾入口 → 图标停进 Shelf → 搜一下立刻找到。
private struct NotchTheater: View {
    static let cycle = 7.4

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.cycle)
            ZStack(alignment: .top) {
                bar(t)
                chip(t)
                panel(t)
            }
            .frame(width: 440, height: 196)
            .opacity(appear(t) * (1 - seg(t, 6.9, 7.35)))
        }
    }

    // MARK: 菜单栏

    private func bar(_ t: Double) -> some View {
        let drift = easeInOut(seg(t, 1.05, 2.05))
        let sink = seg(t, 1.7, 2.05)
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.09))
            UnevenRoundedRectangle(bottomLeadingRadius: 7, bottomTrailingRadius: 7, style: .continuous)
                .fill(Color.black.opacity(0.9))
                .overlay {
                    UnevenRoundedRectangle(bottomLeadingRadius: 7, bottomTrailingRadius: 7, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                }
                .frame(width: 124, height: 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule().fill(Color.primary.opacity(0.16)).frame(width: 22, height: 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            HStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { index in
                    let isVictim = index < 2
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(isVictim ? Color.teal.opacity(0.75) : Color.primary.opacity(0.22))
                        .frame(width: 13, height: 13)
                        .overlay {
                            if isVictim {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(Color.orange, lineWidth: 1.2)
                                    .opacity(seg(t, 0.7, 1.0))
                            }
                        }
                        .opacity(isVictim ? 1 - sink : 1)
                        .offset(x: isVictim ? -86 * drift : 0)
                        .scaleEffect(isVictim ? 1 - 0.35 * drift : 1, anchor: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 13)
        }
        .frame(width: 440, height: 34)
    }

    // MARK: 刘海下方的港湾入口

    private func chip(_ t: Double) -> some View {
        let pop = easeOut(seg(t, 2.15, 2.6))
        return HStack(spacing: 5) {
            Image(systemName: "rectangle.bottomhalf.inset.filled")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
            Text("HARBOR")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.92))
            ZStack {
                Circle().fill(Color.orange)
                Text("2")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 15, height: 15)
            .offset(x: 2)
            .opacity(pop)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Color.teal.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .scaleEffect(0.4 + 0.6 * pop, anchor: .top)
        .opacity(seg(t, 2.15, 2.4))
        .offset(y: 38 + 8 * (1 - pop))
    }

    // MARK: Shelf 面板

    private func panel(_ t: Double) -> some View {
        let drop = easeOut(seg(t, 2.7, 3.3))
        let typed = Int(seg(t, 3.7, 4.5) * 3)
        let match = seg(t, 4.6, 5.0)
        let wifiDock = seg(t, 3.0, 3.35)
        let chatDock = seg(t, 3.15, 3.5)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("wfi".prefix(max(0, typed)))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                Rectangle()
                    .fill(Color.teal)
                    .frame(width: 1.2, height: 11)
                    .opacity(Double((t * 1.6).truncatingRemainder(dividingBy: 1) < 0.55 ? 1 : 0))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            HStack(spacing: 14) {
                dockedIcon(symbol: "wifi", name: "WiFi", shown: wifiDock) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.teal, lineWidth: 1.4)
                        .opacity(match)
                }
                .scaleEffect(1 + 0.08 * match)
                dockedIcon(symbol: "message", name: "微信", shown: chatDock) {}
                    .opacity(1 - 0.75 * match)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 7, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7, weight: .semibold))
                    Text("选择 · ↩︎ 打开")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .opacity(seg(t, 5.1, 5.5))
            }
        }
        .padding(10)
        .frame(width: 236, height: 84)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
        .offset(y: 72 + 12 * (1 - drop))
        .opacity(seg(t, 2.7, 3.0) * drop)
    }

    private func dockedIcon(symbol: String, name: String, shown: Double, @ViewBuilder ring: () -> some View) -> some View {
        HStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.teal.opacity(0.14))
                    .frame(width: 20, height: 20)
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.teal)
                ring()
                    .frame(width: 22, height: 22)
            }
            Text(name)
                .font(.system(size: 10, weight: .medium))
        }
        .opacity(shown)
        .offset(x: -6 * (1 - shown))
    }

    // MARK: 时间轴工具

    private func appear(_ t: Double) -> Double { easeOut(seg(t, 0.05, 0.5)) }
}

// MARK: - 第 2 步：打开港湾（入口）

private struct EntryPage: View {
    let hasNotch: Bool
    let shortcut: String

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                eyebrow: "入口",
                title: "看得到就点，看不到就按快捷键",
                message: "四种方式打开同一个港湾，总有一个顺手。"
            )
            VStack(spacing: 9) {
                entryCard(
                    illustration: MiniBar(hasNotch: true, rightContent: .icons),
                    title: "刘海下方的港湾按钮",
                    subtitle: hasNotch
                        ? "你的屏幕就有：固定在刘海正下方，永远不会被图标挤走。"
                        : "带刘海的屏幕会出现：固定在刘海正下方，不会被图标挤走。"
                )
                entryCard(
                    illustration: MiniBar(hasNotch: false, rightContent: .anchor),
                    title: "菜单栏里的 MenuHarbor 主按钮",
                    subtitle: "日常最顺手的一个：应用常驻菜单栏，点一下打开港湾。"
                )
                entryCard(
                    illustration: AnyView(ShortcutCaps(shortcut: shortcut)),
                    title: "全局快捷键 \(shortcut)",
                    subtitle: "最可靠的保底入口，全屏工作也有效；可以在设置里重新录制。"
                )
                entryCard(
                    illustration: AnyView(HoverCursor()),
                    title: "悬停展开（默认开启）",
                    subtitle: "鼠标停在主按钮或刘海下方约 0.25 秒自动打开，移开自动收起。"
                )
            }
            .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    private func entryCard<I: View>(illustration: I, title: String, subtitle: String) -> some View {
        HStack(spacing: 13) {
            illustration
                .frame(width: 132)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(1.5)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// 入口卡片里的小菜单栏示意。
private struct MiniBar: View {
    enum RightContent { case icons, anchor }
    let hasNotch: Bool
    let rightContent: RightContent

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 20)
                if hasNotch {
                    UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4, style: .continuous)
                        .fill(Color.black.opacity(0.9))
                        .overlay {
                            UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                        }
                        .frame(width: 46, height: 13)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                HStack(spacing: 4) {
                    switch rightContent {
                    case .icons:
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.primary.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    case .anchor:
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.teal.gradient)
                            .frame(width: 12, height: 12)
                            .overlay {
                                Image(systemName: "rectangle.bottomhalf.inset.filled")
                                    .font(.system(size: 7, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 7)
            }
            if hasNotch {
                HStack(spacing: 2) {
                    Image(systemName: "rectangle.bottomhalf.inset.filled")
                        .font(.system(size: 6, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 6)
                .frame(height: 11)
                .background(Color.teal.gradient, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Color.clear.frame(height: 11)
            }
        }
        .frame(width: 132, height: 34)
    }
}

/// 自动依次按下的快捷键键帽。
private struct ShortcutCaps: View {
    let shortcut: String
    static let cycle = 2.7

    private var glyphs: [String] { Array(shortcut).map(String.init) }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.cycle)
            HStack(spacing: 5) {
                ForEach(glyphs.indices, id: \.self) { index in
                    KeyCap(glyph: glyphs[index], pressed: pressed(index, at: t))
                }
            }
            .frame(width: 132)
        }
    }

    private func pressed(_ index: Int, at t: Double) -> Bool {
        let slot = t - 0.25 - Double(index) * 0.85
        return slot >= 0 && slot < 0.55
    }
}

private struct KeyCap: View {
    let glyph: String
    var pressed: Bool = false

    var body: some View {
        Text(glyph)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(pressed ? .white : .primary)
            .frame(width: 24, height: 24)
            .background(
                pressed ? AnyShapeStyle(Color.teal) : AnyShapeStyle(Color.primary.opacity(0.07)),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(pressed ? 0 : 0.1), lineWidth: 0.5)
            }
            .scaleEffect(pressed ? 0.9 : 1)
    }
}

/// 悬停示意：光标 + 呼吸光圈。
private struct HoverCursor: View {
    var body: some View {
        Image(systemName: "cursorarrow.click.2")
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(.teal)
            .symbolEffect(.pulse, options: .repeating)
            .frame(width: 132)
    }
}

// MARK: - 第 3 步：搜索试验场

private struct SearchPlaygroundPage: View {
    let shortcut: String

    @State private var query = ""
    @State private var tappedID: String?

    private struct DemoItem: Identifiable {
        let name: String
        let symbol: String
        let tint: Color
        var id: String { name }
    }

    private static let items: [DemoItem] = [
        .init(name: "WiFi", symbol: "wifi", tint: .blue),
        .init(name: "蓝牙", symbol: "dot.radiowaves.left.and.right", tint: .blue),
        .init(name: "VPN", symbol: "key.horizontal", tint: .purple),
        .init(name: "微信", symbol: "message", tint: .green),
        .init(name: "会议", symbol: "video", tint: .blue),
        .init(name: "云盘", symbol: "externaldrive.badge.icloud", tint: .teal),
        .init(name: "输入法", symbol: "globe", tint: .orange),
        .init(name: "电池", symbol: "battery.100", tint: .green),
    ]

    /// 与真实港湾同一套宽松匹配：折叠大小写/声调/全角后先找包含、再找按顺序的子序列。
    static func matches(_ query: String, name: String) -> Bool {
        let foldedQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
        guard !foldedQuery.isEmpty else { return true }
        let foldedName = name.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        if foldedName.contains(foldedQuery) { return true }
        var cursor = foldedName.startIndex
        for character in foldedQuery {
            guard let hit = foldedName[cursor...].firstIndex(of: character) else { return false }
            cursor = foldedName.index(after: hit)
        }
        return true
    }

    private var results: [DemoItem] {
        Self.items.filter { Self.matches(query, name: $0.name) }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                eyebrow: "试一试",
                title: "搜一下，点一下",
                message: "这是真实港湾的迷你版：试试 wifi、乱序的 wfi，或直接输入“微信”。"
            )
            searchField
                .padding(.top, 14)
            if !query.isEmpty && results.isEmpty {
                VStack(spacing: 5) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                    Text("没有找到“\(query)”。真实港湾会持续同步菜单栏，也可以点“重新扫描”。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(results) { item in
                        demoCell(item)
                    }
                }
                .padding(.top, 12)
            }
            Spacer(minLength: 0)
            keyboardFlow
                .padding(.bottom, 4)
        }
        .padding(.horizontal, 24)
        .onExitCommand { query = "" }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("点这里输入：wifi / wfi / 微信", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 9)
        .frame(width: 250, height: 30)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func demoCell(_ item: DemoItem) -> some View {
        let isTapped = tappedID == item.name
        return Button {
            tappedID = item.name
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                if tappedID == item.name { tappedID = nil }
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(item.tint.opacity(0.13))
                    Image(systemName: item.symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(item.tint)
                    if isTapped {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.teal, lineWidth: 1.6)
                    }
                }
                .frame(height: 36)
                Text(item.name)
                    .font(.system(size: 10.5, weight: isTapped ? .semibold : .regular))
                    .foregroundStyle(isTapped ? .primary : .secondary)
                    .lineLimit(1)
            }
            .padding(6)
            .background(
                isTapped ? AnyShapeStyle(Color.teal.opacity(0.08)) : AnyShapeStyle(Color.primary.opacity(0.035)),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .scaleEffect(isTapped ? 1.04 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isTapped)
        }
        .buttonStyle(.plain)
        .accessibilityHint("演示图标：真实港湾中点击会打开对应的原生菜单")
    }

    /// 底部的完整键盘流：快捷键 → 输入 → 选择 → 打开 → 关闭。
    private var keyboardFlow: some View {
        HStack(spacing: 5) {
            flowChip(caps: [shortcut], label: "打开")
            flowArrow
            flowChip(caps: [], label: "输入名字")
            flowArrow
            flowChip(caps: ["←", "→"], label: "选择")
            flowArrow
            flowChip(caps: ["↩︎"], label: "打开")
            flowArrow
            flowChip(caps: ["esc"], label: "关闭")
        }
    }

    private var flowArrow: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    private func flowChip(caps: [String], label: String) -> some View {
        HStack(spacing: 4) {
            ForEach(caps, id: \.self) { cap in
                Text(cap)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .padding(.horizontal, 4)
                    .frame(height: 16)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.035), in: Capsule())
    }
}

// MARK: - 第 4 步：增强模式（权限）

private struct PermissionPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                eyebrow: "可选增强",
                title: "两项权限，解锁完整体验",
                message: "基础收纳、入口和搜索现在就能用。开启后图标更真实、还能代你点击原生菜单。"
            )
            VStack(spacing: 10) {
                permissionCard(
                    icon: "rectangle.dashed.and.paperclip",
                    tint: .teal,
                    title: "屏幕录制",
                    enabled: model.permissions.hasScreenCapturePermission,
                    detail: "开启后：港湾显示图标的真实快照，一眼认出目标。",
                    fallback: "未开启：仍可看到名称列表，缩略图用通用图标代替。不保存任何截图。"
                ) { model.requestScreenCapture() }
                permissionCard(
                    icon: "hand.tap",
                    tint: .indigo,
                    title: "辅助功能",
                    enabled: model.permissions.hasAccessibilityPermission,
                    detail: "开启后：名称更准确，并尝试以语义按压代你点击原图标。",
                    fallback: "未开启：搜索照常可用，点击会退回手动展开原生菜单栏。"
                ) { model.requestAccessibility() }
            }
            .padding(.top, 16)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 12))
                    .foregroundStyle(.teal)
                Text("两项权限都只在本机使用：不联网、无账号、不上传数据；稍后也可在“设置 → 权限与隐私”开启，授权后这里会实时更新。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .frame(maxWidth: 430)
            }
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 24)
    }

    private func permissionCard(icon: String, tint: Color, title: String, enabled: Bool, detail: String, fallback: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.13))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    if enabled {
                        Label("已开启", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.teal)
                            .labelStyle(.titleAndIcon)
                    }
                }
                Text(detail)
                    .font(.system(size: 11))
                Text(fallback)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if enabled {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(.teal)
            } else {
                Button("去开启", action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - 第 5 步：整理图标

private struct ArrangePage: View {
    let isNotch: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isNotch {
                collectMode
            } else {
                foldMode
            }
        }
        .padding(.horizontal, 24)
    }

    /// 刘海屏：自动收纳，讲“只看溢出”。
    private var collectMode: some View {
        VStack(spacing: 0) {
            PageHeader(
                eyebrow: "自动收纳",
                title: "这台 Mac 不需要整理",
                message: "MenuHarbor 保持原生菜单栏稳定，自动收集当前屏幕的全部图标到港湾。你只需要认识一个标记：橙色。"
            )
            RiskStrip()
                .padding(.top, 14)
            VStack(alignment: .leading, spacing: 8) {
                legendRow(color: .orange, icon: "exclamationmark.circle.fill", text: "带橙色警示的图标可能被刘海挡住，港湾会把它们排在最前面。")
                legendRow(color: .teal, icon: "number.circle.fill", text: "顶部橙色数字是溢出数量，点它切换“只看溢出”，再点一次恢复全部。")
                legendRow(color: .teal, icon: "arrow.triangle.2.circlepath", text: "图标增减、VPN 或会议工具启动时，港湾打开期间会自动同步。")
            }
            .padding(.top, 14)
            .frame(maxWidth: 420, alignment: .leading)
            Spacer(minLength: 0)
        }
    }

    /// 无刘海屏：三区整理 + ⌘ 拖拽动画。
    private var foldMode: some View {
        VStack(spacing: 0) {
            PageHeader(
                eyebrow: "三区整理",
                title: "按住 ⌘ 拖一次，从此清爽",
                message: "不常用的图标折进隐藏区，常用的一眼可见；全部图标始终能在港湾里搜到。"
            )
            FoldStrip()
                .padding(.top, 14)
            VStack(alignment: .leading, spacing: 8) {
                legendRow(color: .teal, icon: "chevron.left.2", text: "双箭头分隔标记左侧：隐藏区，收起菜单栏时自动折叠。")
                legendRow(color: .secondary, icon: "line.diagonal", text: "最左侧竖线标记左侧：始终隐藏区，只在港湾中出现，带圆钉标记。")
                legendRow(color: .teal, icon: "contextualmenu.and.cursorarrow", text: "想重新布置：右键 MenuHarbor 主按钮 → 整理模式（显示全部）。")
            }
            .padding(.top, 14)
            .frame(maxWidth: 430, alignment: .leading)
            Spacer(minLength: 0)
        }
    }

    private func legendRow(color: Color, icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 15)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 刘海屏示意：一排图标里两个带橙色警示 + “只看溢出”入口。
private struct RiskStrip: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.6, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            VStack(spacing: 7) {
                HStack(spacing: 9) {
                    riskIcon("wifi", atRisk: true, pulse: 0.5 + 0.5 * sin(t * 2.4))
                    riskIcon("video", atRisk: true, pulse: 0.5 + 0.5 * cos(t * 2.4))
                    riskIcon("message", atRisk: false, pulse: 0)
                    riskIcon("externaldrive.badge.icloud", atRisk: false, pulse: 0)
                    riskIcon("globe", atRisk: false, pulse: 0)
                    riskIcon("battery.100", atRisk: false, pulse: 0)
                }
                HStack(spacing: 5) {
                    Text("2")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.orange))
                    Text("只看溢出")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.14), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.orange.opacity(0.5), lineWidth: 1)
                }
                Text("示意：顶部入口显示当前溢出数量，点击后只剩橙色两项")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func riskIcon(_ symbol: String, atRisk: Bool, pulse: Double) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(atRisk ? .orange : .secondary)
            }
            .frame(width: 40, height: 34)
            if atRisk {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.orange, lineWidth: 1.4)
                    .frame(width: 40, height: 34)
                    .opacity(0.45 + 0.55 * pulse)
            }
        }
    }
}

/// 无刘海屏示意：一个图标在 ⌘ 的护送下滑进隐藏区。
private struct FoldStrip: View {
    static let cycle = 4.6

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.cycle)
            HStack(spacing: 0) {
                // 始终隐藏区
                icon("key.horizontal", dimmed: true)
                    .overlay(alignment: .bottom) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.teal)
                            .offset(y: 9)
                    }
                divider
                // 隐藏区（动画目标落点）
                ZStack {
                    Capsule().fill(Color.teal.opacity(0.1)).frame(width: 34, height: 26)
                    Image(systemName: "video")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.teal)
                        .opacity(landed(t))
                }
                Image(systemName: "chevron.left.2")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 7)
                // 可见区
                icon("wifi")
                icon("message")
                icon("battery.100")
                // 拖动中的图标
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.teal.gradient)
                    .frame(width: 15, height: 15)
                    .overlay {
                        Image(systemName: "video")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay(alignment: .top) {
                        Text("⌘")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .background(Capsule().fill(Color.orange))
                            .offset(y: -13)
                    }
                    .offset(x: dragX(t))
                    .opacity(1 - seg(t, 3.5, 3.9))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: 400)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.25))
            .frame(width: 2, height: 20)
            .padding(.horizontal, 7)
    }

    private func icon(_ symbol: String, dimmed: Bool = false) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(dimmed ? .tertiary : .secondary)
            .padding(.horizontal, 4)
    }

    /// 0–3.3 秒从右往左滑过双箭头，停一拍后淡出重来。
    private func dragX(_ t: Double) -> CGFloat {
        let progress = easeInOut(seg(t, 0.35, 3.1))
        return CGFloat(lerp(96, -168, progress))
    }

    private func landed(_ t: Double) -> Double { seg(t, 3.1, 3.45) }
}

// MARK: - 第 6 步：更多技巧

private struct FinishPage: View {
    let shortcut: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    private var tips: [(icon: String, title: String, detail: String)] {
        [
            ("cursorarrow.click.2", "悬停展开", "停在入口 0.25 秒自动打开，默认开启。"),
            ("keyboard", "键盘流", "\(shortcut) 打开 → 输入 → ← → 选择 → ↩︎ 打开。"),
            ("arrow.up.arrow.down", "滚动切换", "在菜单栏上滚动即可开关港湾，默认关闭。"),
            ("contextualmenu.and.cursorarrow", "整理模式", "右键主按钮显示全部图标，随时重新布置。"),
            ("timer", "自动收起", "展开后 5 / 10 / 30 秒无操作自动隐藏。"),
            ("power", "登录启动", "开机即可用，在 设置 → 通用 开启。"),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                eyebrow: "就绪",
                title: "还有几招，用起来更顺",
                message: "都记不住也没关系——右键 MenuHarbor 主按钮，或在设置里随时重看这份引导。"
            )
            VStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: tip.icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.teal)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tip.title)
                                    .font(.system(size: 11.5, weight: .semibold))
                                Text(tip.detail)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(1.5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.bottom, 13)
                HStack(spacing: 7) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.teal)
                    Text("所有数据留在本机：不联网、无账号、不上传截图。\n祝你在港湾里找回一条干净的菜单栏。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
                .padding(12)
                .background(Color.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - 共用小组件

private struct PageHeader: View {
    let eyebrow: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.teal)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2.5)
                .frame(maxWidth: 430)
        }
        .padding(.top, 14)
    }
}

// MARK: - 动画曲线工具

private func seg(_ t: Double, _ from: Double, _ to: Double) -> Double {
    guard to > from else { return t >= to ? 1 : 0 }
    let x = (t - from) / (to - from)
    return min(max(x, 0), 1)
}

private func easeOut(_ x: Double) -> Double {
    1 - pow(1 - x, 2.2)
}

private func easeInOut(_ x: Double) -> Double {
    x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
}

private func lerp(_ a: Double, _ b: Double, _ x: Double) -> Double {
    a + (b - a) * x
}
