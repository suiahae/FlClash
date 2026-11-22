import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/tailscale.freezed.dart';
part 'generated/tailscale.g.dart';

const defaultTailscaleControlUrl = 'https://controlplane.tailscale.com';

enum TailscaleLoginMethod {
  @JsonValue('auth-key')
  authKey,
  @JsonValue('interactive')
  interactive,
}

enum TailscaleState {
  stopped('stopped'),
  starting('starting'),
  needsLogin('needs-login'),
  needsApproval('needs-approval'),
  running('running'),
  error('error'),
  unknown('unknown');

  final String wire;

  const TailscaleState(this.wire);

  static TailscaleState fromWire(String? value) {
    return values.firstWhere(
      (state) => state.wire == value,
      orElse: () => unknown,
    );
  }

  bool get isActive => this == starting || this == running;

  bool get needsAttention => this == needsLogin || this == needsApproval;
}

enum TailscaleCheckCode {
  healthy('healthy'),
  notApplied('not-applied'),
  unavailable('unavailable'),
  offline('offline'),
  exitNodeUnset('exit-node-unset'),
  stopped('stopped'),
  starting('starting'),
  needsLogin('needs-login'),
  needsApproval('needs-approval'),
  error('error'),
  unknown('unknown');

  final String wire;

  const TailscaleCheckCode(this.wire);

  static TailscaleCheckCode fromWire(String? value) {
    return values.firstWhere(
      (code) => code.wire == value,
      orElse: () => unknown,
    );
  }
}

@freezed
abstract class TailscaleNetwork with _$TailscaleNetwork {
  const factory TailscaleNetwork({
    required String id,
    required String name,
    @Default('') String hostname,
    @Default(defaultTailscaleControlUrl) String controlUrl,
    @Default(TailscaleLoginMethod.authKey) TailscaleLoginMethod loginMethod,
    @Default('') String exitNode,
    @Default(false) bool acceptRoutes,
    @Default(false) bool exitNodeAllowLanAccess,
  }) = _TailscaleNetwork;

  factory TailscaleNetwork.fromJson(Map<String, Object?> json) =>
      _$TailscaleNetworkFromJson(json);
}

class TailscaleDevice {
  final String id;
  final String name;
  final String hostname;
  final String os;
  final List<String> ips;
  final bool online;
  final bool direct;
  final String relay;
  final bool exitNode;
  final bool exitNodeOption;

  const TailscaleDevice({
    required this.id,
    required this.name,
    required this.hostname,
    required this.os,
    required this.ips,
    required this.online,
    required this.direct,
    required this.relay,
    required this.exitNode,
    required this.exitNodeOption,
  });

  factory TailscaleDevice.fromJson(Map<String, Object?> json) {
    return TailscaleDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      hostname: json['hostname'] as String? ?? '',
      os: json['os'] as String? ?? '',
      ips: [for (final ip in json['ips'] as List? ?? const []) ip as String],
      online: json['online'] as bool? ?? false,
      direct: json['direct'] as bool? ?? false,
      relay: json['relay'] as String? ?? '',
      exitNode: json['exit-node'] as bool? ?? false,
      exitNodeOption: json['exit-node-option'] as bool? ?? false,
    );
  }

  String? get preferredIp => ips.isEmpty ? null : ips.first;
}

class TailscaleNetworkStatus {
  final String id;
  final TailscaleState state;
  final String rawState;
  final TailscaleLoginMethod loginMethod;
  final String authUrl;
  final String error;
  final List<String> health;
  final String account;
  final String tailnet;
  final String hostname;
  final String exitNode;
  final String exitNodeActive;
  final bool acceptRoutes;
  final bool exitNodeAllowLanAccess;
  final bool online;
  final TailscaleDevice? self;
  final List<TailscaleDevice> devices;
  final List<TailscaleDevice> exitNodes;

  const TailscaleNetworkStatus({
    required this.id,
    required this.state,
    required this.rawState,
    required this.loginMethod,
    required this.authUrl,
    required this.error,
    required this.health,
    required this.account,
    required this.tailnet,
    required this.hostname,
    required this.exitNode,
    required this.exitNodeActive,
    required this.acceptRoutes,
    required this.exitNodeAllowLanAccess,
    required this.online,
    required this.self,
    required this.devices,
    required this.exitNodes,
  });

  factory TailscaleNetworkStatus.fromJson(Map<String, Object?> json) {
    final self = json['self'];
    return TailscaleNetworkStatus(
      id: json['id'] as String? ?? '',
      state: TailscaleState.fromWire(json['state'] as String?),
      rawState: json['raw-state'] as String? ?? '',
      loginMethod: switch (json['login-method']) {
        'interactive' => TailscaleLoginMethod.interactive,
        _ => TailscaleLoginMethod.authKey,
      },
      authUrl: json['auth-url'] as String? ?? '',
      error: json['error'] as String? ?? '',
      health: [
        for (final item in json['health'] as List? ?? const []) item as String,
      ],
      account: json['account'] as String? ?? '',
      tailnet: json['tailnet'] as String? ?? '',
      hostname: json['hostname'] as String? ?? '',
      exitNode: json['exit-node'] as String? ?? '',
      exitNodeActive: json['exit-node-active'] as String? ?? '',
      acceptRoutes: json['accept-routes'] as bool? ?? false,
      exitNodeAllowLanAccess:
          json['exit-node-allow-lan-access'] as bool? ?? false,
      online: json['online'] as bool? ?? false,
      self: self is Map
          ? TailscaleDevice.fromJson(Map<String, Object?>.from(self))
          : null,
      devices: [
        for (final device in json['devices'] as List? ?? const [])
          TailscaleDevice.fromJson(Map<String, Object?>.from(device as Map)),
      ],
      exitNodes: [
        for (final device in json['exit-nodes'] as List? ?? const [])
          TailscaleDevice.fromJson(Map<String, Object?>.from(device as Map)),
      ],
    );
  }

  bool get isSignedIn => self != null && state != TailscaleState.needsLogin;

  TailscaleDevice? get selfOnline => self?.online == true ? self : null;
}

class TailscaleCheck {
  final TailscaleCheckCode code;
  final String message;
  final int delay;
  final int peers;
  final int onlinePeers;

  const TailscaleCheck({
    required this.code,
    required this.message,
    required this.delay,
    required this.peers,
    required this.onlinePeers,
  });

  factory TailscaleCheck.fromJson(Map<String, Object?> json) {
    return TailscaleCheck(
      code: TailscaleCheckCode.fromWire(json['code'] as String?),
      message: json['message'] as String? ?? '',
      delay: (json['delay'] as num?)?.toInt() ?? 0,
      peers: (json['peers'] as num?)?.toInt() ?? 0,
      onlinePeers: (json['online-peers'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isHealthy => code == TailscaleCheckCode.healthy;
}
