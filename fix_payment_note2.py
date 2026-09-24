import re

with open('lib/screens/order_form_screen.dart', 'r') as f:
    c = f.read()

old_note = "'This is a custom professional service delivered outside the app. After placing your order, you will be contacted to finalize project details and secure payment arrangements.'"
new_note = "'This is a real-world professional service delivered outside the app. After placing your order, our team will contact you to discuss project details and finalize payment arrangements offline.'"

c = c.replace(old_note, new_note)

with open('lib/screens/order_form_screen.dart', 'w') as f:
    f.write(c)

