import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_cast/dart_cast.dart';
// Diagnostic transport only: this does not validate Google device credentials.
import 'package:dart_cast/src/protocols/chromecast/castv2_channel.dart';
import 'package:multicast_dns/multicast_dns.dart';

const receiver = 'urn:x-cast:com.google.cast.receiver';
const media = 'urn:x-cast:com.google.cast.media';
const connection = 'urn:x-cast:com.google.cast.tp.connection';
const heartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';

Future<CastDevice> discover(String name) async {
  final client = MDnsClient(
    rawDatagramSocketFactory:
        (host, port, {reuseAddress = true, reusePort = true, ttl = 255}) =>
            RawDatagramSocket.bind(
              host,
              port,
              reuseAddress: reuseAddress,
              reusePort: Platform.isWindows ? false : reusePort,
              ttl: ttl,
            ),
  );
  try {
    await client.start(
      interfacesFactory: (type) async {
        final interfaces = await NetworkInterface.list(type: type);
        final selected = Platform.environment['CAST_INTERFACE'];
        return interfaces.where(
          (i) => selected != null
              ? i.name == selected
              : i.addresses.any(
                  (a) => !a.isLoopback && !a.address.startsWith('169.254.'),
                ),
        );
      },
      onError: (Object error) => stderr.writeln('mDNS warning: $error'),
    );
    await for (final ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer('_googlecast._tcp.local'),
      timeout: const Duration(seconds: 18),
    )) {
      final txt = await client
          .lookup<TxtResourceRecord>(ResourceRecordQuery.text(ptr.domainName))
          .first;
      final metadata = <String, String>{};
      for (final line in txt.text.split('\n')) {
        final index = line.indexOf('=');
        if (index > 0)
          metadata[line.substring(0, index)] = line.substring(index + 1).trim();
      }
      if (metadata['fn'] != name) continue;
      final srv = await client
          .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          )
          .first;
      final ip = await client
          .lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )
          .first;
      return CastDevice(
        id: metadata['id'] ?? ptr.domainName,
        name: name,
        protocol: CastProtocol.chromecast,
        address: ip.address,
        port: srv.port,
      );
    }
    throw StateError('Device "$name" not discovered');
  } finally {
    client.stop();
  }
}

Future<void> main(List<String> args) async {
  final name = args.isEmpty ? 'Sonarpad-Test' : args[0];
  var url = args.length > 1
      ? args[1]
      : 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
  final mime = args.length > 2 ? args[2] : 'audio/mpeg';
  final channel = CastV2Channel();
  MediaProxy? proxy;
  StreamSubscription<dynamic>? subscription;
  Timer? ping;
  final pending = <int, Completer<Map<String, dynamic>>>{};
  var sequence = 0;
  String? transport;
  int? session;
  void send(String ns, String destination, Map<String, dynamic> payload) {
    channel.sendMessage(
      namespace: ns,
      sourceId: 'sender-sonarpad-probe',
      destinationId: destination,
      payload: jsonEncode(payload),
    );
  }

  Future<Map<String, dynamic>> request(
    String ns,
    String destination,
    Map<String, dynamic> payload,
  ) async {
    final id = ++sequence;
    final result = Completer<Map<String, dynamic>>();
    pending[id] = result;
    try {
      send(ns, destination, {...payload, 'requestId': id});
      final reply = await result.future.timeout(const Duration(seconds: 12));
      if ([
        'INVALID_REQUEST',
        'LOAD_FAILED',
        'LAUNCH_ERROR',
      ].contains(reply['type'])) {
        throw StateError('Receiver rejected ${payload['type']}: $reply');
      }
      return reply;
    } finally {
      pending.remove(id);
    }
  }

  Future<Map<String, dynamic>> status() async {
    final reply = await request(media, transport!, {'type': 'GET_STATUS'});
    final entries = reply['status'] as List? ?? [];
    if (entries.isEmpty) throw StateError('No media session reported');
    final value = Map<String, dynamic>.from(entries.first as Map);
    session = value['mediaSessionId'] as int;
    return value;
  }

  Future<Map<String, dynamic>> waitFor(
    String? state, {
    double? position,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 35));
    Map<String, dynamic> value = {};
    do {
      value = await status();
      final time = (value['currentTime'] as num?)?.toDouble() ?? 0;
      if ((state == null || value['playerState'] == state) &&
          (position == null || (time - position).abs() <= 5)) {
        print(
          'PASS state=${value['playerState']} position=${time.toStringAsFixed(1)}s',
        );
        return value;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    } while (DateTime.now().isBefore(deadline));
    throw StateError(
      'Expected $state at $position; received '
      '${value['playerState']} at ${value['currentTime']} (${value['idleReason']})',
    );
  }

  try {
    print('Discovering "$name" via Dart mDNS...');
    final device = await discover(name);
    print(
      'PASS discovery: ${device.name} ${device.address.address}:${device.port}',
    );
    if (File(url).existsSync()) {
      proxy = MediaProxy();
      await proxy.start(targetDeviceIp: device.address.address);
      url = proxy.registerFile(File(url).absolute.path);
    }
    await channel.connect(device.address.address, port: device.port);
    subscription = channel.messageStream.listen(
      (message) {
        if (message.payloadUtf8.isEmpty) return;
        final payload = jsonDecode(message.payloadUtf8) as Map<String, dynamic>;
        if (message.namespace_ == heartbeat && payload['type'] == 'PING') {
          send(heartbeat, message.sourceId, {'type': 'PONG'});
        }
        final waiter = pending[payload['requestId']];
        if (waiter != null && !waiter.isCompleted) waiter.complete(payload);
      },
      onError: (Object error, StackTrace stack) {
        for (final waiter in pending.values) {
          if (!waiter.isCompleted) waiter.completeError(error, stack);
        }
      },
    );
    send(connection, 'receiver-0', {'type': 'CONNECT'});
    ping = Timer.periodic(const Duration(seconds: 5), (_) {
      send(heartbeat, 'receiver-0', {'type': 'PING'});
    });
    final launched = await request(receiver, 'receiver-0', {
      'type': 'LAUNCH',
      'appId': 'CC1AD845',
    });
    final applications = launched['status']['applications'] as List;
    final app = applications.firstWhere((a) => a['appId'] == 'CC1AD845');
    transport = app['transportId'] as String;
    send(connection, transport, {'type': 'CONNECT'});
    print('PASS receiver launch');
    await request(media, transport, {
      'type': 'LOAD',
      'autoplay': true,
      'currentTime': 0,
      'media': {
        'contentId': url,
        'contentType': mime,
        'streamType': 'BUFFERED',
        'metadata': {'metadataType': 0, 'title': 'Sonarpad Dart Cast test'},
      },
    });
    await waitFor('PLAYING', position: 7);
    await request(media, transport, {
      'type': 'PAUSE',
      'mediaSessionId': session,
    });
    await waitFor('PAUSED');
    await request(media, transport, {
      'type': 'SEEK',
      'mediaSessionId': session,
      'currentTime': 30,
      'resumeState': 'PLAYBACK_PAUSE',
    });
    final sought = await waitFor(null, position: 30);
    if (sought['playerState'] != 'PAUSED') {
      print(
        'LIMITATION: receiver reports ${sought['playerState']} after paused SEEK.',
      );
    }
    await request(media, transport, {
      'type': 'PLAY',
      'mediaSessionId': session,
    });
    await waitFor('PLAYING', position: 30);
    await Future<void>.delayed(const Duration(seconds: 3));
    final advanced = await status();
    if ((advanced['currentTime'] as num) <= 30) {
      throw StateError('Playback position did not advance');
    }
    print('PASS playback clock advanced: ${advanced['currentTime']}s');
    await request(media, transport, {
      'type': 'STOP',
      'mediaSessionId': session,
    });
    await waitFor('IDLE');
    print(
      'PASS ALL: discovery, launch, load, pause, seek, resume, progress, stop',
    );
  } catch (error, stack) {
    stderr.writeln('FAIL: $error\n$stack');
    exitCode = 1;
  } finally {
    ping?.cancel();
    await proxy?.stop();
    if (transport != null && session != null) {
      try {
        await request(media, transport, {
          'type': 'STOP',
          'mediaSessionId': session,
        });
      } catch (_) {
        /* Best effort cleanup after a failed probe. */
      }
    }
    try {
      await subscription?.cancel().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      stderr.writeln('Subscription cleanup timeout.');
    }
    try {
      await channel.close().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      stderr.writeln('Transport close timeout; exiting probe.');
    }
  }
  // Standalone CLI: terminate any remaining third-party transport handles.
  exit(exitCode);
}
