import 'package:flutter/material.dart';

class CategoryScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const CategoryScreen({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: children,
        ),
      ),
    );
  }
}
