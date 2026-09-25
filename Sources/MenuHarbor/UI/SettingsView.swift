import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let openOnboarding: () -> Void
    @State private var section: Section = .general

    enum Section: String, CaseIterable, Identifiable {
        case general = "通用"
        case privacy = "权限与隐私"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "rectangle.bottomhalf.inset.filled")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MenuHarbor")
                        .font(.system(size: 17, weight: .semibold))
                    Text("让每一个菜单栏图标都可达")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("重新查看引导", action: openOnboarding)
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Section.allCases) { value in
                        Button {
                            section = value
                        } label: {
                            Label(value.rawValue, systemImage: value == .general ? "slider.horizontal.3" : "lock.shield")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(SettingsNavButton(isSelected: section == value))
                    }
                }
                .padding(12)
                .frame(width: 145)
                .background(Color.primary.opacity(0.035))

                Divider()

                ScrollView {
                    Group {
                        switch section {
                        case .general:
                            generalSection
                        case .privacy:
                            privacySection
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(width: 620, height: 440)
        .background(.background)
        .onAppear { model.startPermissionPolling() }
        .onDisappear { model.stopPermissionPolling() }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeading("菜单栏行为", subtitle: "MenuHarbor 只在需要时出现，不改变系统菜单栏外观。")

            if model.foldIsReliable == false {
                SettingsCard {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("折叠在本机不可用，已转入收纳模式")
                                .font(.system(size: 12, weight: .medium))
                            Text("当前系统（macOS 26+）会回收被折叠的图标，同类产品均受影响。MenuHarbor 已自动保持菜单栏展开，港湾仍可浏览和点击图标；恢复按钮可在整理时显示全部。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        Button("立即恢复") { model.restore() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    .padding(.vertical, 11)
                }
            }

            if model.isNotchAwareScreen {
                SettingsCard {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "rectangle.topthird.inset.filled")
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("刘海安全模式已自动开启")
                                .font(.system(size: 12, weight: .medium))
                            Text("MenuHarbor 会把当前屏幕的菜单栏图标集中到刘海下方，首次使用不需要逐个拖到分隔线。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 11)
                }
            }

            SettingsCard {
                if !model.isCollectOnlyMode {
                    SettingsRow(title: "自动收起", subtitle: "展开后无操作多久恢复隐藏图标") {
                        Picker("自动收起", selection: Binding(
                            get: { model.preferences.autoHideDelay },
                            set: { model.setAutoHideDelay($0) }
                        )) {
                            Text("关闭").tag(TimeInterval(0))
                            Text("5 秒").tag(TimeInterval(5))
                            Text("10 秒").tag(TimeInterval(10))
                            Text("30 秒").tag(TimeInterval(30))
                        }
                        .labelsHidden()
                        .frame(width: 90)
                    }
                    Divider()
                }
                SettingsRow(title: "快捷键", subtitle: model.isCollectOnlyMode ? "随时打开刘海下方港湾，点击左侧录制新组合" : "随时切换隐藏区和完整菜单栏，点击左侧录制新组合") {
                    HStack(spacing: 10) {
                        ShortcutRecorderButton(
                            display: model.preferences.shortcutDisplay
                        ) { keyCode, modifiers, display in
                            model.setShortcut(keyCode: keyCode, modifiers: modifiers, display: display)
                        }
                        Toggle("快捷键", isOn: Binding(
                            get: { model.preferences.shortcutEnabled },
                            set: { model.setShortcutEnabled($0) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                }
                Divider()
                SettingsRow(title: "悬停展开", subtitle: "鼠标在主按钮或刘海下方热区停留时自动打开港湾") {
                    Toggle("悬停展开", isOn: Binding(
                        get: { model.preferences.hoverOpensShelf },
                        set: { model.setHoverOpensShelf($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                Divider()
                SettingsRow(title: "滚动切换", subtitle: "在菜单栏上滚动滚轮即可收起或展开") {
                    Toggle("滚动切换", isOn: Binding(
                        get: { model.preferences.scrollTogglesMenuBar },
                        set: { model.setScrollTogglesMenuBar($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                Divider()
                SettingsRow(title: "登录时启动", subtitle: "开机后自动守护你的菜单栏") {
                    Toggle("登录时启动", isOn: Binding(
                        get: { model.preferences.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }

            sectionHeading("按钮样式", subtitle: "选择菜单栏右侧的 MenuHarbor 标记。")
            Picker("按钮样式", selection: Binding(
                get: { model.preferences.iconStyle },
                set: { model.setIconStyle($0) }
            )) {
                Label("港湾", systemImage: "rectangle.bottomhalf.inset.filled").tag(HarborPreferences.IconStyle.harbor)
                Label("圆点", systemImage: "circle.fill").tag(HarborPreferences.IconStyle.dot)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            SettingsCard {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("恢复全部图标")
                            .font(.system(size: 12, weight: .medium))
                        Text("进入整理模式，隐藏区和始终隐藏区的图标全部显示，方便重新布置。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("立即恢复") { model.restore() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    private var privacySection: some View {
        @ObservedObject var permissions = model.permissions
        return VStack(alignment: .leading, spacing: 18) {
            sectionHeading("按需授权", subtitle: model.isNotchAwareScreen ? "刘海下方的基础收纳不需要权限；增强能力全部在本机完成。" : "基础折叠不需要权限。增强能力全部在本机完成。")
            SettingsCard {
                PermissionRow(
                    icon: "rectangle.dashed.and.paperclip",
                    title: "屏幕录制",
                    subtitle: "读取菜单栏图标的外观，生成港湾里的缩略图。",
                    isGranted: permissions.hasScreenCapturePermission,
                    grant: model.requestScreenCapture,
                    openSettings: permissions.openScreenCaptureSettings
                )
                Divider()
                PermissionRow(
                    icon: "hand.tap",
                    title: "辅助功能",
                    subtitle: "在你点按港湾图标时，代为点击原生菜单栏项目。",
                    isGranted: permissions.hasAccessibilityPermission,
                    grant: model.requestAccessibility,
                    openSettings: permissions.openAccessibilitySettings
                )
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.teal)
                Text("MenuHarbor 不联网、不上传截图、不建立账号。拒绝任一权限不会影响基础折叠和手动展开。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 3)
        }
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

private struct SettingsNavButton: ButtonStyle {
    let isSelected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.teal.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 14)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5) }
    }
}

private struct SettingsRow<Accessory: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            accessory
        }
        .padding(.vertical, 11)
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool
    let grant: () -> Void
    let openSettings: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundStyle(isGranted ? .teal : .orange).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 12, weight: .medium))
                    Text(isGranted ? "已开启" : "未开启").font(.system(size: 10, weight: .medium)).foregroundStyle(isGranted ? .teal : .orange)
                }
                Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(isGranted ? "管理" : "开启") { isGranted ? openSettings() : grant() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.vertical, 13)
    }
}
