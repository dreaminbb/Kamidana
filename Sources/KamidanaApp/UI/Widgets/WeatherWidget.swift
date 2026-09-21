import SwiftUI

struct WeatherWidget: View {
    @Environment(\.theme) private var theme
    @Environment(\.popupTheme) private var popupTheme
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    @Environment(\.kamidanaWidgetActivation) private var widgetActivation
    @StateObject private var manager = WeatherManager()
    @StateObject private var interaction = WidgetInteractionController()
    @State private var locationSearchQuery: String = ""
    @State private var isEditingLocation: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    let config: WeatherWidgetConfig

    private var activation: KamidanaActivation { widgetActivation ?? .click }

    var body: some View {
        let presentation = WeatherPresentation(info: manager.info, config: config)
        WidgetActionButton(action: { interaction.activate(activation) }) {
            HStack(spacing: 0) {
                ForEach(
                    Array(
                        presentation.parts(
                            format: widgetFormat ?? config.format ?? "{weather} {temperature}"
                        ).enumerated()), id: \.offset
                ) { _, part in
                    FormattedWidgetLabel(
                        format: part.text,
                        values: [:],
                        iconColor: partColor(
                            part.field ?? .weather, presentation: presentation, theme: theme),
                        textColor: part.field.map {
                            partColor($0, presentation: presentation, theme: theme)
                        } ?? theme?.foreground ?? .primary
                    )
                }
            }
            .monospacedDigit()
            .accessibilityLabel(
                "Weather: \(presentation.value(.description)), \(presentation.value(.temperature))")
        }
        .environment(\.kamidanaWidgetActivation, activation)
        .widgetInteraction(controller: interaction, activation: activation) { _ in
            details(presentation)
        }
        .task(id: config) {
            await manager.monitor(config: config)
        }
    }

    private func details(_ presentation: WeatherPresentation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 12) {
                    FormattedWidgetLabel(
                        format: presentation.value(.weather),
                        values: [:],
                        iconColor: partColor(
                            .weather, presentation: presentation, theme: popupTheme),
                        textColor: partColor(
                            .weather, presentation: presentation, theme: popupTheme),
                        iconSize: 52
                    )
                    .accessibilityLabel(presentation.value(.description))
                    Text(presentation.value(.city))
                        .font(.headline)
                        .foregroundColor(
                            partColor(.city, presentation: presentation, theme: popupTheme)
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(width: 110)
                VStack(alignment: .leading, spacing: 8) {
                    Text(presentation.value(.temperature))
                        .font(.system(size: 30, weight: .semibold, design: .monospaced))
                        .foregroundColor(
                            partColor(.temperature, presentation: presentation, theme: popupTheme)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("Feels like")
                        .font(.caption)
                    Text(presentation.value(.feelsLike))
                        .foregroundColor(
                            partColor(.feelsLike, presentation: presentation, theme: popupTheme)
                        )
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }

            Divider()
            detailRow("Humidity", field: .humidity, presentation: presentation)
            detailRow("Wind speed", field: .windSpeed, presentation: presentation)
            detailRow("Pressure", field: .pressure, presentation: presentation)
            VStack(alignment: .leading, spacing: 6) {
                Text("Conditions").font(.caption)
                Text(presentation.value(.description))
                    .foregroundColor(
                        partColor(.description, presentation: presentation, theme: popupTheme)
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                if isEditingLocation {
                    TextField(
                        "Search location...", text: $locationSearchQuery,
                        onCommit: {
                            let query = locationSearchQuery
                            isEditingLocation = false
                            Task {
                                if !query.isEmpty {
                                    do {
                                        let resolvedName = try await LocationService.fetchLocation(
                                            name: query, lang: config.lang)
                                        manager.userSelectedLocation = resolvedName
                                    } catch {
                                        manager.userSelectedLocation = query
                                    }
                                } else {
                                    manager.userSelectedLocation = ""
                                }
                                await manager.refresh()
                            }
                        }
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .frame(height: 24)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextFieldFocused = true
                        }
                    }

                    Button(action: {
                        isEditingLocation = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Button(action: {
                        locationSearchQuery = manager.userSelectedLocation
                        isEditingLocation = true
                        NSApp.activate(ignoringOtherApps: true)
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text(manager.userSelectedLocation.isEmpty ? "Search location" : "Change location")
                        }
                        .font(.caption)
                        .foregroundColor(popupTheme?.severityColors.normal ?? .secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if manager.isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Updating weather…").font(.caption)
                }
            } else if manager.error != nil {
                Text(
                    manager.info == nil
                        ? "Weather unavailable. Retrying automatically."
                        : "Update failed. Showing the last received weather."
                )
                .font(.caption)
                .foregroundColor(popupTheme?.severityColors.warning ?? .secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundColor(popupTheme?.foreground ?? .primary)
        .padding(16)
        .frame(width: 350, alignment: .leading)
    }

    private func detailRow(_ title: String, field: WeatherValue, presentation: WeatherPresentation)
        -> some View
    {
        HStack {
            Text(title)
            Spacer()
            Text(presentation.value(field))
                .foregroundColor(partColor(field, presentation: presentation, theme: popupTheme))
                .monospacedDigit()
        }
    }

    private func partColor(_ field: WeatherValue, presentation: WeatherPresentation, theme: Theme?)
        -> Color
    {
        if let hex = presentation.colorHex(field) { return Color(hex: hex) }
        return field == .weather ? theme?.iconForeground ?? .primary : theme?.foreground ?? .primary
    }
}
