import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    let finish: () -> Void
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("MENUHARBOR", systemImage: "rectangle.bottomhalf.inset.filled")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.teal)
                Spacer()
                Text("\(step + 1) / 3").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)

            Group {
                switch step {
                case 0: welcome
                case 1: arrange
                default: permissions
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button("稍后再说") { model.completeOnboarding(); finish() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(step == 2 ? "开始使用" : "继续") {
                    if step == 2 { model.completeOnboarding(); finish() } else { withAnimation(.easeOut(duration: 0.18)) { step += 1 } }
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .controlSize(.large)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 22)
        }
        .frame(width: 540, height: 410)
        .background(.background)
        .onAppear { model.startPermissionPolling() }
        .onDisappear { model.stopPermissionPolling() }
    }

    private var welcome: some View {
        OnboardingPage(
            icon: "rectangle.bottomhalf.inset.filled",
            eyebrow: "先把空间还给你",
            title: "图标被刘海挡住？\n把它们停进港湾。",
            message: "MenuHarbor 会在刘海下方提供一个固定入口，把当前屏幕的菜单栏图标集中到港湾；点一下即可搜索或点击。基础收纳不需要任何权限。"
        )
    }

    private var arrange: some View {
        VStack(spacing: 18) {
            HStack(spacing: 5) {
                ForEach(0..<7) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(index == 4 ? Color.teal : Color.primary.opacity(index < 4 ? 0.24 : 0.10))
                        .frame(width: index == 4 ? 32 : 18, height: 18)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.05), in: Capsule())
            .overlay(alignment: .leading) {
                Image(systemName: "chevron.left.2")
                    .foregroundStyle(.teal)
                    .offset(x: 157)
            }
            .padding(.top, 22)

            VStack(spacing: 9) {
                Text(model.isNotchAwareScreen ? "刘海屏自动整理" : "只需要整理一次")
                    .font(.system(size: 23, weight: .semibold))
                Text(model.isNotchAwareScreen
                    ? "在这台 Mac 上，MenuHarbor 会自动收集当前屏幕的菜单栏图标。你可以直接在刘海下方搜索，不需要手动拖拽。"
                    : "展开菜单栏，按住 ⌘ 将不常用的图标拖到双箭头左侧。\n拖到最左侧竖线标记左边的图标会始终保持隐藏，只在港湾中出现。")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            Spacer()
        }
        .padding(.horizontal, 30)
    }

    private var permissions: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.teal)
                Text("要不要开启增强模式？")
                    .font(.system(size: 22, weight: .semibold))
                Text("屏幕录制用来显示图标外观，辅助功能用来代你点击原图标。\n两项都只在本机使用，也可以稍后在设置里开启。")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .padding(.top, 18)

            HStack(spacing: 10) {
                PermissionPill(icon: "rectangle.dashed.and.paperclip", title: "图标预览", granted: model.permissions.hasScreenCapturePermission) { model.requestScreenCapture() }
                PermissionPill(icon: "hand.tap", title: "直接点击", granted: model.permissions.hasAccessibilityPermission) { model.requestAccessibility() }
            }
            Spacer()
        }
        .padding(.horizontal, 26)
    }
}

private struct OnboardingPage: View {
    let icon: String
    let eyebrow: String
    let title: String
    let message: String
    var bodyView: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 42, weight: .medium)).foregroundStyle(.teal).padding(.top, 30)
            Text(eyebrow.uppercased()).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(.secondary)
            Text(title).font(.system(size: 27, weight: .semibold)).multilineTextAlignment(.center)
            Text(message).font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(3).frame(maxWidth: 380)
            Spacer()
        }
    }
    var body: some View { bodyView }
}

private struct PermissionPill: View {
    let icon: String
    let title: String
    let granted: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(granted ? .teal : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 11, weight: .medium))
                    Text(granted ? "已开启" : "点击授权").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: granted ? "checkmark.circle.fill" : "arrow.up.right.square")
                    .foregroundStyle(granted ? .teal : .secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
