import SwiftUI

struct ContentView: View {
    @State private var inGame = false

    var body: some View {
        if inGame {
            GameView(onExit: {
                OrientationManager.lockPortrait()
                inGame = false
            })
        } else {
            JoinView(onJoin: {
                OrientationManager.lockLandscape()
                inGame = true
            })
        }
    }
}

struct JoinView: View {
    let onJoin: () -> Void

    var body: some View {
        VStack(spacing: 48) {
            Spacer()

            VStack(spacing: 12) {
                Text("RECT")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("GAME")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(.cyan)
            }

            Text("Catch the falling rectangles.\nDon't let them hit the floor!")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Button(action: onJoin) {
                Text("JOIN GAME")
                    .font(.title2.bold())
                    .frame(width: 220, height: 56)
                    .background(Color.cyan)
                    .foregroundColor(.black)
                    .cornerRadius(14)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    ContentView()
}
