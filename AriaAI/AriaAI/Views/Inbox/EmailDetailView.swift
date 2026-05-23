import SwiftUI

struct EmailDetailView: View {
    let email: EmailMessage
    @ObservedObject var vm: InboxViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SheetGlassBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Subject
                        Text(email.subject)
                            .font(Theme.Typography.title2(.bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Sender info
                        HStack(spacing: Theme.Spacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#4F8EF7"), Color(hex: "#9B6DFF")],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                Text(email.from.initials)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(email.from.displayName)
                                    .font(Theme.Typography.subheadline(.semibold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text(email.from.email)
                                    .font(Theme.Typography.caption())
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                Text(email.date.emailDateString)
                                    .font(Theme.Typography.caption())
                                    .foregroundStyle(Theme.Colors.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(Theme.Spacing.md)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm, style: .continuous))

                        // Body
                        Text(email.body.isEmpty ? email.snippet : email.body)
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)

                        // Actions
                        VStack(spacing: Theme.Spacing.sm) {
                            GradientButton(
                                title: "Reply",
                                gradient: Theme.Colors.gradientPrimary
                            ) {
                                vm.draftEmail = DraftEmail()
                                vm.draftEmail.to = email.from.email
                                vm.draftEmail.subject = "Re: \(email.subject)"
                                vm.showCompose = true
                                Task { await vm.generateAIDraft(replyTo: email) }
                                dismiss()
                            }

                            Button {
                                vm.draftEmail = DraftEmail()
                                vm.draftEmail.to = email.from.email
                                vm.draftEmail.subject = "Re: \(email.subject)"
                                vm.showCompose = true
                                dismiss()
                            } label: {
                                Text("Reply manually")
                                    .font(Theme.Typography.body(.medium))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: Theme.Size.buttonHeight)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle(email.subject.isEmpty ? "Email" : email.subject)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ComposeEmailView: View {
    @ObservedObject var vm: InboxViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SheetGlassBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        // Fields
                        composeField(label: "To", text: $vm.draftEmail.to, keyboard: .emailAddress)
                        Divider().opacity(0.2)
                        composeField(label: "Cc", text: $vm.draftEmail.cc, keyboard: .emailAddress)
                        Divider().opacity(0.2)
                        composeField(label: "Subject", text: $vm.draftEmail.subject, keyboard: .default)

                        Divider().opacity(0.2)

                        // Body
                        VStack(alignment: .leading) {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $vm.draftEmail.body)
                                    .font(Theme.Typography.body())
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .frame(minHeight: 200)

                                if vm.draftEmail.body.isEmpty {
                                    Text(vm.isGeneratingDraft ? "Generating AI draft…" : "Write your message…")
                                        .font(Theme.Typography.body())
                                        .foregroundStyle(vm.isGeneratingDraft ? Theme.Colors.textSecondary : Theme.Colors.textTertiary)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .allowsHitTesting(false)
                                        .animation(Theme.Animation.quick, value: vm.isGeneratingDraft)
                                }
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm))

                        // AI Draft button
                        Button {
                            Task { await vm.generateAIDraft() }
                        } label: {
                            HStack(spacing: Theme.Spacing.xs) {
                                if vm.isGeneratingDraft {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: vm.draftEmail.body.isEmpty ? "wand.and.stars" : "arrow.clockwise")
                                }
                                Text(vm.isGeneratingDraft ? "Generating…" : vm.draftEmail.body.isEmpty ? "AI Draft" : "Regenerate Draft")
                                    .font(Theme.Typography.subheadline(.medium))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#8B5CF6"), Color(hex: "#6D28D9")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm))
                            .animation(Theme.Animation.snappy, value: vm.draftEmail.body.isEmpty)
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isGeneratingDraft)
                    }
                    .padding(Theme.Spacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(vm.draftEmail.subject.hasPrefix("Re:") ? "Reply" : "New Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await vm.sendEmail() }
                    } label: {
                        if vm.isSending {
                            ProgressView().progressViewStyle(.circular).tint(Theme.Colors.primary)
                        } else {
                            Text("Send")
                                .font(Theme.Typography.subheadline(.semibold))
                                .foregroundStyle(vm.draftEmail.isValid ? Theme.Colors.primary : Theme.Colors.textTertiary)
                        }
                    }
                    .disabled(!vm.draftEmail.isValid || vm.isSending)
                }
            }
            .alert("Send Failed", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button("OK") { vm.error = nil }
            } message: {
                Text(vm.error ?? "")
            }
        }
    }

    private func composeField(label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Theme.Typography.subheadline(.medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 54, alignment: .leading)
            TextField("", text: text)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textPrimary)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm))
    }
}
