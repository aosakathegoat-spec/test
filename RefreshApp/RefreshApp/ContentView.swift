import SwiftUI

struct ContentView: View {
    @State private var refreshID = UUID()
    @State private var refreshCount = 0
    @State private var lastRefreshed = Date()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .id(refreshID)

            VStack(spacing: 8) {
                Text("Refresh Count: \(refreshCount)")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Last refreshed: \(lastRefreshed.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: refresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: refreshID)
    }

    private func refresh() {
        refreshID = UUID()
        refreshCount += 1
        lastRefreshed = Date()
    }
}

#Preview {
    ContentView()
}
