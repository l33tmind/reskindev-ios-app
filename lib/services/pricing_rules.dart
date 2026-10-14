import 'package:cloud_firestore/cloud_firestore.dart';

/// One rule for every order value, shared with the website and the Vision Pro app:
/// at least $5, in steps of $5 (5, 10, 15, ...). Admins can change both in settings/global
/// (minOrderPrice, priceStep); without them the defaults below apply.
class PricingRules {
  final double min;
  final double step;
  const PricingRules({this.min = 5, this.step = 5});

  static Future<PricingRules> load() async {
    try {
      final d = (await FirebaseFirestore.instance.collection('settings').doc('global').get()).data() ?? {};
      final min = double.tryParse('${d['minOrderPrice']}') ?? 5;
      final step = double.tryParse('${d['priceStep']}') ?? 5;
      return PricingRules(min: min > 0 ? min : 5, step: step > 0 ? step : 5);
    } catch (_) {
      return const PricingRules();
    }
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// null when the price is fine, otherwise a message for the user
  String? check(num? value) {
    if (value == null) return 'Enter a price.';
    if (value < min) return 'The minimum order is \$${_fmt(min)}.';
    // Work in cents so float noise can't reject a good value
    if ((value * 100).round() % (step * 100).round() != 0) {
      return 'Prices go up in steps of \$${_fmt(step)} (${_fmt(min)}, ${_fmt(min + step)}, ${_fmt(min + 2 * step)}…).';
    }
    return null;
  }
}
