import SwiftUI

struct FallingBlock: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let speed: CGFloat
}

class GameState: ObservableObject {
    @Published var blocks: [FallingBlock] = []
    @Published var playerX: CGFloat = 0
    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var isGameOver: Bool = false

    let playerWidth: CGFloat = 110
    let playerHeight: CGFloat = 18

    private var gameTimer: Timer?
    private var spawnTimer: Timer?
    private var screenW: CGFloat = 667
    private var screenH: CGFloat = 375
    private var tickCount: Int = 0

    func start(width: CGFloat, height: CGFloat) {
        screenW = width
        screenH = height
        playerX = width / 2
        blocks = []
        score = 0
        lives = 3
        isGameOver = false
        tickCount = 0

        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            self?.spawnBlock()
        }
    }

    func stop() {
        gameTimer?.invalidate()
        spawnTimer?.invalidate()
    }

    private func tick() {
        guard !isGameOver else { return }
        tickCount += 1

        let playerY = screenH - 40
        var toRemove: [UUID] = []

        for i in blocks.indices {
            blocks[i].y += blocks[i].speed

            // caught
            let bx = blocks[i].x
            let by = blocks[i].y
            let bw = blocks[i].width
            let bh = blocks[i].height

            let playerLeft = playerX - playerWidth / 2
            let playerRight = playerX + playerWidth / 2
            let blockLeft = bx - bw / 2
            let blockRight = bx + bw / 2
            let blockBottom = by + bh / 2

            if blockBottom >= playerY - playerHeight / 2 &&
               blockBottom <= playerY + playerHeight / 2 &&
               blockLeft < playerRight && blockRight > playerLeft {
                score += 1
                toRemove.append(blocks[i].id)
            } else if by - bh / 2 > screenH {
                lives -= 1
                toRemove.append(blocks[i].id)
                if lives <= 0 {
                    isGameOver = true
                    stop()
                }
            }
        }
        blocks.removeAll { toRemove.contains($0.id) }
    }

    private func spawnBlock() {
        let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .purple, .pink]
        let w = CGFloat.random(in: 40...90)
        let h = CGFloat.random(in: 24...50)
        let speed = CGFloat.random(in: 2.5...5.0) + CGFloat(score) * 0.04
        let x = CGFloat.random(in: w / 2...(screenW - w / 2))

        blocks.append(FallingBlock(
            x: x, y: -h,
            width: w, height: h,
            color: colors.randomElement()!,
            speed: speed
        ))
    }
}

struct GameView: View {
    let onExit: () -> Void
    @StateObject private var state = GameState()
    @State private var started = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // falling blocks
                ForEach(state.blocks) { block in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(block.color)
                        .frame(width: block.width, height: block.height)
                        .position(x: block.x, y: block.y)
                }

                // player paddle
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(width: state.playerWidth, height: state.playerHeight)
                    .position(x: state.playerX, y: geo.size.height - 40)

                // HUD
                VStack {
                    HStack {
                        Text("Score: \(state.score)")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(0..<3) { i in
                                Image(systemName: i < state.lives ? "heart.fill" : "heart")
                                    .foregroundColor(.red)
                            }
                        }
                        Spacer()
                        Button("Exit") {
                            state.stop()
                            onExit()
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .font(.subheadline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    Spacer()
                }

                // drag zone (invisible, full width)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x
                                let half = state.playerWidth / 2
                                state.playerX = max(half, min(geo.size.width - half, x))
                            }
                    )

                // game over overlay
                if state.isGameOver {
                    gameOverOverlay(geo: geo)
                }
            }
            .onAppear {
                if !started {
                    started = true
                    state.start(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func gameOverOverlay(geo: GeometryProxy) -> some View {
        ZStack {
            Color.black.opacity(0.75)
            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Score: \(state.score)")
                    .font(.title2.bold())
                    .foregroundColor(.cyan)
                HStack(spacing: 20) {
                    Button("Play Again") {
                        state.start(width: geo.size.width, height: geo.size.height)
                    }
                    .buttonStyle(GameButtonStyle(color: .cyan))

                    Button("Exit") {
                        state.stop()
                        onExit()
                    }
                    .buttonStyle(GameButtonStyle(color: .white.opacity(0.3)))
                }
            }
        }
    }
}

struct GameButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundColor(.black)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(color)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
