//
//  TabBarView.swift
//  YouTubeOnMac
//
//  Horizontal tab bar with selection, close, pin, and drag reorder.
//

import SwiftUI
import AppKit

struct TabBarView: View {
    @ObservedObject var manager: TabManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(manager.tabs) { tab in
                    TabButton(tab: tab, isSelected: manager.selectedTabID == tab.id) {
                        manager.selectTab(id: tab.id)
                    } closeAction: {
                        manager.closeTab(id: tab.id)
                    } pinAction: {
                        manager.pinTab(id: tab.id)
                    }
                    .contentShape(Rectangle())
                    .onDrag {
                        NSItemProvider(object: tab.id.uuidString as NSString)
                    }
                    .onDrop(of: ["public.text"], delegate: TabDropDelegate(manager: manager, tabID: tab.id))
                }

                Button(action: { manager.addTab() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
                .help("New Tab")
                .padding(.horizontal, 6)
            }
            .padding(.horizontal, 8)
            .frame(height: 34)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct TabButton: View {
    let tab: Tab
    let isSelected: Bool
    let selectAction: () -> Void
    let closeAction: () -> Void
    let pinAction: () -> Void

    var body: some View {
        Button(action: selectAction) {
            HStack(spacing: 6) {
                if tab.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                if tab.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }

                Text(tab.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .frame(maxWidth: 160, alignment: .leading)

                Button(action: closeAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
                .opacity(isSelected ? 1.0 : 0.6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected
                ? Color(NSColor.selectedControlColor)
                : Color.clear
            )
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.borderless)
        .foregroundColor(isSelected ? .primary : .secondary)
        .contextMenu {
            Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") {
                pinAction()
            }
            Button("Close Tab") {
                closeAction()
            }
            Button("Close Other Tabs") {
                // TODO: implement close-other-tabs
            }
            .disabled(true)
        }
    }
}

private struct TabDropDelegate: DropDelegate {
    @ObservedObject var manager: TabManager
    let tabID: UUID

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: ["public.text"]).first else { return false }
        item.loadItem(forTypeIdentifier: "public.text", options: nil) { data, _ in
            guard let data = data as? Data,
                  let draggedID = String(data: data, encoding: .utf8),
                  let sourceID = UUID(uuidString: draggedID),
                  let sourceIndex = manager.tabs.firstIndex(where: { $0.id == sourceID }),
                  let destIndex = manager.tabs.firstIndex(where: { $0.id == tabID }) else { return }
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 0.15)) {
                    manager.tabs.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destIndex > sourceIndex ? destIndex + 1 : destIndex)
                }
            }
        }
        return true
    }
}

#Preview {
    TabBarView(manager: TabManager())
}
