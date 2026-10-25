//
//  AppearancePane.swift
//  googleCalendarWidget
//

import SwiftUI

struct AppearancePane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        HStack(alignment: .top, spacing: 0) {
            Form {
                Section("Presets") {
                    HStack {
                        Button("Dark") { apply(.standard) }
                        Button("Light") { apply(.light) }
                    }
                }

                Section {
                    ColorPicker("Color", selection: color(\.background))
                    LabeledContent("Opacity") {
                        Slider(value: $model.theme.backgroundOpacity, in: 0...1)
                            .frame(width: 160)
                    }
                } header: {
                    Text("Background")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Want a see-through glass look? Set macOS's own widget style to Clear. The system then draws real Liquid Glass behind this widget and adapts its colors.")
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
                            Link("Open Desktop & Dock settings", destination: url)
                        }
                    }
                }

                Section("Colors") {
                    ColorPicker("Text", selection: color(\.text))
                    ColorPicker("Highlight (today and +)", selection: color(\.accent))
                    ColorPicker("Highlight text", selection: color(\.accentText))
                }

                Section("Events") {
                    Toggle("Use Google calendar colors", isOn: $model.theme.useCalendarColors)
                    if !model.theme.useCalendarColors {
                        ColorPicker("Event color", selection: color(\.customChip))
                    }
                    ColorPicker("Event text", selection: color(\.chipText))
                    LabeledContent("Softness") {
                        Slider(value: $model.theme.chipSoftness, in: 0...0.9)
                            .frame(width: 160)
                    }
                }

                Section("Grid") {
                    Toggle("Show grid lines", isOn: $model.theme.showGrid)
                    if model.theme.showGrid {
                        ColorPicker("Line color", selection: color(\.grid), supportsOpacity: true)
                    }
                    LabeledContent("Other-month days") {
                        Slider(value: $model.theme.dimmedTextOpacity, in: 0.1...1)
                            .frame(width: 160)
                    }
                    Toggle("Show + button", isOn: $model.theme.showPlusButton)
                    Picker("Week starts on", selection: $model.theme.weekStart) {
                        Text("System default").tag(0)
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                        Text("Saturday").tag(7)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 360)

            WidgetPreview()
                .padding(.vertical, 12)
                .padding(.trailing, 8)
        }
        .navigationTitle("Appearance")
        .onChange(of: model.theme) { model.themeDidChange() }
    }

    private func color(_ keyPath: WritableKeyPath<WidgetTheme, RGBAColor>) -> Binding<Color> {
        Binding(get: { model.theme[keyPath: keyPath].color },
                set: { model.theme[keyPath: keyPath] = RGBAColor($0) })
    }

    /// Applies a preset but keeps the user's week-start and + button choices.
    private func apply(_ preset: WidgetTheme) {
        model.theme = model.theme.applying(preset)
    }
}

#Preview("Light") {
    let model = AppModel()
    model.theme = .light
    return AppearancePane()
        .environment(model)
        .frame(width: 820, height: 700)
}
