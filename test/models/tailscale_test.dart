import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

Map<String, Object?> _device({
  String id = 'n1',
  String name = 'laptop',
  List<String> ips = const ['100.64.0.2'],
  bool online = true,
  bool direct = true,
  bool exitNodeOption = false,
}) {
  return {
    'id': id,
    'name': name,
    'hostname': name,
    'os': 'linux',
    'ips': ips,
    'online': online,
    'direct': direct,
    'relay': direct ? '' : 'hkg',
    'exit-node': false,
    'exit-node-option': exitNodeOption,
  };
}

void main() {
  group('TailscaleState', () {
    test('maps every wire state the core writes', () {
      expect(TailscaleState.fromWire('stopped'), TailscaleState.stopped);
      expect(TailscaleState.fromWire('starting'), TailscaleState.starting);
      expect(TailscaleState.fromWire('needs-login'), TailscaleState.needsLogin);
      expect(
        TailscaleState.fromWire('needs-approval'),
        TailscaleState.needsApproval,
      );
      expect(TailscaleState.fromWire('running'), TailscaleState.running);
      expect(TailscaleState.fromWire('error'), TailscaleState.error);
    });

    test('falls back to unknown', () {
      expect(TailscaleState.fromWire(null), TailscaleState.unknown);
      expect(TailscaleState.fromWire('NoState'), TailscaleState.unknown);
    });
  });

  group('TailscaleNetwork', () {
    test('round-trips through JSON with the wire enum values', () {
      const network = TailscaleNetwork(
        id: 'home',
        name: 'Home',
        hostname: 'phone',
        controlUrl: 'https://hs.example.com',
        loginMethod: TailscaleLoginMethod.interactive,
        exitNode: 'n2',
        acceptRoutes: true,
        exitNodeAllowLanAccess: true,
      );
      final json = network.toJson();
      expect(json['loginMethod'], 'interactive');
      expect(TailscaleNetwork.fromJson(json), network);
    });

    test('defaults an auth-key network with the public control URL', () {
      final network = TailscaleNetwork.fromJson({'id': 'a', 'name': 'A'});
      expect(network.loginMethod, TailscaleLoginMethod.authKey);
      expect(network.controlUrl, defaultTailscaleControlUrl);
      expect(network.exitNode, isEmpty);
      expect(network.acceptRoutes, isFalse);
    });
  });

  group('TailscaleNetworkStatus', () {
    test('decodes the fields the page shows', () {
      final status = TailscaleNetworkStatus.fromJson({
        'id': 'home',
        'state': 'running',
        'raw-state': 'Running',
        'login-method': 'interactive',
        'auth-url': '',
        'account': 'me@example.com',
        'tailnet': 'example.com',
        'hostname': 'phone',
        'exit-node': '',
        'accept-routes': true,
        'exit-node-allow-lan-access': false,
        'online': true,
        'self': _device(id: 'self', name: 'phone'),
        'devices': [_device(id: 'n2', name: 'router', exitNodeOption: true)],
        'exit-nodes': [_device(id: 'n2', name: 'router', exitNodeOption: true)],
      });
      expect(status.state, TailscaleState.running);
      expect(status.loginMethod, TailscaleLoginMethod.interactive);
      expect(status.self?.name, 'phone');
      expect(status.devices.single.name, 'router');
      expect(status.exitNodes.single.exitNodeOption, isTrue);
      expect(status.selfOnline, isNotNull);
      expect(status.isSignedIn, isTrue);
      expect(status.acceptRoutes, isTrue);
    });

    test(
      'a network the core has not reported is neither signed in nor online',
      () {
        final status = TailscaleNetworkStatus.fromJson({
          'id': 'home',
          'state': 'needs-login',
        });
        expect(status.state, TailscaleState.needsLogin);
        expect(status.self, isNull);
        expect(status.selfOnline, isNull);
        expect(status.devices, isEmpty);
        expect(status.isSignedIn, isFalse);
      },
    );
  });

  group('TailscaleCheck', () {
    test('decodes a healthy answer', () {
      final check = TailscaleCheck.fromJson({
        'code': 'healthy',
        'delay': 42,
        'peers': 3,
        'online-peers': 2,
      });
      expect(check.code, TailscaleCheckCode.healthy);
      expect(check.isHealthy, isTrue);
      expect(check.delay, 42);
      expect(check.onlinePeers, 2);
    });

    test('keeps the core message of an unavailable check', () {
      final check = TailscaleCheck.fromJson({
        'code': 'unavailable',
        'message': 'dial tcp: i/o timeout',
      });
      expect(check.code, TailscaleCheckCode.unavailable);
      expect(check.message, 'dial tcp: i/o timeout');
      expect(check.isHealthy, isFalse);
    });
  });
}
