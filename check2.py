with open('lib/screens/home_screen.dart', 'r') as f:
    lines = f.readlines()

for i in range(470, 500):
    if i < len(lines):
        print(f"{i+1}: {lines[i].strip()}")
