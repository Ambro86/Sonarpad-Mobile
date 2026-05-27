import 'package:flutter/material.dart';

/// Wrapper semantico che intercetta i comandi di scorrimento globale
/// (come lo swipe a 3 dita in alto/basso di VoiceOver/TalkBack)
/// e forza lo scorrimento del [controller] fornito.
class SonarpadScroller extends StatelessWidget {
  final Widget child;
  final ScrollController controller;

  const SonarpadScroller({
    super.key,
    required this.child,
    required this.controller,
  });

  void _scrollBy(BuildContext context, double amount) {
    if (controller.hasClients) {
      final position = controller.position;
      final target = (position.pixels + amount).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // In Flutter, 'scrollUp' indica che l'utente vuole scorrere verso la parte
      // superiore del contenuto (spesso generato da uno swipe verso il basso a 3 dita).
      // Quindi dobbiamo *diminuire* l'offset.
      onScrollUp: () {
        final height = MediaQuery.of(context).size.height * 0.7;
        _scrollBy(context, -height);
      },
      // In Flutter, 'scrollDown' indica che l'utente vuole scorrere verso la parte
      // inferiore del contenuto (spesso generato da uno swipe verso l'alto a 3 dita).
      // Quindi dobbiamo *aumentare* l'offset.
      onScrollDown: () {
        final height = MediaQuery.of(context).size.height * 0.7;
        _scrollBy(context, height);
      },
      child: child,
    );
  }
}
