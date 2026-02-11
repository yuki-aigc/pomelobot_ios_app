import SwiftUI

// MARK: - Liquid Glass Card 通用组件

/// 液态玻璃卡片容器
struct GlassCard<Content: View>: View {
    var tint: Color?
    var cornerRadius: CGFloat = 20
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        content()
            .padding(16)
            .glassEffect(
                tint.map { .regular.tint($0) } ?? .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
    }
}

/// 液态玻璃胶囊标签
struct GlassBadge: View {
    let text: String
    let icon: String?
    var tint: Color = .accentColor
    
    init(_ text: String, icon: String? = nil, tint: Color = .accentColor) {
        self.text = text
        self.icon = icon
        self.tint = tint
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11))
            }
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(tint), in: .capsule)
    }
}

/// 液态玻璃浮动操作按钮
struct GlassFloatingButton: View {
    let icon: String
    var tint: Color = .accentColor
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
        }
        .glassEffect(.regular.interactive().tint(tint), in: .circle)
        .shadow(color: tint.opacity(0.3), radius: 8, y: 4)
    }
}

/// 液态玻璃分割线
struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(height: 1)
            .opacity(0.5)
    }
}

// MARK: - Morphing Glass Container

/// 支持 morphing 动画的 Glass 容器
struct MorphingGlassView<Content: View>: View {
    @Namespace private var morphNamespace
    let id: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        content()
            .glassEffect(in: .rect(cornerRadius: 16))
            .glassEffectID(id, in: morphNamespace)
    }
}

// MARK: - Glass Toolbar Item

/// 液态玻璃工具栏图标按钮
struct GlassToolbarButton: View {
    let icon: String
    var tint: Color = .accentColor
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
        }
        .glassEffect(.regular.interactive().tint(tint), in: .circle)
    }
}

// MARK: - Empty State Glass View

/// 空状态液态玻璃视图
struct GlassEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}
