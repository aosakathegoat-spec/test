import SwiftUI

struct VoiceButton: View {
    let isListening: Bool
    let isSpeaking: Bool
    let onTap: () -> Void

    @State private var pulse = false
    @State private var wavePhase: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Pulse rings when listening
                if isListening {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color(hex: "#F87171").opacity(0.3 - Double(i) * 0.08), lineWidth: 2)
                            .scaleEffect(pulse ? 1.0 + CGFloat(i) * 0.4 : 1.0)
                            .opacity(pulse ? 0 : 0.8)
                            .animation(
                                .easeOut(duration: 1.2).repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.3),
                                value: pulse
                            )
                    }
                }

                // Glow when speaking
                if isSpeaking {
                    Circle()
                        .fill(Color(hex: "#3B82F6").opacity(0.25))
                        .frame(width: 60, height: 60)
                        .scaleEffect(pulse ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                }

                // Main button
                Circle()
                    .fill(buttonGradient)
                    .frame(width: 48, height: 48)
                    .shadow(color: buttonShadowColor, radius: 12, x: 0, y: 4)

                Image(systemName: buttonIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(isListening || isSpeaking ? 1.1 : 1.0)
                    .animation(Theme.Animation.spring, value: isListening || isSpeaking)
            }
        }
        .buttonStyle(.plain)
        .onAppear { pulse = true }
    }

    private var buttonIcon: String {
        if isListening { return "waveform" }
        if isSpeaking  { return "speaker.wave.2.fill" }
        return "mic.fill"
    }

    private var buttonGradient: LinearGradient {
        if isListening {
            return LinearGradient(
                colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        if isSpeaking {
            return LinearGradient(
                colors: [Color(hex: "#3B82F6"), Color(hex: "#1D4ED8")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color(hex: "#6366F1"), Color(hex: "#4F46E5")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var buttonShadowColor: Color {
        if isListening { return Color(hex: "#EF4444").opacity(0.4) }
        if isSpeaking  { return Color(hex: "#3B82F6").opacity(0.4) }
        return Color(hex: "#6366F1").opacity(0.4)
    }
}

// Waveform animation for voice mode
struct SoundWaveView: View {
    let isActive: Bool
    let barCount = 7

    @State private var amplitudes: [CGFloat] = Array(repeating: 0.3, count: 7)
    private let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#60A5FA"), Color(hex: "#A78BFA")],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
                    .frame(width: 4, height: isActive ? amplitudes[i] * 32 + 6 : 6)
                    .animation(
                        .spring(response: 0.25, dampingFraction: 0.65),
                        value: amplitudes[i]
                    )
            }
        }
        .frame(height: 40)
        .onReceive(timer) { _ in
            guard isActive else { return }
            withAnimation {
                for i in 0..<barCount {
                    amplitudes[i] = CGFloat.random(in: 0.2...1.0)
                }
            }
        }
    }
}
