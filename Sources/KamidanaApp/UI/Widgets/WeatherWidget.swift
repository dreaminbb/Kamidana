import AppKit
import SwiftUI

struct WeatherWidget: View {
    @Environment(\.theme) private var theme
    @Environment(\.popupTheme) private var popupTheme
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    @Environment(\.kamidanaWidgetActivation) private var widgetActivation
    @StateObject private var manager = WeatherManager()
    @StateObject private var interaction = WidgetInteractionController()
    @State private var locationSearchQuery: String = ""
    @State private var locationSuggestions: [LocationResult] = []
    @State private var selectedSuggestionIndex: Int?

    let config: WeatherWidgetConfig

    private var activation: KamidanaActivation { widgetActivation ?? .click }

    var body: some View {
        let presentation = WeatherPresentation(
            info: manager.info,
            config: config,
            locationOverride: manager.userSelectedLocation
        )
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
            detailRow("Feels like", field: .feelsLike, presentation: presentation)
            detailRow("Wind speed", field: .windSpeed, presentation: presentation)
            detailRow("Humidity", field: .humidity, presentation: presentation)

            if !presentation.forecast.isEmpty {
                Divider()
                forecastView(
                    presentation.forecast,
                    temperatureUnit: presentation.config.display.temperatureUnit.symbol
                )
            }

            Divider()

            HStack {
                LocationSearchField(
                    text: $locationSearchQuery,
                    onCommit: commitLocation,
                    onMove: moveSuggestionSelection
                )
                .frame(height: 24)
                .onChange(of: locationSearchQuery) { _ in
                    selectedSuggestionIndex = nil
                }
            }

            if !locationSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(locationSuggestions.enumerated()), id: \.offset) {
                        index, suggestion in
                        Button {
                            selectLocation(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.name)
                                if let detail = suggestion.locationDetail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundColor(
                                            popupTheme?.foreground.opacity(0.7) ?? .secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                            .background(
                                index == selectedSuggestionIndex
                                    ? (popupTheme?.hoverTheme?.background
                                        ?? popupTheme?.foreground.opacity(0.12)
                                        ?? .clear)
                                    : .clear
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .background(popupTheme?.background ?? .clear)
                .cornerRadius(6)
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
        .onAppear {
            if locationSearchQuery.isEmpty {
                locationSearchQuery =
                    manager.userSelectedLocation.isEmpty
                    ? config.display.location
                    : manager.userSelectedLocation
            }
        }
        .task(id: locationSearchQuery) {
            await updateLocationSuggestions()
        }
    }

    private func updateLocationSuggestions() async {
        let query = locationSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            locationSuggestions = []
            return
        }

        do {
            try await Task.sleep(nanoseconds: 100_000_000)
            let suggestions = try await LocationService.fetchLocations(
                name: query, lang: config.lang)
            guard !Task.isCancelled,
                locationSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query
            else { return }
            locationSuggestions = suggestions
        } catch is CancellationError {
            return
        } catch {
            locationSuggestions = []
        }
    }

    private func selectLocation(_ suggestion: LocationResult) {
        locationSearchQuery = suggestion.name
        locationSuggestions = []
        selectedSuggestionIndex = nil
        manager.userSelectedLocation = suggestion.name
        Task { await manager.refresh() }
    }

    // This function is called when the user presses Enter or Return in the location search field. It checks if a suggestion is selected and uses that, otherwise it resolves the query to a location.
    private func commitLocation() {
        let query = locationSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if let selectedSuggestionIndex,
            locationSuggestions.indices.contains(selectedSuggestionIndex)
        {
            selectLocation(locationSuggestions[selectedSuggestionIndex])
            return
        }

        locationSuggestions = []
        selectedSuggestionIndex = nil
        Task {
            let resolvedLocation: String
            if query.isEmpty {
                resolvedLocation = ""
            } else {
                do {
                    resolvedLocation = try await LocationService.fetchLocation(
                        name: query, lang: config.lang)
                } catch {
                    resolvedLocation = query
                }

            }
            guard !Task.isCancelled,
                locationSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query
            else { return }
            print("Resolved location: \(resolvedLocation)")
            manager.userSelectedLocation = resolvedLocation
            await manager.refresh()
        }
    }

    private func moveSuggestionSelection(_ direction: MoveCommandDirection) {
        guard !locationSuggestions.isEmpty else { return }
        switch direction {
        case .down:
            selectedSuggestionIndex = min(
                (selectedSuggestionIndex ?? -1) + 1, locationSuggestions.count - 1)
        case .up:
            selectedSuggestionIndex = max(
                (selectedSuggestionIndex ?? locationSuggestions.count) - 1, 0)
        default:
            return
        }
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

    private func forecastView(
        _ forecast: [WeatherPresentation.ForecastDay], temperatureUnit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("3-day forecast")
                .font(.headline)
            ForEach(Array(forecast.enumerated()), id: \.offset) { _, day in
                HStack(spacing: 8) {
                    FormattedWidgetLabel(
                        format: day.icon,
                        values: [:],
                        iconColor: popupTheme?.iconForeground ?? .primary,
                        textColor: popupTheme?.foreground ?? .primary,
                        iconSize: 18
                    )
                    Text(day.date)
                        .font(.caption)
                        .frame(width: 86, alignment: .leading)
                    Spacer(minLength: 0)
                    Text(
                        "\(day.maximumTemperature)\(temperatureUnit) / \(day.minimumTemperature)\(temperatureUnit)"
                    )
                        .monospacedDigit()
                    Text("Rain \(day.precipitationChance)%")
                        .font(.caption)
                        .foregroundColor(popupTheme?.foreground.opacity(0.7) ?? .secondary)
                }
                .accessibilityLabel(
                    "\(day.date), \(day.description), high \(day.maximumTemperature)\(temperatureUnit), low \(day.minimumTemperature)\(temperatureUnit), rain \(day.precipitationChance) percent"
                )
            }
        }
    }

    private func partColor(_ field: WeatherValue, presentation: WeatherPresentation, theme: Theme?)
        -> Color
    {
        if let hex = presentation.colorHex(field) { return Color(hex: hex) }
        return field == .weather ? theme?.iconForeground ?? .primary : theme?.foreground ?? .primary
    }
}

private struct LocationSearchField: NSViewRepresentable {
    @Binding var text: String
    let onCommit: () -> Void
    let onMove: (MoveCommandDirection) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> LocationSearchTextField {
        let textField = LocationSearchTextField()
        textField.delegate = context.coordinator
        textField.onCommit = onCommit
        textField.onMove = onMove
        textField.placeholderString = "Search location..."
        textField.stringValue = text
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.isBordered = true
        textField.drawsBackground = true
        textField.focusRingType = .default
        return textField
    }

    func updateNSView(_ nsView: LocationSearchTextField, context: Context) {
        context.coordinator.parent = self
        nsView.onCommit = onCommit
        nsView.onMove = onMove
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LocationSearchField

        init(_ parent: LocationSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
    }
}

private final class LocationSearchTextField: NSTextField {
    var onCommit: (() -> Void)?
    var onMove: ((MoveCommandDirection) -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            onCommit?()
        case 125:
            onMove?(.down)
        case 126:
            onMove?(.up)
        default:
            super.keyDown(with: event)
        }
    }
}
