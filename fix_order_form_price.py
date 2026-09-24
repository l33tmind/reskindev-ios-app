import re

with open('lib/screens/order_form_screen.dart', 'r') as f:
    content = f.read()

# Update _submit to include serviceFee
old_submit_order = """    final order = OrderModel(
      gigId: gig.id,
      gigTitle: gig.title,
      packageId: package.id.isNotEmpty ? package.id : package.name.toLowerCase(),
      packageName: package.name,
      price: package.price,
      basePrice: package.price,
      discountAmount: 0,
      deliveryDays: package.deliveryDays,
      userId: auth.user!.uid,"""
new_submit_order = """    final settings = context.read<SettingsProvider>();
    final double serviceFeePct = settings.serviceFee;
    final double discountedPrice = package.price - 0; // 0 is discountAmount
    final double serviceFeeAmount = discountedPrice * (serviceFeePct / 100);
    final double finalPrice = discountedPrice + serviceFeeAmount;

    final order = OrderModel(
      gigId: gig.id,
      gigTitle: gig.title,
      packageId: package.id.isNotEmpty ? package.id : package.name.toLowerCase(),
      packageName: package.name,
      price: finalPrice, // Used as total price
      basePrice: package.price,
      discountAmount: 0,
      deliveryDays: package.deliveryDays,
      userId: auth.user!.uid,"""
content = content.replace(old_submit_order, new_submit_order)

# Also add serviceFee to map directly (since OrderModel might not have it yet, or we could just put it in map)
old_order_map = """    final orderMap = order.toMap();
    // Add optional profile fields (only if non-null)
    if (phone != null) orderMap['clientPhone'] = phone;"""
new_order_map = """    final orderMap = order.toMap();
    // Include serviceFee in the map for backend consistency
    orderMap['serviceFee'] = serviceFeeAmount;
    
    // Add optional profile fields (only if non-null)
    if (phone != null) orderMap['clientPhone'] = phone;"""
content = content.replace(old_order_map, new_order_map)

# Update buildFormContent calculation
old_build_form = """  Widget _buildFormContent(BuildContext context, GigModel gig, GigPackage package) {
    final total = package.price;
    return Form("""
new_build_form = """  Widget _buildFormContent(BuildContext context, GigModel gig, GigPackage package) {
    final settings = context.read<SettingsProvider>();
    final double serviceFeePct = settings.serviceFee;
    final double discountedPrice = package.price - 0; // 0 is discount
    final double serviceFeeAmount = discountedPrice * (serviceFeePct / 100);
    final double finalPrice = discountedPrice + serviceFeeAmount;
    
    final total = finalPrice;
    return Form("""
content = content.replace(old_build_form, new_build_form)

# Update Order Summary UI
old_summary_ui = """                          const SizedBox(height: 14),
                          Divider(color: context.themeBorder, height: 1),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount',"""
new_summary_ui = """                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Service Fee (${serviceFeePct.toStringAsFixed(0)}%)',
                                  style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
                              Text('\$${serviceFeeAmount.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(color: context.themeBorder, height: 1),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount',"""
content = content.replace(old_summary_ui, new_summary_ui)

with open('lib/screens/order_form_screen.dart', 'w') as f:
    f.write(content)

print("Updated order form price logic")
