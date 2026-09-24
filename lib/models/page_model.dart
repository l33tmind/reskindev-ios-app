import 'package:cloud_firestore/cloud_firestore.dart';

class PageModel {
  final String id;
  final String slug;
  final String title;
  final String content;
  final String linkUrl;       // External URL (e.g. https://google.com)
  final bool openInNewTab;   // Open in new tab or same tab
  final String pageType;     // 'content' = show content page, 'link' = go to URL
  final int order;
  final bool isVisible;

  PageModel({
    required this.id,
    required this.slug,
    required this.title,
    this.content = '',
    this.linkUrl = '',
    this.openInNewTab = true,
    this.pageType = 'link',
    required this.order,
    this.isVisible = true,
  });

  static String generateSlug(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  }

  factory PageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String titleStr = data['title'] ?? '';
    return PageModel(
      id: doc.id,
      slug: data['slug'] != null && data['slug'].toString().isNotEmpty 
          ? data['slug'] 
          : generateSlug(titleStr),
      title: titleStr,
      content: data['content'] ?? '',
      linkUrl: (data['linkUrl'] ?? data['link_url']) ?? '',
      openInNewTab: (data['openInNewTab'] ?? data['open_in_new_tab']) ?? true,
      pageType: (data['pageType'] ?? data['page_type']) ?? 'link',
      order: data['order'] ?? 0,
      isVisible: (data['isVisible'] ?? data['is_visible']) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slug': slug,
      'title': title,
      'content': content,
      'link_url': linkUrl,
      'open_in_new_tab': openInNewTab,
      'page_type': pageType,
      'order': order,
      'is_visible': isVisible,
    };
  }
}
