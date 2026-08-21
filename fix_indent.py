with open("/Users/shin/.config/kamidana/config.yaml", "r") as f:
    lines = f.readlines()

new_lines = []
skip_displays = False

for line in lines:
    if line.startswith("displays:"):
        skip_displays = True
        continue
    
    if skip_displays:
        if line.startswith("  "):
            # un-indent by 2 spaces
            new_lines.append(line[2:])
        else:
            if line.strip() != "":
                skip_displays = False
                new_lines.append(line)
            else:
                new_lines.append(line)
    else:
        new_lines.append(line)

with open("/Users/shin/.config/kamidana/config.yaml", "w") as f:
    f.writelines(new_lines)
