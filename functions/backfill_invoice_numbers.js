// One-time: numbers the orders that exist today, oldest first, then continues from the last number.
// Run from /functions with a service account:  GOOGLE_APPLICATION_CREDENTIALS=key.json node backfill_invoice_numbers.js
// Dry run by default; pass --write to save.
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
const write = process.argv.includes("--write");

(async () => {
  const counterRef = db.collection("counters").doc("invoices");
  const counter = await counterRef.get();
  let n = (counter.exists && counter.data().last) || 0;
  const snap = await db.collection("orders").get();
  const orders = snap.docs
    .filter((d) => !d.data().invoiceNumber)
    .sort((a, b) => (a.data().createdAt?.toMillis?.() || 0) - (b.data().createdAt?.toMillis?.() || 0));
  console.log(`${orders.length} orders need an invoice number (starting after ${n})`);
  for (const d of orders) {
    n += 1;
    const number = `INV-${String(n).padStart(6, "0")}`;
    console.log(d.id, "->", number);
    if (write) await d.ref.update({ invoiceNumber: number, invoiceNumberSeq: n });
  }
  if (write) await counterRef.set({ last: n });
  console.log(write ? `Done. Counter at ${n}.` : "Dry run only. Use --write to save.");
})();
