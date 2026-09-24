import re

with open('next-frontend/src/app/admin/layout.js', 'r') as f:
    c = f.read()

# Add to imports: AlertTriangle
old_import = """  Cloud,
  List,
  LifeBuoy
} from "lucide-react";"""

new_import = """  Cloud,
  List,
  LifeBuoy,
  AlertTriangle
} from "lucide-react";"""

c = c.replace(old_import, new_import)

# Add to menuItems
old_menu = """    { name: "Withdrawals", icon: DollarSign, path: "/admin/withdrawals" },
    { name: "Reviews Moderation", icon: Star, path: "/admin/reviews" },
    { name: "Settings", icon: Settings, path: "/admin/settings" },"""

new_menu = """    { name: "Withdrawals", icon: DollarSign, path: "/admin/withdrawals" },
    { name: "Reports (UGC)", icon: AlertTriangle, path: "/admin/reports" },
    { name: "Reviews Moderation", icon: Star, path: "/admin/reviews" },
    { name: "Settings", icon: Settings, path: "/admin/settings" },"""

c = c.replace(old_menu, new_menu)

with open('next-frontend/src/app/admin/layout.js', 'w') as f:
    f.write(c)
