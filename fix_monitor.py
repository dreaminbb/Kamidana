import re

with open("/Users/shin/.config/kamidana/config.yaml", "r") as f:
    lines = f.readlines()

new_lines = []
inserted = False

for line in lines:
    if line.startswith("  hide_in_fullscreen:"):
        new_lines.append("  monitor: [ \"\" ]\n")
        new_lines.append(line)
        inserted = True
    else:
        new_lines.append(line)

with open("/Users/shin/.config/kamidana/config.yaml", "w") as f:
    f.writelines(new_lines)
