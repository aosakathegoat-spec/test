import SwiftUI
import UIKit

struct BlocksView: View {
    @StateObject private var vm = BlocksViewModel()
    @State private var editingAutomation: Automation?
    @State private var showEditor = false
    @State private var runTarget: Automation?
    @State private var showRunLog = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                navBar
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if vm.automations.isEmpty {
                            emptyState.padding(.top, 80)
                        } else {
                            ForEach(vm.automations) { automation in
                                AutomationCard(automation: automation, vm: vm) {
                                    runTarget = automation
                                    vm.run(automation: automation)
                                    showRunLog = true
                                }
                                .onTapGesture {
                                    editingAutomation = automation
                                    showEditor = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, 120)
                }
            }

            // FAB
            Button {
                editingAutomation = Automation()
                showEditor = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Theme.Colors.gradientPrimary)
                    .clipShape(Circle())
                    .shadow(color: Theme.Colors.primary.opacity(0.45), radius: 14, y: 5)
            }
            .padding(.trailing, Theme.Spacing.md)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showEditor) {
            if let a = editingAutomation {
                AutomationEditorView(automation: a, vm: vm)
            }
        }
        .sheet(isPresented: $showRunLog) {
            if let a = runTarget {
                RunLogSheet(automation: a, vm: vm)
            }
        }
    }

    private var navBar: some View {
        HStack {
            Text("Blocks")
                .font(Theme.Typography.title(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("No Automations")
                .font(Theme.Typography.title3())
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Tap + to build your first automation.\nChain AI, email, and more into one flow.")
                .font(Theme.Typography.subheadline())
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
        }
    }
}

// MARK: - AutomationCard

struct AutomationCard: View {
    let automation: Automation
    @ObservedObject var vm: BlocksViewModel
    let onRun: () -> Void

    private var isRunning: Bool { vm.runningID == automation.id && vm.isRunning }
    private var runningBlockIdx: Int { isRunning ? vm.currentBlockIndex : -1 }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(automation.name)
                        .font(Theme.Typography.subheadline(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Text("\(automation.blocks.count) block\(automation.blocks.count == 1 ? "" : "s")")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                Spacer()
                runButton
            }

            if !automation.blocks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(automation.blocks.enumerated()), id: \.element.id) { i, block in
                            BlockChip(block: block, isActive: runningBlockIdx == i)
                            if i < automation.blocks.count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.textTertiary)
                            }
                        }
                    }
                }
            }

            if let last = automation.lastRun {
                Text("Last run \(last.relativeDisplay)")
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous)
                        .stroke(isRunning ? Theme.Colors.primary.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .animation(Theme.Animation.spring, value: isRunning)
        .contextMenu {
            Button(role: .destructive) {
                vm.deleteAutomation(automation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var runButton: some View {
        if isRunning {
            ProgressView()
                .tint(Theme.Colors.primary)
                .scaleEffect(0.85)
                .frame(width: 34, height: 34)
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onRun()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Theme.Colors.success)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - BlockChip

struct BlockChip: View {
    let block: AutomationBlock
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: block.type.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(block.type.displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(isActive ? .white : Color(hex: block.type.colorHex))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color(hex: block.type.colorHex).opacity(isActive ? 0.75 : 0.15))
        )
        .scaleEffect(isActive ? 1.06 : 1.0)
        .animation(Theme.Animation.spring, value: isActive)
    }
}

// MARK: - RunLogSheet

struct RunLogSheet: View {
    let automation: Automation
    @ObservedObject var vm: BlocksViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusBanner
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(vm.runLog) { entry in
                                LogRow(entry: entry, blocks: automation.blocks)
                                    .id(entry.id)
                            }
                            if vm.isRunning && vm.runningID == automation.id {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(Theme.Colors.primary)
                                        .scaleEffect(0.75)
                                    Text("Running…")
                                        .font(Theme.Typography.caption())
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }
                                .id("spinner")
                            }
                        }
                        .padding(Theme.Spacing.md)
                    }
                    .onChange(of: vm.runLog.count) { _, _ in
                        if let last = vm.runLog.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: vm.isRunning) { _, running in
                        if !running {
                            if let last = vm.runLog.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }
            }
            .navigationTitle(automation.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.isRunning && vm.runningID == automation.id {
                        Button("Cancel", role: .destructive) {
                            vm.cancelRun()
                        }
                        .foregroundStyle(Theme.Colors.error)
                    } else {
                        Button("Done") { dismiss() }
                            .foregroundStyle(Theme.Colors.primary)
                    }
                }
            }
            .background(Theme.Colors.background.ignoresSafeArea())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(vm.isRunning && vm.runningID == automation.id)
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let err = vm.runError {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Theme.Colors.error)
                Text(err)
                    .font(Theme.Typography.footnote())
                    .foregroundStyle(Theme.Colors.error)
                    .lineLimit(2)
            }
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.error.opacity(0.1).clipShape(RoundedRectangle(cornerRadius: 10)))
        } else if vm.runComplete && vm.runningID == nil {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Colors.success)
                Text("Automation completed")
                    .font(Theme.Typography.footnote(.medium))
                    .foregroundStyle(Theme.Colors.success)
            }
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.success.opacity(0.1).clipShape(RoundedRectangle(cornerRadius: 10)))
        }
    }
}

struct LogRow: View {
    let entry: BlockRunLog
    let blocks: [AutomationBlock]

    private var block: AutomationBlock? {
        guard entry.blockIndex >= 0 && entry.blockIndex < blocks.count else { return nil }
        return blocks[entry.blockIndex]
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            if let b = block {
                Image(systemName: b.type.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: b.type.colorHex))
                    .frame(width: 20)
            } else {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(width: 20)
                    .padding(.top, 4)
            }
            Text(entry.message)
                .font(Theme.Typography.footnote())
                .foregroundStyle(entry.isError ? Theme.Colors.error : Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

// MARK: - Date helper

private extension Date {
    var relativeDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
