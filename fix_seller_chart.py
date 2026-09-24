import re

with open('lib/screens/seller_dashboard_screen.dart', 'r') as f:
    content = f.read()

if 'earnings_chart.dart' not in content:
    content = content.replace("import '../widgets/web_nav_bar.dart';", "import '../widgets/web_nav_bar.dart';\nimport '../widgets/earnings_chart.dart';")

old_earnings = """                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.themeTextDark,
                                side: BorderSide(color: context.themeBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text('Withdraw Funds', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      ),
                    ],
                  );"""

new_earnings = """                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.themeTextDark,
                                side: BorderSide(color: context.themeBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text('Withdraw Funds', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      EarningsChart(orders: orderSnap.data!.docs),
                    ],
                  );"""
content = content.replace(old_earnings, new_earnings)

with open('lib/screens/seller_dashboard_screen.dart', 'w') as f:
    f.write(content)

print("Added EarningsChart to Seller Dashboard")
