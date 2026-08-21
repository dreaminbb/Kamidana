import SwiftUI

enum KamidanaFormatRenderer {
  static func render(_ format: String, values: [String: String]) -> String {
    values.reduce(format) { result, value in
      result.replacingOccurrences(of: "{\(value.key)}", with: value.value)
    }
  }

  static func segments(in value: String) -> [KamidanaFormatSegment] {
    var result: [KamidanaFormatSegment] = []
    var current = ""
    var currentIsIcon: Bool?

    func appendCurrent() {
      guard !current.isEmpty, let currentIsIcon else { return }
      result.append(KamidanaFormatSegment(value: current, isIcon: currentIsIcon))
      current = ""
    }

    for character in value {
      let isIcon = character.unicodeScalars.contains { scalar in
        let value = scalar.value
        return (0xE000...0xF8FF).contains(value)
          || (0xF0000...0xFFFFD).contains(value)
          || (0x100000...0x10FFFD).contains(value)
      }
      if currentIsIcon != nil, currentIsIcon != isIcon {
        appendCurrent()
      }
      currentIsIcon = isIcon
      current.append(character)
    }
    appendCurrent()
    return result
  }
}

struct KamidanaFormatSegment: Equatable {
  let value: String
  let isIcon: Bool
}

struct FormattedWidgetLabel: View {
  let format: String
  let values: [String: String]
  let iconColor: Color
  let textColor: Color
  var iconSize: CGFloat = 20

  var body: some View {
    let rendered = KamidanaFormatRenderer.render(format, values: values)
    let segments = KamidanaFormatRenderer.segments(in: rendered)

    HStack(spacing: 0) {
      ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
        if segment.isIcon {
          NerdFontIcon(segment.value, size: iconSize)
            .foregroundColor(iconColor)
        } else {
          Text(segment.value)
            .foregroundColor(textColor)
        }
      }
    }
    .fixedSize(horizontal: true, vertical: false)
  }
}
