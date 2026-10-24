//
//  ContentView.swift
//  googleCalendarWidget
//
//  Created by Mark Greene on 25/10/2026.
//

import SwiftUI

private enum SidebarItem: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case calendars = "Calendars"
    case appearance = "Appearance"
    case general = "General"
    case account = "Account"
    case about = "About"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: "calendar"
        case .calendars: "list.bullet"
        case .appearance: "paintpalette"
        case .general: "gearshape"
        case .account: "person.crop.circle"
        case .about: "info.circle"
        }
    }
}

/// The whole app is available from launch. Signing in unlocks real events; everything else works without it.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: SidebarItem? = .overview

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases.filter { $0 != .account }, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                accountRow
            }
        } detail: {
            switch selection ?? .overview {
            case .overview: OverviewPane()
            case .calendars: CalendarsPane()
            case .appearance: AppearancePane()
            case .general: GeneralPane()
            case .account: AccountPane()
            case .about: AboutPane()
            }
        }
        .task { await model.start() }
    }

    /// Account sits at the bottom of the sidebar, with the sign-in state beside it.
    private var accountRow: some View {
        Button {
            selection = .account
        } label: {
            HStack(spacing: 8) {
                Image(systemName: SidebarItem.account.symbol)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Account")
                    HStack(spacing: 5) {
                        Circle()
                            .fill(model.isSignedIn ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(model.isSignedIn ? (model.accountName ?? "Signed in") : "Not signed in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selection == .account ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(10)
    }
}

/// The widget drawn at roughly its large size, using the same view the widget uses.
/// Shows sample events until the user signs in.
struct WidgetPreview: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let month = model.previewMonth
        let isSample = !model.isSignedIn
        MonthCalendarView(month: month,
                          events: isSample ? SampleData.events(in: month, calendar: model.theme.calendar) : model.events,
                          theme: model.theme) {
            HStack(spacing: 10) {
                Button { model.shiftPreview(by: -1) } label: { Image(systemName: "chevron.left") }
                Button { model.shiftPreview(by: 1) } label: { Image(systemName: "chevron.right") }
            }
            .disabled(isSample)
        }
        .padding(16)
        .frame(width: 364, height: 382)
        .background { WidgetBackground(theme: model.theme) }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(model.theme.backgroundStyle == .clear ? 0 : 0.25), radius: 12, y: 6)
        .padding(24)
        // A colorful backdrop, so Glass and Clear have something to show through.
        .background {
            LinearGradient(colors: [Color(red: 0.95, green: 0.55, blue: 0.35),
                                    Color(red: 0.55, green: 0.30, blue: 0.70),
                                    Color(red: 0.20, green: 0.35, blue: 0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 28))
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
