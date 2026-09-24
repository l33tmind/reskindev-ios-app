with open('lib/models/order_model.dart', 'r') as f:
    c = f.read()
c = c.replace("projectDetails: d['projectDetails'] ?? '',", "projectDetails: d['requirementsText'] ?? d['projectDetails'] ?? '',")
with open('lib/models/order_model.dart', 'w') as f:
    f.write(c)
