import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    @State private var showTokens = false

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
            if message.isUser {
                Spacer(minLength: 60)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 60)
            }
        }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Images
            if !message.images.isEmpty {
                imageGrid
            }
            // Text
            if !message.content.isEmpty {
                Text(message.content)
                    .font(Theme.Typography.body())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#4F8EF7"), Color(hex: "#7C3AED")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(BubbleShape(isUser: true))
                    .shadow(color: Color(hex: "#4F8EF7").opacity(0.3), radius: 8, x: 0, y: 4)
            }
            Text(message.timestamp.shortTimeString)
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    private var assistantBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Aria avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#4F8EF7"), Color(hex: "#9B6DFF")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Text("A")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: .leading, spacing: 6) {
                        if message.isStreaming && message.content.isEmpty {
                            typingIndicator
                        } else {
                            Text(message.content)
                                .font(Theme.Typography.body())
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .textSelection(.enabled)
                        }

                        if message.isStreaming && !message.content.isEmpty {
                            streamingCursor
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(BubbleShape(isUser: false))
                    .overlay(
                        BubbleShape(isUser: false)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }

                HStack(spacing: 6) {
                    Text(message.timestamp.shortTimeString)
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textTertiary)

                    if let tokens = message.tokensUsed {
                        Button {
                            withAnimation(Theme.Animation.quick) { showTokens.toggle() }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                Text(tokens.totalTokens.tokenFormatted)
                                    .font(Theme.Typography.caption())
                            }
                            .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)

                        if showTokens {
                            tokenDetail(tokens)
                        }
                    }
                }
            }
        }
    }

    private var imageGrid: some View {
        let cols = min(message.images.count, 2)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: cols),
            spacing: 4
        ) {
            ForEach(message.images) { img in
                if let data = Data(base64Encoded: img.base64Data),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 130, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                TypingDot(delay: Double(i) * 0.2)
            }
        }
        .padding(.vertical, 4)
    }

    private var streamingCursor: some View {
        BlinkingCursor()
    }

    private func tokenDetail(_ tokens: TokenUsageSnapshot) -> some View {
        HStack(spacing: 4) {
            Text("↑\(tokens.inputTokens.tokenFormatted)")
                .foregroundStyle(Color(hex: "#3B82F6"))
            Text("↓\(tokens.outputTokens.tokenFormatted)")
                .foregroundStyle(Color(hex: "#8B5CF6"))
            if tokens.cachedInputTokens > 0 {
                Text("⚡\(tokens.cachedInputTokens.tokenFormatted)")
                    .foregroundStyle(Color(hex: "#10B981"))
            }
        }
        .font(Theme.Typography.caption())
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height),
            cornerSize: CGSize(width: r, height: r),
            style: .continuous
        )
        return path
    }
}

struct TypingDot: View {
    let delay: Double
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(Theme.Colors.textSecondary)
            .frame(width: 7, height: 7)
            .scaleEffect(animate ? 1.2 : 0.7)
            .opacity(animate ? 1.0 : 0.4)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay)
                ) { animate = true }
            }
    }
}

struct BlinkingCursor: View {
    @State private var visible = true
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.primary)
            .frame(width: 2, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
