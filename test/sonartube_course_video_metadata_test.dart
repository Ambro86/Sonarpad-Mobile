import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';

void main() {
  test('direct course playlist keeps videos with avatar and a single metadata row', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'www.youtube.com');
      return http.Response(jsonEncode({
        'contents': {'playlistVideoListRenderer': {'contents': [{
          'lockupViewModel': {
            'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO', 'contentId': 'abcdefghijk',
            'metadata': {'lockupMetadataViewModel': {
              'title': {'content': 'Lesson'},
              'image': {'decoratedAvatarViewModel': <String, dynamic>{}},
              'metadata': {'contentMetadataViewModel': {'metadataRows': [{
                'metadataParts': [
                  {'text': {'content': '154K views'}},
                  {'text': {'content': '6 years ago'}},
                ],
              }]}},
            }},
          },
        }]}},
      }), 200);
    });
    addTearDown(client.close);
    final service = SonarTubeService(client: client);
    final page = await service.browse(const SonarTubeItem(
      kind: SonarTubeItemKind.playlist, id: 'PLcourse001', title: 'Course',
      url: 'https://www.youtube.com/playlist?list=PLcourse001',
    ));
    expect(page.items.single.views, '154K views');
    expect(page.items.single.channel, isNull);
  });
}
