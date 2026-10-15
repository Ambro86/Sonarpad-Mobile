import 'package:flutter/material.dart';
import '../utils/book_preview_segments.dart';
import 'universal_accessible_view.dart';

class BookPreviewContent extends StatelessWidget {
  const BookPreviewContent({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final segments = splitBookPreview(text);
    if (useSharedAccessibleViewModel) {
      return SizedBox(
        width: 520,
        height: 420,
        child: UniversalAccessibleList(
          sections: [
            AccessibleListSection(
              rows: [
                for (var i = 0; i < segments.length; i++)
                  AccessibleListRow(
                    id: 'preview_$i',
                    kind: 'text',
                    title: segments[i],
                  ),
              ],
            ),
          ],
          onEvent: (_) {},
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final segment in segments)
            Semantics(container: true, child: Text(segment)),
        ],
      ),
    );
  }
}
