import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/page_provider.dart';
import '../models/page_model.dart';
import '../theme.dart';

class ManagePagesView extends StatefulWidget {
  const ManagePagesView({super.key});

  @override
  State<ManagePagesView> createState() => _ManagePagesViewState();
}

class _ManagePagesViewState extends State<ManagePagesView> {
  void _showPageForm([PageModel? page]) {
    final titleCtrl = TextEditingController(text: page?.title);
    final slugCtrl = TextEditingController(text: page?.slug);
    final linkUrlCtrl = TextEditingController(text: page?.linkUrl);
    final contentCtrl = TextEditingController(text: page?.content);
    final orderCtrl = TextEditingController(text: (page?.order ?? 0).toString());
    bool isVisible = page?.isVisible ?? true;
    bool openInNewTab = page?.openInNewTab ?? true;
    String pageType = page?.pageType ?? 'link';

    showAdaptiveDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
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

          return Dialog(
            backgroundColor: context.themeSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: EdgeInsets.all(32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            page == null ? 'Add Menu Item' : 'Edit Menu Item',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: context.themeTextDark, fontSize: 24),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: context.themeTextLight),
                            onPressed: () => Navigator.pop(ctx),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: titleCtrl,
                        style: GoogleFonts.inter(color: context.themeTextDark, fontWeight: FontWeight.w500),
                        decoration: inputDecoration('Menu Title'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: slugCtrl,
                        style: GoogleFonts.inter(color: context.themeTextDark, fontWeight: FontWeight.w500),
                        decoration: inputDecoration('Custom Link Path (Optional)', hintText: 'e.g. contact-us'),
                      ),
                      const SizedBox(height: 24),
                      Text('Menu Type', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: context.themeTextDark)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TypeButton(
                              label: '🔗 Link to URL',
                              selected: pageType == 'link',
                              onTap: () => setStateSB(() => pageType = 'link'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TypeButton(
                              label: '📄 Content Page',
                              selected: pageType == 'content',
                              onTap: () => setStateSB(() => pageType = 'content'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (pageType == 'link') ...[
                        TextField(
                          controller: linkUrlCtrl,
                          style: GoogleFonts.inter(color: context.themeTextDark, fontWeight: FontWeight.w500),
                          decoration: inputDecoration('URL (link)', hintText: 'https://example.com'),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Open in new tab', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                          activeColor: AppTheme.primary,
                          value: openInNewTab,
                          onChanged: (v) => setStateSB(() => openInNewTab = v),
                        ),
                      ] else ...[
                        TextField(
                          controller: contentCtrl,
                          maxLines: 6,
                          style: GoogleFonts.inter(color: context.themeTextDark, fontWeight: FontWeight.w500),
                          decoration: inputDecoration('Page Content (HTML Supported)'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: orderCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(color: context.themeTextDark, fontWeight: FontWeight.w500),
                        decoration: inputDecoration('Menu Order (0, 1, 2...)'),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Show in Menu', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                        activeColor: AppTheme.primary,
                        value: isVisible,
                        onChanged: (v) => setStateSB(() => isVisible = v),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final newPage = PageModel(
                              id: page?.id ?? '',
                              slug: slugCtrl.text.trim().isEmpty ? PageModel.generateSlug(titleCtrl.text) : PageModel.generateSlug(slugCtrl.text),
                              title: titleCtrl.text,
                              content: contentCtrl.text,
                              linkUrl: linkUrlCtrl.text,
                              openInNewTab: openInNewTab,
                              pageType: pageType,
                              order: int.tryParse(orderCtrl.text) ?? 0,
                              isVisible: isVisible,
                            );

                            if (page == null) {
                              await context.read<PageProvider>().addPage(newPage);
                            } else {
                              await context.read<PageProvider>().updatePage(newPage);
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PageProvider>();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manage Menu Items',
                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: context.themeTextDark)),
                    const SizedBox(height: 8),
                    Text('Add links or content pages to the website navigation menu.',
                        style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showPageForm(),
                icon: Icon(Icons.add, size: 18),
                label: const Text('Add Menu Item'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (provider.loading)
            const Center(child: CircularProgressIndicator.adaptive())
          else if (provider.pages.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(60),
                child: Column(
                  children: [
                    Icon(Icons.menu_open, size: 60, color: context.themeBorder),
                    const SizedBox(height: 16),
                    Text('No menu items yet.', style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Click "Add Menu Item" to get started.', style: GoogleFonts.inter(color: context.themeTextLight)),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: context.themeSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.themeBorder),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.pages.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: context.themeBorder),
                itemBuilder: (context, index) {
                  final pg = provider.pages[index];
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: pg.pageType == 'link'
                            ? Colors.blue.withOpacity(0.1)
                            : AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        pg.pageType == 'link' ? Icons.link : Icons.article_outlined,
                        color: pg.pageType == 'link' ? Colors.blue : AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      pg.title,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextDark),
                    ),
                    subtitle: Text(
                      pg.pageType == 'link'
                          ? '🔗 ${pg.linkUrl.isEmpty ? "No URL set" : pg.linkUrl} ${pg.openInNewTab ? "(new tab)" : "(same tab)"}'
                          : '📄 Content Page',
                      style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Visibility badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: pg.isVisible ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            pg.isVisible ? 'Visible' : 'Hidden',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: pg.isVisible ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
                          onPressed: () => _showPageForm(pg),
                          tooltip: 'Edit',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          tooltip: 'Delete',
                          onPressed: () {
                            showAdaptiveDialog(
                              context: context,
                              builder: (ctx) => AlertDialog.adaptive(
                                title: const Text('Delete Menu Item?'),
                                content: Text('Are you sure you want to delete "${pg.title}"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () {
                                      context.read<PageProvider>().deletePage(pg.id);
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
            ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.08) : context.themeSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.black12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? AppTheme.primary : context.themeTextDark,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
