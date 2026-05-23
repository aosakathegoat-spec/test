import SwiftUI
import PhotosUI
import UIKit

struct ChatView: View {
    @StateObject private var vm = ChatViewModel()
    @ObservedObject private var voiceService = VoiceService.shared
    @EnvironmentObject private var appState: AppState
    @FocusState private var inputFocused: Bool
    @State private var showSessions = false
    @State private var showImagePicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showUpgradeForImages = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                navBar
                messageList
                inputBar
            }
        }
        .sheet(isPresented: $showSessions) { sessionSheet }
        .sheet(item: $vm.pendingSMSConfirmation) { sms in
            SMSConfirmationSheet(sms: sms, vm: vm)
                .onDisappear { vm.cancelSMSSend() }
        }
        .onChange(of: vm.isVoiceActive) { _, active in
            if active { inputFocused = false }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.clearError() } }
        )) {
            Button("OK") { vm.clearError() }
        } message: {
            Text(vm.error ?? "")
        }
        .onAppear {
            inputFocused = false
            checkPendingSiriRequest()
        }
        .onReceive(NotificationCenter.default.publisher(for: .siriRequestReceived)) { notification in
            guard let request = notification.object as? String else { return }
            UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.pendingSiriRequest)
            Task {
                vm.inputText = request
                await vm.sendMessage()
            }
        }
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
            .accessibilityLabel("Show conversation history")

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
                    SoundWaveView(isActive: voiceService.isListening || voiceService.isSpeaking)
                        .frame(width: 40)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }

                Button {
                    vm.toggleVoiceMode()
                } label: {
                    Image(systemName: vm.isVoiceActive ? "waveform.circle.fill" : "waveform.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(vm.isVoiceActive ? Theme.Colors.primary : Theme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(Theme.Animation.snappy, value: vm.isVoiceActive)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(vm.isVoiceActive ? "Switch to text mode" : "Switch to voice mode")

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
                .accessibilityLabel("New conversation")
            }
            .animation(Theme.Animation.snappy, value: vm.isVoiceActive)
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
            .onChange(of: vm.scrollToBottom) { _, newValue in
                guard newValue else { return }
                withAnimation(Theme.Animation.smooth) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                vm.scrollToBottom = false
            }
            .onChange(of: vm.messages.count) { oldCount, newCount in
                guard newCount > oldCount else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            } else {
                textInputBar
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity
                    ))
            }
        }
        .animation(Theme.Animation.spring, value: vm.isVoiceActive)
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
            .accessibilityLabel(appState.plan.canAnalyzeImages ? "Attach image" : "Attach image — upgrade required")

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
                        guard !vm.isStreaming else { return }
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

            // Send / stop / voice button
            Group {
                if vm.isStreaming {
                    Button { vm.cancelStreaming() } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#EF4444"))
                                .frame(width: 38, height: 38)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white)
                                .frame(width: 13, height: 13)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop response")
                    .transition(.scale.combined(with: .opacity))
                } else if vm.inputText.isEmpty && vm.selectedImages.isEmpty {
                    VoiceButton(
                        isListening: voiceService.isListening,
                        isSpeaking: voiceService.isSpeaking
                    ) {
                        if appState.plan.canUseVoice {
                            Task {
                                if voiceService.isListening {
                                    await vm.stopVoiceAndSend()
                                } else {
                                    await vm.startVoiceInput()
                                }
                            }
                        } else {
                            appState.triggerUpgradePrompt()
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        Task { await vm.sendMessage() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#4F8EF7"), Color(hex: "#7C3AED")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ).erased
                                )
                                .frame(width: 38, height: 38)
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Send message")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.isStreaming)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.inputText.isEmpty && vm.selectedImages.isEmpty)
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
                SoundWaveView(isActive: voiceService.isListening || voiceService.isSpeaking)
                    .frame(width: 100)
                Spacer()
            }

            // Recognized text preview
            if !voiceService.recognizedText.isEmpty {
                Text(voiceService.recognizedText)
                    .font(Theme.Typography.callout())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(2)
                    .padding(.horizontal, Theme.Spacing.md)
            }

            // Controls
            HStack(spacing: Theme.Spacing.xl) {
                // Stop speaking
                Button {
                    voiceService.stop()
                } label: {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(voiceService.isSpeaking ? Theme.Colors.error : Theme.Colors.textTertiary)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!voiceService.isSpeaking)
                .accessibilityLabel("Stop Aria speaking")

                // Main voice button
                VoiceButton(
                    isListening: voiceService.isListening,
                    isSpeaking: voiceService.isSpeaking
                ) {
                    Task {
                        if voiceService.isListening {
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
                .accessibilityLabel("Switch to text input")
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

                        Button { withAnimation(Theme.Animation.snappy) { vm.removeImage(at: i) } } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                    }
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
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
                                    guard session.id != vm.currentSessionID else {
                                        showSessions = false
                                        return
                                    }
                                    vm.loadSession(session)
                                    showSessions = false
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(session.displayTitle)
                                                .font(Theme.Typography.subheadline(.medium))
                                                .foregroundStyle(Theme.Colors.textPrimary)
                                                .lineLimit(1)
                                            Text(session.date.emailDateString)
                                                .font(Theme.Typography.caption())
                                                .foregroundStyle(Theme.Colors.textSecondary)
                                        }
                                        Spacer()
                                        if session.id == vm.currentSessionID {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(Theme.Colors.primary)
                                        }
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

    private func checkPendingSiriRequest() {
        let key = Constants.UserDefaultsKeys.pendingSiriRequest
        guard let request = UserDefaults.standard.string(forKey: key), !request.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: key)
        Task {
            vm.inputText = request
            await vm.sendMessage()
        }
    }

    private func loadPickedImages(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                withAnimation(Theme.Animation.snappy) { vm.addImage(image) }
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

// MARK: - SMS Confirmation Sheet

struct SMSConfirmationSheet: View {
    let sms: PendingSMS
    @ObservedObject var vm: ChatViewModel

    var recipientLabel: String {
        if let name = sms.contactName, !name.isEmpty {
            return "\(name)  ·  \(sms.phoneNumber)"
        }
        return sms.phoneNumber
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, Theme.Spacing.md)

            // Icon + title
            VStack(spacing: Theme.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.success.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: "message.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Theme.Colors.success)
                }
                Text("Send SMS?")
                    .font(Theme.Typography.title3(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)

            VStack(spacing: Theme.Spacing.sm) {
                // Recipient
                infoRow(icon: "person.fill", label: "To", value: recipientLabel)
                // Message
                VStack(alignment: .leading, spacing: 6) {
                    Label("Message", systemImage: "text.bubble.fill")
                        .font(Theme.Typography.caption(.semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text(sms.message)
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.surface.clipShape(RoundedRectangle(cornerRadius: 14)))
            }
            .padding(.horizontal, Theme.Spacing.md)

            Spacer()

            // Actions
            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task { await vm.confirmSMSSend() }
                } label: {
                    Label("Open SMS Composer", systemImage: "arrow.up.message.fill")
                        .font(Theme.Typography.body(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.success)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    vm.cancelSMSSend()
                } label: {
                    Text("Cancel")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.Typography.caption(.semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
                Text(value)
                    .font(Theme.Typography.subheadline(.medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface.clipShape(RoundedRectangle(cornerRadius: 14)))
    }
}
