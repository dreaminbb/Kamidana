import re

with open("/Users/shin/.config/kamidana/config.yaml", "r") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.strip() == "monitor: [ \"\" ]":
        continue
    new_lines.append(line)

with open("/Users/shin/.config/kamidana/config.yaml", "w") as f:
    f.writelines(new_lines)
