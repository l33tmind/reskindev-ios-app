with open('pubspec.yaml', 'r') as f:
    c = f.read()

c = c.replace("version: 20.22.0+22", "version: 20.23.0+23")

with open('pubspec.yaml', 'w') as f:
    f.write(c)

