//
//  WhatsNewView.swift
//  googleCalendarWidget
//

import SwiftUI

/// Pages introducing what changed in an update, one highlight at a time.
struct WhatsNewView: View {
    let pages: [WhatsNewPage]
    let onFinish: () -> Void
    let onOpenPane: (String) -> Void

    @State private var index = 0

    var body: some View {
        ZStack {
            if pages.indices.contains(index) {
                page(pages[index])
                    .id(pages[index].id)
                    .transition(.opacity)
            }
        }
        .frame(width: 400, height: 600)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private func page(_ page: WhatsNewPage) -> some View {
        VStack(spacing: 20) {
            Text("New in \(page.version)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 32)

            Image(systemName: page.highlight.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 56)
                .foregroundColor(.accentColor)

            Text(page.highlight.title)
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(page.highlight.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            if let action = page.highlight.action {
                switch action {
                case .openPane(let pane, let label):
                    Button(label) {
                        onOpenPane(pane)
                        advance()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                }
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            if pages.count > 1 {
                HStack(spacing: 6) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == index ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: i == index ? 16 : 6, height: 6)
                    }
                }
            }

            HStack {
                if pages.count > 1 {
                    Button("Skip") { onFinish() }
                        .buttonStyle(.bordered)
                }
                Spacer()
                Button(index == pages.count - 1 ? "Done" : "Next") {
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 24)
    }

    private func advance() {
        if index == pages.count - 1 {
            onFinish()
        } else {
            withAnimation(.easeInOut(duration: 0.6)) {
                index += 1
            }
        }
    }
}

#Preview("Multi-page") {
    WhatsNewView(pages: WhatsNewCatalog.pages(lastSeenVersion: "", currentVersion: "1.1"),
                 onFinish: {},
                 onOpenPane: { _ in })
}
