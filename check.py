with open('lib/screens/home_screen.dart', 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "_buildMobileLayout" in line:
        print(f"{i}: {line.strip()}")
    if "class _CategoryChipsList" in line:
        print(f"{i}: {line.strip()}")
