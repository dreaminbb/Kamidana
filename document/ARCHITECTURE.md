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
