import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Inline syntax for `==highlighted==` text.
class HighlightSyntax extends md.InlineSyntax {
  HighlightSyntax() : super(r'==(.+?)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final el = md.Element.text('highlight', match[1]!);
    parser.addNode(el);
    return true;
  }
}

class HighlightBuilder extends MarkdownElementBuilder {
  HighlightBuilder(this.color);
  final Color color;

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(element.textContent, style: preferredStyle),
    );
  }
}
