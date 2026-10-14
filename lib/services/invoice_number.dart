/// Two different numbers on every order, the same on the website and the Vision Pro app:
///  - Order number:   #0CFX1F    the last 6 characters of the order id, upper case (what people mention in chat)
///  - Invoice number: INV-000123 a running number the server saves on the order (invoiceNumber)
String orderNumber(String? orderId) {
  final id = (orderId ?? '').toUpperCase();
  if (id.isEmpty) return '#';
  return '#${id.length > 6 ? id.substring(id.length - 6) : id}';
}

/// "—" for the few seconds before a brand-new order gets its number
String invoiceNo(String? invoiceNumber) =>
    (invoiceNumber == null || invoiceNumber.isEmpty) ? '—' : invoiceNumber;
