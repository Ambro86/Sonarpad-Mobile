import 'package:flutter/material.dart';

import '../widgets/native_ios_accessible_view.dart';

class CategoryNativeItem {
  const CategoryNativeItem({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
}

class CategoryScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<CategoryNativeItem> nativeItems;

  const CategoryScreen({
    super.key,
    required this.title,
    required this.children,
    this.nativeItems = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: useNativeIosAccessibleViews && nativeItems.isNotEmpty
            ? NativeIosAccessibleList(
                sections: [
                  NativeIosListSection(
                    rows: nativeItems
                        .asMap()
                        .entries
                        .map((entry) => NativeIosListRow(
                              id: 'category_${entry.key}',
                              title: entry.value.label,
                            ))
                        .toList(growable: false),
                  ),
                ],
                onEvent: (event) {
                  if (event.type != 'activate' || event.id == null) return;
                  final index = int.tryParse(
                    event.id!.replaceFirst('category_', ''),
                  );
                  if (index != null && index >= 0 && index < nativeItems.length) {
                    nativeItems[index].onPressed();
                  }
                },
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: children,
              ),
      ),
    );
  }
}
