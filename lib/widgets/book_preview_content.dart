import 'package:flutter/material.dart';
import 'universal_accessible_view.dart';
import '../utils/book_preview_segments.dart';

class BookPreviewContent extends StatelessWidget {
  const BookPreviewContent({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final segments = splitBookPreview(text);
    return UniversalAccessibleTextBlocks(
      rows: [
        for (var i = 0; i < segments.length; i++)
          AccessibleListRow(id: 'preview_$i', kind: 'text', title: segments[i]),
      ],
    );
  }
}
