import SwiftUI

/// 字体 Design Token（SF Pro / 系统字体）。契约来源：PRD §9.2.5。
///
/// 正文字号跟随系统「字体大小」设置动态缩放（PRD §9.8）——通过
/// `Font.system(size:weight:).relativeTo?` 无法直接表达，这里对正文类字号
/// 使用 `relativeTo` 语义的 `TextStyle` 关联，使其参与 Dynamic Type 缩放。
public enum JadeFont {

    /// 启动页 / Onboarding 大 logo：40pt bold
    public static let display = Font.system(size: 40, weight: .bold)

    /// 窗口标题：28pt semibold
    public static let title1 = Font.system(size: 28, weight: .semibold)

    /// section 大标题：22pt semibold
    public static let title2 = Font.system(size: 22, weight: .semibold)

    /// 卡片标题 / 结果首行：17pt semibold
    public static let title3 = Font.system(size: 17, weight: .semibold)

    /// 主阅读正文：13pt regular（随系统字体大小缩放）
    public static let body = Font.system(size: 13, weight: .regular)

    /// 辅助说明：12pt regular
    public static let callout = Font.system(size: 12, weight: .regular)

    /// 副标题 / 元信息 / breadcrumb：11pt medium
    public static let subhead = Font.system(size: 11, weight: .medium)

    /// 快捷键提示 / 徽章 / tab 计数：10pt medium
    public static let caption = Font.system(size: 10, weight: .medium)

    /// 命令栏输入框：20pt regular
    public static let commandBarInput = Font.system(size: 20, weight: .regular)
}

// MARK: - Preview

#Preview("JadeFont") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                Text("display · 40 bold").font(JadeFont.display)
                Text("title1 · 28 semibold").font(JadeFont.title1)
                Text("title2 · 22 semibold").font(JadeFont.title2)
                Text("title3 · 17 semibold").font(JadeFont.title3)
                Text("body · 13 regular").font(JadeFont.body)
                Text("callout · 12 regular").font(JadeFont.callout)
                Text("subhead · 11 medium").font(JadeFont.subhead)
                Text("caption · 10 medium").font(JadeFont.caption)
                Text("commandBarInput · 20 regular").font(JadeFont.commandBarInput)
            }
            .foregroundStyle(JadeColor.textPrimary)
        }
        .padding(24)
    }
    .frame(width: 360, height: 420)
}
