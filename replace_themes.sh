#!/bin/bash
FILES=(
  "/Users/shin/Developer/Kamidana/Sources/Kamidana/KamidanaApp.swift"
)

while IFS= read -r file; do
  FILES+=("$file")
done < <(find /Users/shin/Developer/Kamidana/Sources/Kamidana/UI -type f -name '[A-La-l]*.swift')

for file in "${FILES[@]}"; do
  sed -E -i '' \
    -e 's/theme\.base[[:>:]]/theme.background/g' \
    -e 's/theme\.surface0[[:>:]]/theme.surface/g' \
    -e 's/theme\.surface1[[:>:]]/theme.surfaceHighlight/g' \
    -e 's/theme\.surface2[[:>:]]/theme.surfaceBorder/g' \
    -e 's/theme\.text[[:>:]]/theme.textPrimary/g' \
    -e 's/theme\.subtext1[[:>:]]/theme.textSecondary/g' \
    -e 's/theme\.subtext0[[:>:]]/theme.textTertiary/g' \
    -e 's/theme\.blue[[:>:]]/theme.primary/g' \
    -e 's/theme\.mauve[[:>:]]/theme.secondary/g' \
    -e 's/theme\.pink[[:>:]]/theme.accent/g' \
    -e 's/theme\.green[[:>:]]/theme.success/g' \
    -e 's/theme\.peach[[:>:]]/theme.warning/g' \
    -e 's/theme\.red[[:>:]]/theme.danger/g' \
    -e 's/theme\.teal[[:>:]]/theme.info/g' \
    -e 's/theme\.yellow[[:>:]]/theme.caution/g' \
    "$file"
done
