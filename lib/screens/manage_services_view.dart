import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme.dart';
import '../../models/gig_model.dart';
import 'gig_editor_screen.dart';

import 'package:provider/provider.dart';
import '../../providers/gig_provider.dart';

class ManageServicesView extends StatelessWidget {
  const ManageServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Consumer<GigProvider>(
      builder: (context, provider, child) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final gigs = provider.gigs;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manage Services',
                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: context.themeTextDark)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/admin/edit-gig'),
                        icon: Icon(Icons.add),
                        label: const Text('Add New Service'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Manage Services',
                            style: GoogleFonts.outfit(
                                fontSize: 32, fontWeight: FontWeight.w800, color: context.themeTextDark)),
                        const SizedBox(height: 8),
                        Text('Drag and drop to reorder. Add, edit, or remove services.',
                            style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/admin/edit-gig'),
                      icon: Icon(Icons.add),
                      label: const Text('Add Service'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              if (gigs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(48),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.themeSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.themeBorder, style: BorderStyle.solid),
                  ),
                  child: Text('No services added yet. Click "Add Service" to create one.',
                      style: GoogleFonts.inter(color: context.themeTextLight)),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ReorderableWrap(
                    spacing: 24,
                    runSpacing: 24,
                    onReorder: (oldIndex, newIndex) {
                      final updatedList = List<GigModel>.from(gigs);
                      final item = updatedList.removeAt(oldIndex);
                      updatedList.insert(newIndex, item);
                      provider.updateServiceOrder(updatedList);
                    },
                    children: gigs.map<Widget>((gig) => _AdminGigCard(key: ValueKey(gig.id), gig: gig)).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ReorderableWrap extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ReorderableWrap({
    super.key,
    required this.children,
    required this.onReorder,
    this.spacing = 0,
    this.runSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;

        return LongPressDraggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.8,
              child: child,
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: child,
          ),
          child: DragTarget<int>(
            onWillAcceptWithDetails: (details) => details.data != index,
            onAcceptWithDetails: (details) => onReorder(details.data, index),
            builder: (context, candidateData, rejectedData) {
              return child;
            },
          ),
        );
      }).toList(),
    );
  }
}

class _AdminGigCard extends StatelessWidget {
  final GigModel gig;
  const _AdminGigCard({super.key, required this.gig});

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text('Delete Service?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to delete this service?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('services').doc(gig.id).delete();
    }
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'draft':
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = 'DRAFT';
        break;
      case 'pending':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        label = 'PENDING';
        break;
      case 'published':
      default:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'PUBLISHED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width < 600 ? width - 32 : 340.0;
    
    return Container(
      width: cardWidth,
      margin: width < 600 ? EdgeInsets.only(bottom: 16) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.themeBorder),
        boxShadow: [
          BoxShadow(color: context.isDarkMode ? Colors.transparent : Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Image.network(
              gig.imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                color: const Color(0xFFF3F4F6),
                child: Icon(Icons.design_services, size: 48, color: Color(0xFFD1D5DB)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        gig.title,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: context.themeTextDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(gig.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${gig.basePrice.toInt()} Base Price · ${gig.packages.length} Packages',
                  style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/admin/edit-gig', extra: gig),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => _delete(context),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete Service',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
