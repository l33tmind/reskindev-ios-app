with open('lib/widgets/workspace_details_sheet.dart', 'r') as f:
    c = f.read()
c = c.replace("order.status == 'processing', 'in_progress'", "order.status == 'processing' || order.status == 'in_progress'")
c = c.replace("['processing', 'in_progress'", "['processing', 'in_progress'")
with open('lib/widgets/workspace_details_sheet.dart', 'w') as f:
    f.write(c)
