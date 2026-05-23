import SwiftUI

// MARK: - Editor

struct AutomationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var automation: Automation
    @ObservedObject var vm: BlocksViewModel
    @State private var showBlockPicker = false
    @State private var showBlockConfig = false
    @State private var editingBlockIndex = 0

    init(automation: Automation, vm: BlocksViewModel) {
        self._automation = State(initialValue: automation)
        self.vm = vm
    }

    var body: some View {
        NavigationStack {
            List {
                // Name field
                Section {
                    TextField("Automation name", text: $automation.name)
                        .font(Theme.Typography.body(.medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .listRowBackground(Theme.Colors.surface)
                }

                // Blocks
                Section {
                    ForEach(Array(automation.blocks.enumerated()), id: \.element.id) { i, block in
                        BlockEditorRow(block: block, isFirst: i == 0, isLast: i == automation.blocks.count - 1)
                            .listRowBackground(Theme.Colors.surface)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingBlockIndex = i
                                showBlockConfig = true
                            }
                    }
                    .onDelete { indexSet in
                        automation.blocks.remove(atOffsets: indexSet)
                    }
                    .onMove { from, to in
                        automation.blocks.move(fromOffsets: from, toOffset: to)
                    }

                    // Add block row
                    Button {
                        showBlockPicker = true
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.Colors.primary)
                            Text("Add Block")
                                .font(Theme.Typography.subheadline(.medium))
                                .foregroundStyle(Theme.Colors.primary)
                        }
                        .padding(.vertical, Theme.Spacing.sm)
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                    .listRowBackground(Theme.Colors.surfaceAlt)
                } header: {
                    Text("BLOCKS")
                        .font(Theme.Typography.caption(.semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background.ignoresSafeArea())
            .environment(\.editMode, .constant(.active))
            .navigationTitle(automation.name.isEmpty ? "New Automation" : automation.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        vm.saveAutomation(automation)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(automation.blocks.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.primary)
                    .disabled(automation.blocks.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showBlockPicker) {
            BlockPickerSheet { type in
                automation.blocks.append(AutomationBlock(type: type))
            }
        }
        .sheet(isPresented: $showBlockConfig) {
            if editingBlockIndex < automation.blocks.count {
                BlockConfigSheet(block: $automation.blocks[editingBlockIndex])
            }
        }
    }
}

// MARK: - Block editor row

struct BlockEditorRow: View {
    let block: AutomationBlock
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Color accent bar
            Color(hex: block.type.colorHex)
                .frame(width: 4)

            HStack(spacing: Theme.Spacing.sm) {
                // Icon
                Image(systemName: block.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: block.type.colorHex))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: block.type.colorHex).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.type.displayName)
                        .font(Theme.Typography.subheadline(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(block.summary)
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
}

// MARK: - Block picker

struct BlockPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (BlockType) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                    ForEach(BlockType.allCases, id: \.self) { type in
                        BlockTypeCard(type: type) {
                            onSelect(type)
                            dismiss()
                        }
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Add Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .background(Theme.Colors.background.ignoresSafeArea())
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct BlockTypeCard: View {
    let type: BlockType
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(hex: type.colorHex))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: type.colorHex).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(type.displayName)
                    .font(Theme.Typography.subheadline(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(type.blockDescription)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous)
                            .stroke(Color(hex: type.colorHex).opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Block config sheet

struct BlockConfigSheet: View {
    @Binding var block: AutomationBlock
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                switch block.type {
                case .ai:
                    aiSection
                case .sendEmail:
                    emailSection
                case .readInbox:
                    inboxSection
                case .wait:
                    waitSection
                }

                Section {
                    variableHints
                } header: {
                    Text("AVAILABLE VARIABLES")
                        .font(Theme.Typography.caption(.semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle(block.type.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var aiSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if block.aiPrompt.isEmpty {
                    Text("e.g. Compose a professional email about…")
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .font(Theme.Typography.body())
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $block.aiPrompt)
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
            }
        } header: {
            Text("PROMPT")
        }
        .listRowBackground(Theme.Colors.surface)
    }

    @ViewBuilder
    private var emailSection: some View {
        Section {
            configRow(label: "To", placeholder: "recipient@example.com", binding: $block.emailTo)
            configRow(label: "Subject", placeholder: "Subject line", binding: $block.emailSubject)
        } header: { Text("RECIPIENTS") }
        .listRowBackground(Theme.Colors.surface)

        Section {
            ZStack(alignment: .topLeading) {
                if block.emailBody.isEmpty {
                    Text("Email body. Use {{ai_output}} to insert AI response.")
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .font(Theme.Typography.body())
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $block.emailBody)
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
            }
        } header: { Text("BODY") }
        .listRowBackground(Theme.Colors.surface)
    }

    @ViewBuilder
    private var inboxSection: some View {
        Section {
            Stepper("Fetch \(block.inboxMaxResults) email\(block.inboxMaxResults == 1 ? "" : "s")",
                    value: $block.inboxMaxResults, in: 1...20)
            .foregroundStyle(Theme.Colors.textPrimary)
        } header: { Text("SETTINGS") }
        .listRowBackground(Theme.Colors.surface)
    }

    @ViewBuilder
    private var waitSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("\(Int(block.waitSeconds)) seconds")
                    .font(Theme.Typography.body(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Slider(value: $block.waitSeconds, in: 1...120, step: 1)
                    .tint(Color(hex: block.type.colorHex))
                HStack {
                    Text("1s")
                    Spacer()
                    Text("120s")
                }
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.vertical, 4)
        } header: { Text("DURATION") }
        .listRowBackground(Theme.Colors.surface)
    }

    private var variableHints: some View {
        VStack(alignment: .leading, spacing: 6) {
            variableHintRow("{{ai_output}}", "Output from the most recent Ask AI block")
            variableHintRow("{{inbox_summary}}", "Emails from the most recent Read Inbox block")
            variableHintRow("{{previous_output}}", "Output from the previous block")
        }
        .listRowBackground(Theme.Colors.surface)
    }

    private func variableHintRow(_ variable: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Text(variable)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.Colors.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.Colors.accent.opacity(0.1).clipShape(RoundedRectangle(cornerRadius: 5)))
            Text(description)
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func configRow(label: String, placeholder: String, binding: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.subheadline())
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 60, alignment: .leading)
            TextField(placeholder, text: binding)
                .font(Theme.Typography.subheadline())
                .foregroundStyle(Theme.Colors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}
