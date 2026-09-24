import re

with open('lib/screens/my_orders_screen.dart', 'r') as f:
    content = f.read()

if 'live_timer.dart' not in content:
    content = content.replace("import '../widgets/web_nav_bar.dart';", "import '../widgets/web_nav_bar.dart';\nimport '../widgets/live_timer.dart';")

old_date = """                          Text('Package: ${order.packageName}',
                            style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                          ),
                          Container(width: 4, height: 4, decoration: BoxDecoration(color: AppTheme.textMuted, shape: BoxShape.circle)),
                          Text(formattedDate,
                            style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                          ),
                        ],
                      ),
                    ],
                  ),"""

new_date = """                          Text('Package: ${order.packageName}',
                            style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                          ),
                          Container(width: 4, height: 4, decoration: BoxDecoration(color: AppTheme.textMuted, shape: BoxShape.circle)),
                          Text(formattedDate,
                            style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                          ),
                        ],
                      ),
                      if (order.status == 'in_progress' || order.status == 'requirements') ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 14, color: Colors.orange),
                            const SizedBox(width: 4),
                            LiveTimer(startTime: order.startedAt ?? order.createdAt, deliveryDays: order.deliveryDays),
                          ],
                        )
                      ],
                    ],
                  ),"""
content = content.replace(old_date, new_date)

with open('lib/screens/my_orders_screen.dart', 'w') as f:
    f.write(content)

print("Added LiveTimer to MyOrdersScreen")
