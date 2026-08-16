YASB UI Design Notes (language-agnostic, for a Swift/macOS port)

1. The bar is a declarative composition, not a hardcoded layout

The status bar isn't a fixed arrangement of views baked into code. It's built at runtime from a config file that lists, per region (left / center / right), which named widget instances go where. The same widget type (e.g. "clock") can be instantiated multiple times under different names with different options, and different bar instances can show different widget sets on different screens.

For Swift: don't model the bar as a NSStackView with fixed subviews. Model it as [Region: [WidgetInstance]], where WidgetInstance carries a type identifier + a validated options struct, and the actual NSView/SwiftUI View is built by looking up that type identifier in a registry at construction time.

2. Widgets are self-describing components with validated options

Every widget type declares its own options schema. Before a widget is constructed, its raw config dictionary is validated against that schema; invalid options block construction of that widget only, with the rest of the bar unaffected. Widget types self-register into a lookup table at definition time — the composition layer never has a hardcoded list of "all possible widgets."

For Swift: a WidgetType protocol with an associated Options: Decodable & Validatable type, registered into a [String: WidgetType.Type] table (via a static registration call, a plugin manifest, or NSExtension-style discovery). Decode+validate happens once per widget instance at build time, and a validation failure produces a per-widget error rather than aborting the whole bar.

3. Label content is decomposed into segments, not rendered as rich text

A widget's display string can mix plain text and icon glyphs (<span class="icon">...</span> in the source config). Rather than rendering this as one rich-text label, it's split into segments, and each segment becomes its own label view — one class for the icon glyph, one class for the text. This exists because the underlying label widget's rich-text support was too limited to style icon vs. text independently through CSS classes.

This constraint doesn't really apply to Swift — NSAttributedString / SwiftUI's Text concatenation handle mixed icon+text natively and can carry per-run styling. Worth keeping the underlying idea rather than the implementation: separate the semantic pieces (icon glyph vs. label text) so each can be styled and toggled independently (e.g., an icon-only mode), even if it's one attributed string instead of two views.

4. Styling is a stylesheet, not per-view code

Visual appearance lives entirely in an external stylesheet (CSS-like syntax, with @import support for splitting themes across files), not in the widget code. Widget code only sets class names/properties; the stylesheet decides colors, spacing, fonts. On top of that, a custom animation layer parses transition-like declarations out of the stylesheet and drives them separately, because the native styling engine didn't support animated property changes.

For Swift, there's no native CSS, so this is the part that needs the most original thought:

A theme file (could be a custom DSL, or reuse something like a subset of CSS parsed into a [Selector: [Property: Value]] map) applied to views via a class/property-name mapping, so non-programmers can restyle the bar without touching Swift code.
Transitions/animations as a separate, declarative layer read from the same theme file and applied via NSAnimationContext / SwiftUI withAnimation, keyed off the same class names used for static styling.
5. The UI reloads live, without relaunching

Editing the config or stylesheet is reflected without restarting the app. This has two different granularities:

Style-only changes re-apply the stylesheet in place — same widget instances, new appearance.
Structural config changes (widgets added/removed/reordered, options changed) tear down and rebuild the affected bar(s) from scratch, rather than diffing and patching the view tree.

The full-rebuild choice for structural changes is deliberate: incremental patching of a live view hierarchy — figuring out which widget moved vs. was replaced vs. changed options — is a lot of state-tracking complexity for a status bar that rebuilds in well under a second. Full teardown/rebuild is simpler to reason about and cheap enough that the simplicity wins.

For Swift: watch the config/theme files (DispatchSource file monitoring or FSEvents), hash their contents to avoid reacting to spurious writes, and on a real change either re-apply styles to existing views or discard and rebuild the window's view tree. Don't build incremental diffing unless the rebuild genuinely proves too slow or visually jarring (a fade transition on rebuild can hide the flash).

6. Multi-monitor placement is a first-class config concern

A bar definition specifies which screens it appears on: an explicit list of screen names, "primary," a wildcard meaning "any screen not already claimed by another bar," or a second wildcard meaning "every screen, even if already claimed." Screens connecting/disconnecting triggers a full re-evaluation of this placement logic and rebuilds all bars.

For Swift: enumerate NSScreen.screens, resolve the same three placement modes against a set of "already assigned" screens computed from all bar definitions first, then instantiate one bar window per resolved screen. Subscribe to NSApplication.didChangeScreenParametersNotification to trigger placement re-evaluation on connect/disconnect.

7. Click handling is button-specific and decoupled from the widget's own logic

Each widget exposes separate action slots for left/middle/right click, and those slots reference named actions (e.g., "open explorer," "run this shell command") rather than being tied to a specific widget's internal methods. This keeps interaction behavior configurable per-instance from the config file, independent of what the widget type itself implements.

For Swift: a small action registry ([String: (Widget, [String]) -> Void]) that both built-in and widget-specific actions can register into, with each widget instance holding three action references (one per mouse button) resolved from its config at construction time, using NSClickGestureRecognizer/NSPressGestureRecognizer per button.

8. Global hotkeys are a cross-cutting layer above the widget tree

Keybindings are declared per-widget in config but dispatched through one global hotkey listener that routes by widget name (and, in multi-monitor setups, by screen), not through per-widget event handlers. A widget nested inside a container widget still needs its keybinding collected and routed correctly — the collection step has to walk into containers explicitly.

For Swift: a single HotkeyManager (built on the Carbon RegisterEventHotKey API or a wrapper like HotKey) that owns all global shortcut registrations, dispatching to widgets via a name+screen key rather than each widget managing its own hotkey. Keeps hotkey conflict detection and duplicate-registration handling (same widget shown on two screens) in one place instead of scattered across widget instances.
