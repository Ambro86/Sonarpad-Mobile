import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/utils/tv_return_focus.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

class FocusSpy extends AccessibleListController {
  final calls=<String>[];
  @override
  Future<void> focusAccessibleRow(String id,{AccessibleFocusMode mode=AccessibleFocusMode.inPlaceJump,bool animated=false}) async {
    expectSync(mode,AccessibleFocusMode.routeReturnJump);
    expectSync(animated,isFalse);
    calls.add(id);
  }
}
void main() {
  for (final action in ['open','play_live','play_record']) {
    testWidgets('$action restores exact channel only after returning', (tester) async {
      late BuildContext source;
      final focus=FocusSpy();
      final navigator=GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey:navigator,home:Builder(builder:(c){source=c;return const Scaffold(body:Text('channels'));})));
      final pending=restoreTvRowAfterAction(source,focus,'Rai 3',()=>Navigator.of(source).push<void>(MaterialPageRoute(builder:(_)=>const Scaffold(body:Text('player')))));
      await tester.pumpAndSettle();
      expect(focus.calls,isEmpty);
      navigator.currentState!.pop();await tester.pumpAndSettle();await pending;
      expect(focus.calls,['Rai 3']);
    });
  }
  testWidgets('hidden list does not steal focus', (tester) async {
    late BuildContext source;
    final focus=FocusSpy();
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(c){source=c;return const SizedBox();})));
    final pending=restoreTvRowAfterAction(source,focus,'Rai 1',() {
      Navigator.of(source).push<void>(MaterialPageRoute(builder:(_)=>const Scaffold(body:Text('other'))));
    });
    await tester.pumpAndSettle();await pending;
    expect(focus.calls,isEmpty);
  });
  testWidgets('disposed list does not restore focus', (tester) async {
    late BuildContext source;
    final focus=FocusSpy();final done=Completer<void>();
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(c){source=c;return const SizedBox();})));
    final pending=restoreTvRowAfterAction(source,focus,'Rai 1',()=>done.future);
    await tester.pumpWidget(const SizedBox());done.complete();await tester.pump();await pending;
    expect(focus.calls,isEmpty);
  });
  testWidgets('failed opening returns focus and propagates failure', (tester) async {
    late BuildContext source;final focus=FocusSpy();
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(c){source=c;return const SizedBox();})));
    final check=expectLater(restoreTvRowAfterAction(source,focus,'Rai 2',()=>throw StateError('failed')),throwsStateError);
    await tester.pumpAndSettle();await check;
    expect(focus.calls,['Rai 2']);
  });
  test('categories, search and favorites await their route and retain search results', () {
    final tv=File('lib/screens/tv_screen.dart').readAsStringSync();
    final favorites=File('lib/screens/favorite_tvs_screen.dart').readAsStringSync();
    for(final source in [tv,favorites]) {
      expect(source,contains('FutureOr<void> Function(TvChannel) onOpenChannel'));
      expect(source,contains('controller: _returnFocus'));
      expect(source,contains('await _openAndRestore(channel, widget.onOpenChannel)'));
      expect(source,contains('await _openAndRestore(channel, widget.onPlayLive)'));
    }
    final search=tv.substring(tv.indexOf('class _TvSearchResultsDialogState'),tv.indexOf('class _TvChannelButton'));
    expect(search,isNot(contains('pop(channel)')));
    expect(search,isNot(contains('Navigator.of(context).pop();')));
  });
}
