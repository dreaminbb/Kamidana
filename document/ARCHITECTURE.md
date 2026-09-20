# Kamidana Widget Engine Architecture

Kamidana's UI is designed to be fully declarative and dynamic, meaning the status bar layout is constructed at runtime from configuration data rather than being hardcoded into the view hierarchy. This document outlines the core components of this architecture (implemented based on `DESIGN.md` Point 1).

## 1. WidgetRegistry & WidgetFactory
To avoid hardcoded lists of all possible widgets (e.g., massive `switch` statements), Kamidana uses a **Dynamic Registry Pattern**.
- **`WidgetFactory` Protocol**: Every widget type provides a factory that defines its `typeID` and a `makeView(config:)` method.
- **`WidgetRegistry`**: A central singleton that stores these factories. When the app launches, all widgets are registered here (e.g., `WidgetRegistry.shared.registerAllWidgets()`). The UI simply asks the registry to build the view for a given `typeID`.

## 2. WidgetInstance (Type Erasure)
Instead of relying on a giant Enum (`AnyWidgetConfig`) to represent heterogeneous widget configurations in arrays, we use `WidgetInstance`.
- `WidgetInstance` is a struct containing a `typeID` (String) and `config` (`AnyHashable`).
- This allows layout configurations (`DisplayLayoutConfig`) to hold arrays of `[WidgetInstance]`.
- For state tracking and SwiftUI diffing, `WidgetInstance` implements value-based `Hashable` and `Equatable` (comparing `typeID` and `config`), while keeping a `UUID` solely for `Identifiable` conformance in loops.

## 3. Dependency Injection via `@EnvironmentObject`
Widgets often require access to shared system states (e.g., `SystemMatrix`, `NetworkManager`, `AudioViewModel`). 
- **Previous approach**: State objects were explicitly passed down through the view hierarchy (`init(matrix: ...)`), causing tight coupling.
- **Current approach**: All shared states are injected at the root level using `.environmentObject(...)`. Widgets declare `@EnvironmentObject var matrix: SystemMatrix` and pull only the data they need. This makes dynamic instantiation via `WidgetRegistry` clean and simple.

## Summary Flow
1. Config is loaded, producing arrays of `WidgetInstance`.
2. `KamidanaApp` iterates over these instances: `ForEach(layout, id: \.id)`.
3. For each instance, it looks up the factory: `WidgetRegistry.shared.factory(for: instance.typeID)`.
4. The factory returns an `AnyView` containing the configured widget.
5. The widget seamlessly accesses global state via the Environment.

## 4. Component Restrictions
To prevent complex UI states and clipping issues within SwiftUI popovers, there are explicit architectural restrictions on widget composition:
- **Vertical `WidgetFolder` (`direction: "below"`) Content Constraint**: 
  A vertically expanding WidgetFolder displays its children inside a popover. It is **strictly prohibited** to nest widgets that themselves expand on click or hover (e.g., another `WidgetFolder` or `NetworkWidget`) inside this popover.
  Only simple, action-oriented widgets that trigger a command on click (such as `SystemActionWidget`) or purely informational widgets without sub-menus are permitted.

## 5. Adding a Widget

New widgets must be configuration-driven and discoverable through the registry. The required changes are:

1. Add the validated `KamidanaWidgetKind` case and its v1 decoding/validation rules.
2. Map the kind to a runtime `WidgetInstance` in `KamidanaConfigurationV1Adapter` and register its `WidgetFactory` in `WidgetRegistry`.
3. Add focused adapter and rendering-model tests, then update `Example/config.yaml` when the example should demonstrate the widget.

Widget views receive a resolved `Theme` through the environment. Use `theme` and `popupTheme` for appearance, and apply `SmoothUIModule(theme:)` or `WidgetButtonStyle` rather than creating a widget-specific surface. The view must not be added to a hardcoded list in the status-bar layout.

## 6. Interaction Foundation

All interactive widgets use the shared action foundation in `WidgetInteraction.swift`.

- `Theme.Motion` owns hover, expand, and severity color-change animations, plus hover-settle and popup-dismiss timing.
- `WidgetInteractionController` owns click/hover presentation, anchor and popup hover state, explicit transitions, and stale callback cancellation.
- `WidgetActionButton` owns the common Button and pressed appearance path.
- `widgetInteraction` owns anchor tracking, popup tracking, external-application dismissal, and popup transitions.
- `WidgetInteractionState` owns the `idle`, `hover`, and `pressed` states in one place.
- The interaction hit region is a fixed transparent layer. Hover appearance may use opacity or scale without moving the hit region or changing layout metrics.
- `Theme.SeverityColors` and `WidgetSeverity` provide shared normal, warning, and critical color transitions.
- Widget-specific code owns only its content and domain action. It must not add independent popup state, hover timers, or hardcoded interaction durations.
