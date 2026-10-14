import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

/// "About this service" on the gig page, laid out for easy reading.
///
/// Sellers paste descriptions from everywhere: one long paragraph, "• a • b • c" squeezed into one line,
/// inline colors that vanish in dark mode. This reads the text (keeping bold, italic and links) and shows it
/// in one calm style: short headings, paragraphs with room between them, and list items as ✓ rows.
/// It opens in place ("Read more" / "Show less") instead of a separate sheet, so the order button stays in reach.
class GigDescription extends StatefulWidget {
  final String html;
  final String title;
  const GigDescription({super.key, required this.html, this.title = 'About this service'});

  @override
  State<GigDescription> createState() => _GigDescriptionState();
}

class _GigDescriptionState extends State<GigDescription> {
  bool _expanded = false;
  late List<_Block> _blocks = parseDescription(widget.html);

  @override
  void didUpdateWidget(covariant GigDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) _blocks = parseDescription(widget.html);
  }

  /// Folded: the first blocks up to about 280 characters (at least 2 blocks)
  int get _foldedCount {
    var chars = 0;
    var count = _blocks.length;
    for (var i = 0; i < _blocks.length; i++) {
      chars += _blocks[i].length;
      if (i >= 1 && chars > 280) {
        count = i + 1;
        break;
      }
    }
    // Never stop on a heading: show the first two items under it, so the preview ends on something useful
    if (count < _blocks.length && _blocks[count - 1].kind == _Kind.heading) {
      count = (count + 2).clamp(0, _blocks.length);
    }
    // Not worth folding when only a little is left
    final rest = _blocks.skip(count).fold<int>(0, (n, b) => n + b.length);
    return rest < 80 ? _blocks.length : count;
  }

  @override
  Widget build(BuildContext context) {
    if (_blocks.isEmpty) return const SizedBox.shrink();
    final canFold = _foldedCount < _blocks.length;
    final shown = _expanded || !canFold ? _blocks : _blocks.take(_foldedCount).toList();
    final minutes = (_blocks.fold<int>(0, (n, b) => n + b.words) / 200).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(widget.title,
                style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: context.themeTextDark)),
            ),
            if (minutes > 1)
              Text('$minutes min read', style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
          ],
        ),
        const SizedBox(height: 10),
        // Tapping the folded text opens it too, not only the small "Read more" link
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canFold && !_expanded ? () => setState(() => _expanded = true) : null,
          child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final b in shown) _BlockView(block: b)],
              ),
              // Soft fade over the last folded line, so it's clear there's more
              if (canFold && !_expanded)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 36,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [context.themeBackground.withValues(alpha: 0), context.themeBackground],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ),
        if (canFold)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 40),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            iconAlignment: IconAlignment.end,
            icon: Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 20),
            label: Text(_expanded ? 'Show less' : 'Read more'),
          ),
      ],
    );
  }
}

enum _Kind { heading, paragraph, bullet, numbered }

class _Run {
  final String text;
  final bool bold;
  final bool italic;
  final String? href;
  const _Run(this.text, {this.bold = false, this.italic = false, this.href});
  _Run withText(String t) => _Run(t, bold: bold, italic: italic, href: href);
}

class _Block {
  final _Kind kind;
  final List<_Run> runs;
  final String? number;
  _Block(this.kind, this.runs, {this.number});
  String get plain => runs.map((r) => r.text).join();
  int get length => plain.length;
  int get words => plain.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}

const _blockTags = {'p', 'div', 'br', 'li', 'ul', 'ol', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'section', 'article', 'blockquote', 'tr', 'table'};
final _bulletMark = RegExp(r'^\s*(?:[•●▪◦‣∙·*✓✔✅☑→➤►▶➜-]|–|—)\s+');
final _numberMark = RegExp(r'^\s*(\d{1,2})[.)]\s+');
final _inlineBullet = RegExp(r'\s*[•●▪◦‣∙]\s*');

/// HTML (or plain text) → headings, paragraphs and list items
List<_Block> parseDescription(String source) {
  final doc = html_parser.parseFragment(source.replaceAll('&nbsp;', ' ').replaceAll(' ', ' '));
  final lines = <({List<_Run> runs, bool li, bool heading})>[];
  var current = <_Run>[];
  var inLi = false;
  var inHeading = false;

  void flush() {
    if (current.any((r) => r.text.trim().isNotEmpty)) {
      lines.add((runs: current, li: inLi, heading: inHeading));
    }
    current = <_Run>[];
  }

  void walk(dom.Node node, {bool bold = false, bool italic = false, String? href}) {
    if (node is dom.Text) {
      // Plain-text descriptions: every newline is a line break
      final parts = node.text.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) flush();
        final t = parts[i].replaceAll(RegExp(r'[ \t\r]+'), ' ');
        if (t.isNotEmpty) current.add(_Run(t, bold: bold, italic: italic, href: href));
      }
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName ?? '';
    if (const {'script', 'style', 'iframe', 'img', 'video', 'object', 'embed'}.contains(tag)) return;
    final isBlock = _blockTags.contains(tag);
    final wasLi = inLi, wasHeading = inHeading;
    if (isBlock) flush();
    if (tag == 'li') inLi = true;
    if (tag.length == 2 && tag.startsWith('h')) inHeading = true;
    for (final child in node.nodes) {
      walk(child,
        bold: bold || tag == 'b' || tag == 'strong',
        italic: italic || tag == 'i' || tag == 'em',
        href: tag == 'a' ? node.attributes['href'] : href);
    }
    if (isBlock) flush();
    inLi = wasLi;
    inHeading = wasHeading;
  }

  for (final n in doc.nodes) {
    walk(n);
  }
  flush();

  // Trim each line's runs
  List<_Run> trimmed(List<_Run> runs) {
    final out = runs.where((r) => r.text.isNotEmpty).toList();
    if (out.isEmpty) return out;
    out[0] = out[0].withText(out[0].text.trimLeft());
    out[out.length - 1] = out.last.withText(out.last.text.trimRight());
    return out.where((r) => r.text.isNotEmpty).toList();
  }

  final blocks = <_Block>[];
  for (final line in lines) {
    final runs = trimmed(line.runs);
    if (runs.isEmpty) continue;
    final plain = runs.map((r) => r.text).join();

    // "My services include: • a • b • c" → a lead-in heading plus one ✓ row per item
    if (_inlineBullet.allMatches(plain).length >= 2) {
      final parts = plain.split(_inlineBullet).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      final leadIn = plain.trimLeft().startsWith(RegExp(r'[•●▪◦‣∙]')) ? null : parts.removeAt(0);
      if (leadIn != null) blocks.add(_Block(leadIn.endsWith(':') ? _Kind.heading : _Kind.paragraph, [_Run(leadIn)]));
      for (final p in parts) {
        blocks.add(_Block(_Kind.bullet, [_Run(p)]));
      }
      continue;
    }

    final bullet = _bulletMark.firstMatch(plain);
    final number = _numberMark.firstMatch(plain);
    if (line.li || bullet != null) {
      blocks.add(_Block(_Kind.bullet, _stripPrefix(runs, bullet?.end ?? 0)));
    } else if (number != null) {
      blocks.add(_Block(_Kind.numbered, _stripPrefix(runs, number.end), number: number.group(1)));
    } else if (line.heading ||
        (plain.length <= 60 && (plain.endsWith(':') || runs.every((r) => r.bold)) && !plain.endsWith('.'))) {
      blocks.add(_Block(_Kind.heading, runs));
    } else {
      blocks.add(_Block(_Kind.paragraph, runs));
    }
  }
  return blocks;
}

List<_Run> _stripPrefix(List<_Run> runs, int chars) {
  final out = <_Run>[];
  var left = chars;
  for (final r in runs) {
    if (left >= r.text.length) {
      left -= r.text.length;
      continue;
    }
    out.add(left > 0 ? r.withText(r.text.substring(left)) : r);
    left = 0;
  }
  return out;
}

class _BlockView extends StatelessWidget {
  final _Block block;
  const _BlockView({required this.block});

  TextSpan _spans(BuildContext context, TextStyle base) {
    return TextSpan(
      style: base,
      children: [
        for (final r in block.runs)
          TextSpan(
            text: r.text,
            style: TextStyle(
              fontWeight: r.bold ? FontWeight.w700 : null,
              fontStyle: r.italic ? FontStyle.italic : null,
              color: r.href != null ? AppTheme.primary : null,
              decoration: r.href != null ? TextDecoration.underline : null,
            ),
            recognizer: r.href == null
                ? null
                : (TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(r.href!), mode: LaunchMode.externalApplication)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = GoogleFonts.inter(fontSize: 15, height: 1.6, color: context.themeTextDark.withValues(alpha: 0.88));
    switch (block.kind) {
      case _Kind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text.rich(_spans(context, GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.4, color: context.themeTextDark))),
        );
      case _Kind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text.rich(_spans(context, body)),
        );
      case _Kind.bullet:
      case _Kind.numbered:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: block.kind == _Kind.numbered
                    ? Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: Text(block.number!, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text.rich(_spans(context, body))),
            ],
          ),
        );
    }
  }
}
