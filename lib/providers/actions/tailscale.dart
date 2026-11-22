part of '../action.dart';

class TailscaleData {
  final Map<String, TailscaleNetworkStatus> statuses;
  final Set<String> busy;
  final bool available;

  const TailscaleData({
    this.statuses = const {},
    this.busy = const {},
    this.available = false,
  });

  TailscaleData copyWith({
    Map<String, TailscaleNetworkStatus>? statuses,
    Set<String>? busy,
    bool? available,
  }) {
    return TailscaleData(
      statuses: statuses ?? this.statuses,
      busy: busy ?? this.busy,
      available: available ?? this.available,
    );
  }
}

@Riverpod(keepAlive: true)
class TailscaleAction extends _$TailscaleAction {
  CoreController get _core => ref.read(coreHandlerProvider);

  List<TailscaleNetwork> get _networks => ref.read(tailscaleNetworksProvider);

  @override
  TailscaleData build() => const TailscaleData();

  Future<List<Map<String, Object?>>> _payload() async {
    final networks = _networks;
    return [
      for (final network in networks)
        {
          'id': network.id,
          'name': network.name,
          'hostname': network.hostname,
          'control-url': network.controlUrl,
          'auth-key': network.loginMethod == TailscaleLoginMethod.authKey
              ? await preferences.getTailscaleAuthKey(network.id) ?? ''
              : '',
          'login-method': switch (network.loginMethod) {
            TailscaleLoginMethod.authKey => 'auth-key',
            TailscaleLoginMethod.interactive => 'interactive',
          },
          'exit-node': network.exitNode,
          'accept-routes': network.acceptRoutes,
          'exit-node-allow-lan-access': network.exitNodeAllowLanAccess,
        },
    ];
  }

  Future<void> push() async {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    try {
      await _core.applyTailscale(await _payload());
    } catch (error) {
      commonPrint.log(
        'tailscale.apply failed: $error',
        logLevel: coreFailureLogLevel(error),
      );
    }
  }

  Future<void> apply() async {
    await push();
    await refresh();
  }

  Future<void> refresh() async {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      if (state.available) {
        state = state.copyWith(available: false);
      }
      return;
    }
    try {
      final statuses = await _core.getTailscaleStatus();
      state = state.copyWith(
        available: true,
        statuses: {for (final status in statuses) status.id: status},
      );
    } catch (error) {
      commonPrint.log(
        'tailscale.status failed: $error',
        logLevel: coreFailureLogLevel(error),
      );
      state = state.copyWith(available: false);
    }
  }

  Future<void> saveNetwork(TailscaleNetwork network, {String? authKey}) async {
    if (authKey != null) {
      await preferences.saveTailscaleAuthKey(network.id, authKey);
    }
    ref.read(tailscaleNetworksProvider.notifier).update((networks) {
      final exists = networks.any((item) => item.id == network.id);
      if (!exists) {
        return [...networks, network];
      }
      return [
        for (final item in networks) item.id == network.id ? network : item,
      ];
    });
    await push();
    await _applyConfig();
    await refresh();
  }

  // The proxies, rules and DNS reach the Core through the config, not the payload.
  Future<void> _applyConfig() async {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    final applied = await ref
        .read(setupActionProvider.notifier)
        .applyProfile(force: true, silence: true);
    if (!applied) {
      commonPrint.log(
        'tailscale config apply did not complete',
        logLevel: LogLevel.warning,
      );
    }
  }

  Future<void> login(String id) async {
    await _run(id, () async {
      await _core.loginTailscale(id);
      await refresh();
    });
  }

  Future<void> logout(String id) async {
    await _run(id, () async {
      await _core.logoutTailscale(id);
      await preferences.saveTailscaleAuthKey(id, null);
      await push();
      await refresh();
    });
  }

  Future<void> forget(TailscaleNetwork network) async {
    await _run(network.id, () async {
      await _core.forgetTailscale(network.id);
      await preferences.saveTailscaleAuthKey(network.id, null);
    });
    ref.read(tailscaleNetworksProvider.notifier).update((networks) {
      return networks.where((item) => item.id != network.id).toList();
    });
    final statuses = {...state.statuses}..remove(network.id);
    state = state.copyWith(statuses: statuses);
    await push();
    await _applyConfig();
  }

  Future<TailscaleCheck> check(String id) {
    return _run(id, () => _core.checkTailscale(id));
  }

  Future<T> _run<T>(String id, Future<T> Function() run) async {
    state = state.copyWith(busy: {...state.busy, id});
    try {
      return await run();
    } catch (error) {
      commonPrint.log(
        'tailscale action for $id failed: $error',
        logLevel: coreFailureLogLevel(error),
      );
      rethrow;
    } finally {
      state = state.copyWith(busy: {...state.busy}..remove(id));
    }
  }
}
