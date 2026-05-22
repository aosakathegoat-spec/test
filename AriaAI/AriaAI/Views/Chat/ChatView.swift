import SwiftUI
import PhotosUI

struct ChatView: View {
    @StateObject private var vm = ChatViewModel()
    @EnvironmentObject private var appState: AppState
    @FocusState private var inputFocused: Bool
    @State private var showSessions = false
    @State private var showImagePicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showUpgradeForImages = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 0) {
                navBar
                messageList
                inputBar
            }
        }
        .sheet(isPresented: $showSessions) { sessionSheet }
        .sheet(isPresented: $appState.showUpgradePrompt) { PricingView() }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.clearError() } }
        )) {
            Button("OK") { vm.clearError() }
        } message: {
            Text(vm.error ?? "")
        }
        .onAppear { inputFocused = false }
    }

    // MARK: - Nav Bar
    private var navBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button { showSessions = true } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            // Aria logo + name
            HStack(spacing: 6) {
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
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text("Aria")
                    .font(Theme.Typography.title3(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Spacer()

            HStack(spacing: Theme.Spacing.xs) {
                if vm.isVoiceActive {
                    SoundWaveView(isActive: appState.voiceService.isListening || appState.voiceService.isSpeaking)
                        .frame(width: 40)
                }

                Button {
                    vm.toggleVoiceMode()
                } label: {
                    Image(systemName: vm.isVoiceActive ? "waveform.circle.fill" : "waveform.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(vm.isVoiceActive ? Theme.Colors.primary : Theme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button { vm.newConversation() } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.sm)
    }

    // MARK: - Message List
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(vm.messages) { message in
                        MessageBubbleView(message: message)
                            .padding(.horizontal, Theme.Spacing.md)
                            .id(message.id)
                    }

                    // Bottom anchor
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.scrollToBottom) { _, _ in
                withAnimation(Theme.Animation.smooth) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                vm.scrollToBottom = false
            }
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    // MARK: - Input Bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            // Selected images preview
            if !vm.selectedImages.isEmpty {
                imagePreviewBar
            }

            // Voice mode bar
            if vm.isVoiceActive {
                voiceModeBar
            } else {
                textInputBar
            }
        }
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .top) {
            Divider().opacity(0.3)
        }
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $pickerItems,
            maxSelectionCount: 4,
            matching: .images
        )
        .onChange(of: pickerItems) { _, items in
            Task { await loadPickedImages(items) }
        }
    }

    private var textInputBar: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
            // Attach image button
            Button {
                if appState.plan.canAnalyzeImages {
                    showImagePicker = true
                } else {
                    appState.triggerUpgradePrompt()
                }
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(appState.plan.canAnalyzeImages ? Theme.Colors.textSecondary : Theme.Colors.textTertiary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            // Text field
            HStack(alignment: .bottom, spacing: 0) {
                TextField("", text: $vm.inputText, axis: .vertical)
                    .placeholder(when: vm.inputText.isEmpty) {
                        Text("Message Aria…")
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1...8)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await vm.sendMessage() }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )

            // Send / voice button
            if vm.inputText.isEmpty && vm.selectedImages.isEmpty {
                VoiceButton(
                    isListening: appState.voiceService.isListening,
                    isSpeaking: appState.voiceService.isSpeaking
                ) {
                    if appState.plan.canUseVoice {
                        Task {
                            if appState.voiceService.isListening {
                                await vm.stopVoiceAndSend()
                            } else {
                                await vm.startVoiceInput()
                            }
                        }
                    } else {
                        appState.triggerUpgradePrompt()
                    }
                }
            } else {
                Button {
                    Task { await vm.sendMessage() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(vm.isStreaming
                                ? Color(hex: "#EF4444")
                                : LinearGradient(
                                    colors: [Color(hex: "#4F8EF7"), Color(hex: "#7C3AED")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ).erased
                            )
                            .frame(width: 38, height: 38)

                        if vm.isStreaming {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(vm.isStreaming && vm.inputText.isEmpty)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.bottom, 4)
    }

    private var voiceModeBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Waveform
            HStack(spacing: 0) {
                Spacer()
                SoundWaveView(isActive: appState.voiceService.isListening || appState.voiceService.isSpeaking)
                    .frame(width: 100)
                Spacer()
            }

            // Recognized text preview
            if !appState.voiceService.recognizedText.isEmpty {
                Text(appState.voiceService.recognizedText)
                    .font(Theme.Typography.callout())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(2)
                    .padding(.horizontal, Theme.Spacing.md)
            }

            // Controls
            HStack(spacing: Theme.Spacing.xl) {
                // Stop speaking
                Button {
                    appState.voiceService.stop()
                } label: {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(appState.voiceService.isSpeaking ? Theme.Colors.error : Theme.Colors.textTertiary)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!appState.voiceService.isSpeaking)

                // Main voice button
                VoiceButton(
                    isListening: appState.voiceService.isListening,
                    isSpeaking: appState.voiceService.isSpeaking
                ) {
                    Task {
                        if appState.voiceService.isListening {
                            await vm.stopVoiceAndSend()
                        } else {
                            await vm.startVoiceInput()
                        }
                    }
                }
                .scaleEffect(1.3)

                // Exit voice mode
                Button {
                    vm.toggleVoiceMode()
                } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Theme.Spacing.md)
    }

    private var imagePreviewBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(vm.selectedImages.indices, id: \.self) { i in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: vm.selectedImages[i])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button { vm.removeImage(at: i) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    // MARK: - Session Sheet
    private var sessionSheet: some View {
        NavigationStack {
            ZStack {
                SheetGlassBackground()
                Group {
                    if vm.conversations.isEmpty {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.Colors.textTertiary)
                            Text("No saved conversations")
                                .font(Theme.Typography.body())
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    } else {
                        List {
                            ForEach(vm.conversations) { session in
                                Button {
                                    vm.loadSession(session)
                                    showSessions = false
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(session.title)
                                            .font(Theme.Typography.subheadline(.medium))
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                            .lineLimit(1)
                                        Text(session.date.emailDateString)
                                            .font(Theme.Typography.caption())
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        vm.deleteSession(session)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showSessions = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { vm.newConversation(); showSessions = false } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private func loadPickedImages(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                vm.addImage(image)
            }
        }
        pickerItems = []
    }
}

extension LinearGradient {
    var erased: AnyShapeStyle { AnyShapeStyle(self) }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { content() }
            self
        }
    }
}
