import '../widgets/search_bottom_sheet.dart';
import '../providers/gig_provider.dart';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/connectivity_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/user_avatar.dart';

/// The persistent bottom navigation shell for the Android app.
class MobileShell extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const MobileShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  int _getSelectedIndex(bool isSeller) {
    final path = widget.currentPath;
    if (path.startsWith('/all-services')) return 1;
    if (path.startsWith('/seller')) return 2; // Seller Mode Maps to index 2
    if (path.startsWith('/my-orders')) return 2; // Buyer Mode Maps to index 2
    if (path.startsWith('/inbox')) return 3;
    if (path.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTabTap(int index, bool isSeller) {
    HapticFeedback.selectionClick();
    switch (index) {
      case 0: context.go('/'); break;
      case 1: context.go('/all-services'); break;
      case 2:
        if (isSeller) {
          context.go('/seller');
        } else {
          context.go('/my-orders');
        }
        break;
      case 3: context.go('/inbox'); break;
      case 4: context.go('/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ap.AuthProvider, ConnectivityProvider, ChatProvider>(
      builder: (context, auth, conn, chatProvider, child) {
        final pendingCount = 0; // Will integrate with orders stream

        return Scaffold(
          body: Stack(
            children: [
              widget.child,
              if (!conn.isOnline)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.red.withOpacity(0.9),
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      bottom: 8,
                    ),
                    child: const Text(
                      'No Internet Connection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: StreamBuilder(
            stream: auth.isLoggedIn ? chatProvider.getInbox(auth.user!.uid) : const Stream.empty(),
            builder: (context, snapshot) {
              int unreadChatCount = 0;
              if (snapshot.hasData && auth.isLoggedIn && auth.user != null) {
                final chats = snapshot.data as List;
                for (var chat in chats) {
                  final Map unreads = chat.unreadCount;
                  if ((unreads[auth.user!.uid] ?? 0) > 0) {
                    unreadChatCount++;
                  }
                }
              }
              return _BottomNav(
                selectedIndex: _getSelectedIndex(auth.isSellerMode),
                onTap: (index) => _onTabTap(index, auth.isSellerMode),
                isSellerMode: auth.isSellerMode,
                orderBadge: pendingCount,
                chatBadge: unreadChatCount,
                isLoggedIn: auth.isLoggedIn,
                photoUrl: auth.user?.photoURL,
              );
            },
          ),
        );
      },
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final int orderBadge;
  final int chatBadge;
  final bool isLoggedIn;
  final String? photoUrl;
  final bool isSellerMode;

  const _BottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.orderBadge,
    this.chatBadge = 0,
    required this.isLoggedIn,
    this.photoUrl,
    this.isSellerMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        border: Border(top: BorderSide(color: context.themeBorder, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          if (index != selectedIndex) onTap(index);
        },
        backgroundColor: context.themeSurface,
        selectedItemColor: AppTheme.primary, // Facebook-like blue
        unselectedItemColor: context.isDarkMode ? Colors.white54 : Colors.black87,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        iconSize: 24,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: isSellerMode ? const Icon(Icons.storefront_outlined) : (orderBadge > 0
                  ? Badge.count(count: orderBadge, child: const Icon(Icons.receipt_long_outlined))
                  : const Icon(Icons.receipt_long_outlined)),
            activeIcon: isSellerMode ? const Icon(Icons.storefront) : const Icon(Icons.receipt_long),
            label: isSellerMode ? 'Dashboard' : 'Orders',
          ),
          BottomNavigationBarItem(
            icon: chatBadge > 0
                ? Badge.count(count: chatBadge, child: const Icon(Icons.chat_bubble_outline))
                : const Icon(Icons.chat_bubble_outline),
            activeIcon: const Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: isLoggedIn && photoUrl != null
                  ? UserAvatar(
                      name: 'Profile',
                      photoUrl: photoUrl,
                      radius: 12,
                    )
                  : const Icon(Icons.person_outline),
            activeIcon: isLoggedIn && photoUrl != null
                  ? Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primary, width: 2),
                      ),
                      child: UserAvatar(
                        name: 'Profile',
                        photoUrl: photoUrl,
                        radius: 10,
                      ),
                    )
                  : const Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}


