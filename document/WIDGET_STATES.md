# Widget UI State Matrix

This document tracks the application-defined UI states required by the customization boundary in `UI_DESIGN.md`. Each missing state is implemented and accepted separately.

## Acceptance Workflow

1. Select one missing state.
2. Implement only that state and its configuration path.
3. Add automated coverage for state selection where practical.
4. Provide an exact configuration and visual checklist for user testing.
5. Mark the state accepted only after the user confirms the UI on a real device.

## Regular Information Widgets

| Widget | Defined states | Missing states |
|---|---|---|
| CPU | value, details | loading, unavailable, collection error, tooltip disabled |
| GPU | value, details | loading, unsupported hardware, collection error, tooltip disabled |
| Memory | value, details, process-list loading | value loading, unavailable, empty process list, collection error |
| Network | wired and wireless compact indicators, transfer values, cached SSID and network name, address details, detail loading and unavailable, Wi-Fi scanning/loading/empty/failure states, cached scan fallback, Wi-Fi side panel, wired scan disabled | tooltip disabled |
| Disk | used space, I/O details, process-list loading | value loading, unavailable volume, missing I/O data, empty process list |
| Battery | charging, discharging, details | battery unavailable, missing power data, missing thermal data |
| Clock | date and time | invalid format fallback, wake refresh failure |
| Custom | idle, running, command failure | empty output, explicit completion state |

## Center Widgets

| Widget | Defined states | Missing states |
|---|---|---|
| Island | compact, expanded, selected tab | click activation, expansion disabled, empty center |
| Music | regular normal, regular activated, center normal, center activated, playing, paused, no track, no artwork, no track duration | deterministic visual previews |
| btop | executable available | executable unavailable |
| Regular center widget | compact format, expanded factory view | unavailable data and empty compact content |

## Interactive and Expanding Widgets

| Widget | Defined states | Missing states |
|---|---|---|
| Volume | unified input/output popup, codec details, mute, sliders, device lists, input disabled, output disabled, both disabled, empty device list | device error |
| Bluetooth | on, off, connected device list, no connected devices | unavailable hardware, permission denied, refresh error |
| Widget Folder | collapsed, expanded, supported directions, static and dynamic motion | unavailable child factory |
| System Action | action buttons | execution failure feedback |

## Ordered Acceptance Queue

1. Volume input disabled (`input_management: false`, `output_management: true`)
2. Volume output disabled (`input_management: true`, `output_management: false`)
3. Volume fully disabled (`input_management: false`, `output_management: false`)
4. CPU data unavailable
5. GPU data unavailable
6. Music artwork unavailable
7. Center activation set to click

Additional states are selected from the matrix after these states pass user acceptance.
