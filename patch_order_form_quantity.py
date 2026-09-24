import re

with open('lib/screens/order_form_screen.dart', 'r') as f:
    c = f.read()

# Add quantity to state
old_state = """  final _detailsCtrl = TextEditingController();
  
  bool _submitting = false;"""

new_state = """  final _detailsCtrl = TextEditingController();
  
  int _quantity = 1;
  bool _submitting = false;"""
c = c.replace(old_state, new_state)

# Update _submit to include quantity and correct total
old_submit = """      packageName: package.name,
      price: finalPrice, // Used as total price
      basePrice: package.price,
      discountAmount: 0,
      deliveryDays: package.deliveryDays,"""

new_submit = """      packageName: package.name,
      price: finalPrice, // Used as total price
      basePrice: package.price,
      discountAmount: 0,
      quantity: _quantity,
      deliveryDays: package.deliveryDays * _quantity,"""
c = c.replace(old_submit, new_submit)

# Update calculate price logic
old_calc = """    final double serviceFeePct = settings.serviceFee;
    final double discountedPrice = package.price - 0; // 0 is discount
    final double serviceFeeAmount = discountedPrice * (serviceFeePct / 100);
    final double finalPrice = discountedPrice + serviceFeeAmount;"""

new_calc = """    final double serviceFeePct = settings.serviceFee;
    final double basePackagePrice = package.price * _quantity;
    final double discountedPrice = basePackagePrice - 0; // 0 is discount
    final double serviceFeeAmount = discountedPrice * (serviceFeePct / 100);
    final double finalPrice = discountedPrice + serviceFeeAmount;"""
c = c.replace(old_calc, new_calc)

# Add Quantity selector widget inside the build method
old_summary_start = """                  child: Column(
                    children: [
                      // Selected Package Head"""

new_summary_start = """                  child: Column(
                    children: [
                      // Quantity Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Quantity', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline, color: _quantity > 1 ? AppTheme.primary : Colors.grey),
                                onPressed: () {
                                  if (_quantity > 1) {
                                    setState(() => _quantity--);
                                  }
                                },
                              ),
                              Text('$_quantity', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                                onPressed: () {
                                  if (_quantity < 10) {
                                    setState(() => _quantity++);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      // Selected Package Head"""
c = c.replace(old_summary_start, new_summary_start)

with open('lib/screens/order_form_screen.dart', 'w') as f:
    f.write(c)

