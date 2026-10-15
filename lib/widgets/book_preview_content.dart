import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../utils/book_preview_segments.dart';

class BookPreviewContent extends StatelessWidget {
  const BookPreviewContent({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final segments = splitBookPreview(text);
    // Keep every reading block mounted. Native table cells taller than the
    // dialog viewport get recycled during VoiceOver's backwards traversal.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < segments.length; i++)
            Builder(
              key: ValueKey('preview_$i'),
              builder: (context) => Semantics(
                container: true,
                sortKey: OrdinalSortKey(i.toDouble()),
                onDidGainAccessibilityFocus: () {
                  Scrollable.ensureVisible(context);
                },
                child: Text(segments[i]),
              ),
            ),
        ],
      ),
    );
  }
}
