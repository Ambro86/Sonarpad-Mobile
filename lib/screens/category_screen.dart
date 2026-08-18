import 'package:flutter/material.dart';

import '../widgets/universal_accessible_view.dart';

class CategoryAccessibleItem {
  const CategoryAccessibleItem({
    required this.label,
    required this.onPressed,
    this.flutterChild,
  });
  final String label;
  final VoidCallback onPressed;
  final Widget? flutterChild;
}

class CategoryScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<CategoryAccessibleItem> accessibleItems;

  const CategoryScreen({
    super.key,
    required this.title,
    required this.children,
    this.accessibleItems = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: useSharedAccessibleViewModel && accessibleItems.isNotEmpty
            ? UniversalAccessibleList(
                sections: [
                  AccessibleListSection(
                    rows: accessibleItems
                        .asMap()
                        .entries
                        .map((entry) => AccessibleListRow(
                              id: 'category_${entry.key}',
                              title: entry.value.label,
                              onActivate: entry.value.onPressed,
                              flutterChild: entry.value.flutterChild,
                            ))
                        .toList(growable: false),
                  ),
                ],
                padding: const EdgeInsets.all(16),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: children,
              ),
      ),
    );
  }
}
