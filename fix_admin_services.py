import re

with open('next-frontend/src/app/admin/services/page.js', 'r') as f:
    c = f.read()

# Replace deleteDoc with updateDoc
c = c.replace('await deleteDoc(doc(db, "services", id));', 'await updateDoc(doc(db, "services", id), { status: "deleted", isActive: false, isDeleted: true });')

with open('next-frontend/src/app/admin/services/page.js', 'w') as f:
    f.write(c)

