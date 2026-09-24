import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LiveTimer extends StatefulWidget {
  final DateTime startTime;
  final int deliveryDays;

  const LiveTimer({super.key, required this.startTime, required this.deliveryDays});

  @override
  State<LiveTimer> createState() => _LiveTimerState();
}

class _LiveTimerState extends State<LiveTimer> {
  late DateTime _deadline;
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _deadline = widget.startTime.add(Duration(days: widget.deliveryDays));
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _remaining = _deadline.difference(now);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) {
      return Text('Late Delivery', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13));
    }

    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24);
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    return Text(
      '${days}d ${hours}h ${minutes}m ${seconds}s',
      style: GoogleFonts.inter(
        color: Colors.orange.shade700,
        fontWeight: FontWeight.bold,
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: 13,
      ),
    );
  }
}
