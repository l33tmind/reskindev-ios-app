with open('lib/screens/order_form_screen.dart', 'r') as f:
    content = f.read()

import_statement = "import '../providers/chat_provider.dart';\n"
if "chat_provider.dart" not in content:
    # Insert after last import
    idx = content.rfind("import '")
    end_idx = content.find(";", idx) + 2
    content = content[:end_idx] + import_statement + content[end_idx:]
    with open('lib/screens/order_form_screen.dart', 'w') as f:
        f.write(content)
