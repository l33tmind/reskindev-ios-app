import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/coupon_model.dart';

class AdminCouponsView extends StatefulWidget {
  const AdminCouponsView({super.key});

  @override
  State<AdminCouponsView> createState() => _AdminCouponsViewState();
}

class _AdminCouponsViewState extends State<AdminCouponsView> {
  final _codeCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  DateTime? _selectedDate;

  Future<void> _addCoupon() async {
    if (_codeCtrl.text.isEmpty || _discountCtrl.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('coupons').add({
      'code': _codeCtrl.text.trim().toUpperCase(),
      'discount': double.tryParse(_discountCtrl.text) ?? 0,
      'usageLimit': int.tryParse(_limitCtrl.text),
      'usageCount': 0,
      'expiryDate': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
      'targetedUsers': _userCtrl.text.isEmpty ? [] : _userCtrl.text.split(',').map((e) => e.trim()).toList(),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _codeCtrl.clear();
    _discountCtrl.clear();
    _limitCtrl.clear();
    _userCtrl.clear();
    setState(() => _selectedDate = null);
    if (mounted) Navigator.pop(context);
  }

  void _showAddDialog() {
    showAdaptiveDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          InputDecoration inputDecoration(String label, {String? hintText}) {
            return InputDecoration(
              labelText: label,
              hintText: hintText,
              filled: true,
              fillColor: context.themeSurface,
              labelStyle: GoogleFonts.inter(color: context.themeTextDark.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w500),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            );
          }

          return AlertDialog.adaptive(
            backgroundColor: context.themeSurface,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'Add New Coupon',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: context.themeTextDark, fontSize: 24),
            ),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeCtrl,
                      style: GoogleFonts.inter(color: context.themeTextDark, fontWeight: FontWeight.w600),
                      decoration: inputDecoration('Coupon Code', hintText: 'e.g. SAVE50'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _discountCtrl,
                      style: GoogleFonts.inter(color: context.themeTextDark, fontWeight: FontWeight.w600),
                      decoration: inputDecoration('Discount Amount (\$)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _limitCtrl,
                      style: GoogleFonts.inter(color: context.themeTextDark, fontWeight: FontWeight.w600),
                      decoration: inputDecoration('Usage Limit (Optional)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _userCtrl,
                      style: GoogleFonts.inter(color: context.themeTextDark, fontWeight: FontWeight.w600),
                      decoration: inputDecoration('Targeted Emails', hintText: 'email1@example.com, ...'),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: Text(
                          _selectedDate == null ? 'Select Expiry Date' : 'Expires: ${_selectedDate.toString().split(' ')[0]}',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: context.themeTextDark),
                        ),
                        trailing: const Icon(Icons.calendar_today_outlined, size: 20, color: AppTheme.primary),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setDialogState(() => _selectedDate = date);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: EdgeInsets.fromLTRB(24, 0, 24, 24),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextLight)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _addCoupon,
                child: const Text('Create Coupon'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coupon Management', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: context.themeTextDark)),
                  const SizedBox(height: 8),
                  Text('Create and manage discount coupons for services.', style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 14)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add Coupon'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('coupons').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator.adaptive());
                final coupons = snap.data!.docs.map((d) => CouponModel.fromFirestore(d)).toList();

                if (coupons.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_offer_outlined, size: 64, color: context.themeTextLight.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text('No coupons found', style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: context.themeSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(color: context.isDarkMode ? Colors.transparent : Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: coupons.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                    itemBuilder: (context, index) {
                      final c = coupons[index];
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.confirmation_number_outlined, color: AppTheme.primary),
                        ),
                        title: Text(
                          c.code,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18, color: context.themeTextDark),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Discount: \$${c.discount} • Used: ${c.usageCount}/${c.usageLimit ?? "∞"}',
                            style: GoogleFonts.inter(color: context.themeTextLight, fontWeight: FontWeight.w500),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  c.isActive ? 'Active' : 'Inactive',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: c.isActive ? Colors.green : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 24,
                                  width: 44,
                                  child: Switch.adaptive(
                                    value: c.isActive,
                                    activeColor: AppTheme.primary,
                                    onChanged: (val) => FirebaseFirestore.instance.collection('coupons').doc(c.id).update({'isActive': val}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                              onPressed: () {
                                showAdaptiveDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog.adaptive(
                                    title: const Text('Delete Coupon?'),
                                    content: Text('Are you sure you want to delete coupon "${c.code}"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () {
                                          FirebaseFirestore.instance.collection('coupons').doc(c.id).delete();
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
