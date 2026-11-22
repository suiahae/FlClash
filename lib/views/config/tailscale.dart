import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _stateLabel(
  AppLocalizations appLocalizations,
  TailscaleNetworkStatus? status,
) {
  if (status == null) {
    return appLocalizations.tailscaleNotApplied;
  }
  if (status.state == TailscaleState.running && !status.online) {
    return appLocalizations.tailscaleOffline;
  }
  return switch (status.state) {
    TailscaleState.running => appLocalizations.tailscaleConnected,
    TailscaleState.starting => appLocalizations.tailscaleConnecting,
    TailscaleState.needsLogin => appLocalizations.tailscaleNeedsLogin,
    TailscaleState.needsApproval => appLocalizations.tailscaleNeedsApproval,
    TailscaleState.stopped => appLocalizations.tailscaleStopped,
    TailscaleState.error => appLocalizations.tailscaleUnavailable,
    TailscaleState.unknown => appLocalizations.tailscaleStopped,
  };
}

TonalChip _stateChip(
  BuildContext context,
  AppLocalizations appLocalizations,
  TailscaleNetworkStatus? status,
) {
  final colorScheme = context.colorScheme;
  final (background, foreground) = switch (status?.state) {
    null => (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
    TailscaleState.running when status!.online => (
      colorScheme.successContainer,
      colorScheme.onSuccessContainer,
    ),
    TailscaleState.running => (
      colorScheme.warningContainer,
      colorScheme.onWarningContainer,
    ),
    TailscaleState.starting ||
    TailscaleState.needsLogin ||
    TailscaleState.needsApproval => (
      colorScheme.warningContainer,
      colorScheme.onWarningContainer,
    ),
    TailscaleState.error => (
      colorScheme.errorContainer,
      colorScheme.onErrorContainer,
    ),
    _ => (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
  };
  return TonalChip(
    label: _stateLabel(appLocalizations, status),
    color: background,
    foregroundColor: foreground,
  );
}

String _connectionLabel(
  AppLocalizations appLocalizations,
  TailscaleDevice device,
) {
  return device.direct
      ? appLocalizations.tailscaleDirect
      : appLocalizations.tailscaleRelay;
}

String _checkMessage(AppLocalizations appLocalizations, TailscaleCheck check) {
  return switch (check.code) {
    TailscaleCheckCode.healthy => appLocalizations.tailscaleCheckHealthy(
      check.delay,
    ),
    TailscaleCheckCode.notApplied => appLocalizations.tailscaleCheckNotApplied,
    TailscaleCheckCode.unavailable =>
      check.message.isEmpty
          ? appLocalizations.tailscaleCheckUnavailable
          : check.message,
    TailscaleCheckCode.offline => appLocalizations.tailscaleCheckOffline,
    TailscaleCheckCode.exitNodeUnset =>
      appLocalizations.tailscaleCheckExitNodeUnset,
    TailscaleCheckCode.needsLogin => appLocalizations.tailscaleCheckNeedsLogin,
    TailscaleCheckCode.needsApproval =>
      appLocalizations.tailscaleCheckNeedsApproval,
    _ => appLocalizations.tailscaleCheckUnavailable,
  };
}

class TailscaleView extends ConsumerStatefulWidget {
  const TailscaleView({super.key});

  @override
  ConsumerState<TailscaleView> createState() => _TailscaleViewState();
}

class _TailscaleViewState extends ConsumerState<TailscaleView>
    with WidgetsBindingObserver, ActivePollingMixin<TailscaleView> {
  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  Future<void> poll(PollGuard isCurrent) async {
    await ref.read(tailscaleActionProvider.notifier).refresh();
  }

  Future<void> _handleAdd() async {
    await showFormSheet<void>(
      context: context,
      builder: (_) => const _TailscaleNetworkForm(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final networks = ref.watch(tailscaleNetworksProvider);
    final data = ref.watch(tailscaleActionProvider);
    return Scaffold(
      title: appLocalizations.tailscale,
      iconActions: [
        if (networks.isNotEmpty)
          IconButtonData(
            glyph: AppGlyphs.add,
            tooltip: appLocalizations.tailscaleAddNetwork,
            onPressed: _handleAdd,
          ),
      ],
      body: networks.isEmpty
          ? NullStatus(
              label: appLocalizations.tailscaleEmptyTitle,
              description: appLocalizations.tailscaleEmptyDesc,
              illustration: NullStatusIllustration.tailscale,
              action: TonalButton(
                size: TonalButtonSize.bar,
                glyph: AppGlyphs.add,
                label: appLocalizations.tailscaleAddNetwork,
                onPressed: _handleAdd,
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
                top: context.sectionsTopPadding,
                bottom: 20 + context.bottomInset,
              ),
              children: [
                ErrorBanner(
                  message: data.available
                      ? null
                      : appLocalizations.tailscaleUnavailableHint,
                ),
                generateSection(
                  title: appLocalizations.tailscaleNetworks,
                  footer: appLocalizations.tailscaleCredentialsFooter,
                  items: [
                    for (final network in networks)
                      ListItem.open(
                        leading: const GlyphIcon(AppGlyphs.link),
                        title: Text(network.name),
                        trailing: _stateChip(
                          context,
                          appLocalizations,
                          data.statuses[network.id],
                        ),
                        widget: TailscaleNetworkView(networkId: network.id),
                      ),
                  ],
                ),
                const _TailscaleGuideSection(),
              ],
            ),
    );
  }
}

class _TailscaleGuideSection extends StatelessWidget {
  const _TailscaleGuideSection();

  void _show({required String title, required String body}) {
    dialogs.showAlert(
      title: title,
      message: TextSpan(text: body),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final entries = [
      (
        appLocalizations.tailscaleGuideGetStarted,
        appLocalizations.tailscaleGuideGetStartedBody,
      ),
      (
        appLocalizations.tailscaleGuideSignIn,
        appLocalizations.tailscaleGuideSignInBody,
      ),
      (
        appLocalizations.tailscaleGuideDevices,
        appLocalizations.tailscaleGuideDevicesBody,
      ),
      (
        appLocalizations.tailscaleGuideExitNodes,
        appLocalizations.tailscaleGuideExitNodesBody,
      ),
      (
        appLocalizations.tailscaleGuideTroubleshooting,
        appLocalizations.tailscaleGuideTroubleshootingBody,
      ),
    ];
    return generateSection(
      title: appLocalizations.tailscaleGuide,
      items: [
        for (final entry in entries)
          ListItem(
            leading: const GlyphIcon(AppGlyphs.info),
            title: Text(entry.$1),
            onTap: () => _show(title: entry.$1, body: entry.$2),
          ),
      ],
    );
  }
}

class TailscaleNetworkView extends ConsumerStatefulWidget {
  const TailscaleNetworkView({super.key, required this.networkId});

  final String networkId;

  @override
  ConsumerState<TailscaleNetworkView> createState() =>
      _TailscaleNetworkViewState();
}

class _TailscaleNetworkViewState extends ConsumerState<TailscaleNetworkView>
    with WidgetsBindingObserver, ActivePollingMixin<TailscaleNetworkView> {
  DateTime? _loginStartedAt;

  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  Future<void> poll(PollGuard isCurrent) async {
    await ref.read(tailscaleActionProvider.notifier).refresh();
    if (!isCurrent() || !mounted || _loginStartedAt == null) {
      return;
    }
    final status = ref.read(tailscaleActionProvider).statuses[widget.networkId];
    if (status?.state != TailscaleState.needsLogin) {
      setState(() {
        _loginStartedAt = null;
      });
    }
  }

  Future<void> _handleEdit(TailscaleNetwork network) async {
    await showFormSheet<void>(
      context: context,
      builder: (_) => _TailscaleNetworkForm(network: network),
    );
  }

  Future<void> _handleSaveNetwork(TailscaleNetwork network) async {
    await ref.read(tailscaleActionProvider.notifier).saveNetwork(network);
  }

  Future<void> _handleLogin(TailscaleNetwork network) async {
    setState(() {
      _loginStartedAt = DateTime.now();
    });
    try {
      await ref.read(tailscaleActionProvider.notifier).login(network.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      await dialogs.showAlert(
        message: TextSpan(
          text: userFacingErrorMessage(error, context.appLocalizations),
        ),
      );
    }
  }

  Future<void> _handleLogout(TailscaleNetwork network) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      message: TextSpan(text: appLocalizations.tailscaleLogoutConfirm),
      destructive: true,
      confirmText: appLocalizations.tailscaleLogout,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref.read(tailscaleActionProvider.notifier).logout(network.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      await dialogs.showAlert(
        message: TextSpan(
          text: userFacingErrorMessage(error, appLocalizations),
        ),
      );
    }
  }

  Future<void> _handleCheck(TailscaleNetwork network) async {
    final appLocalizations = context.appLocalizations;
    try {
      final check = await ref
          .read(tailscaleActionProvider.notifier)
          .check(network.id);
      if (!mounted) {
        return;
      }
      await dialogs.showAlert(
        message: TextSpan(text: _checkMessage(appLocalizations, check)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await dialogs.showAlert(
        message: TextSpan(
          text: userFacingErrorMessage(error, appLocalizations),
        ),
      );
    }
  }

  Future<void> _handleRemove(TailscaleNetwork network) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      message: TextSpan(
        text: appLocalizations.tailscaleRemoveConfirm(network.name),
      ),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref.read(tailscaleActionProvider.notifier).forget(network);
    } catch (error) {
      if (!mounted) {
        return;
      }
      await dialogs.showAlert(
        message: TextSpan(
          text: userFacingErrorMessage(error, appLocalizations),
        ),
      );
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleCopy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      dialogs.showBanner(currentAppLocalizations.copySuccess);
    }
  }

  Widget _buildStatusSection(
    AppLocalizations appLocalizations,
    TailscaleNetwork network,
    TailscaleNetworkStatus? status,
    TailscaleData data,
  ) {
    final busy = data.busy.contains(network.id);
    final needsLogin = status?.state == TailscaleState.needsLogin;
    final interactive = network.loginMethod == TailscaleLoginMethod.interactive;
    final timedOut =
        needsLogin &&
        interactive &&
        _loginStartedAt != null &&
        DateTime.now().difference(_loginStartedAt!) >=
            const Duration(minutes: 1);
    return generateSection(
      title: appLocalizations.tailscaleStatus,
      items: [
        ListItem(
          title: Text(appLocalizations.tailscaleConnection),
          trailing: _stateChip(context, appLocalizations, status),
        ),
        if (status != null && status.error.isNotEmpty)
          ListItem(
            leading: GlyphIcon(
              AppGlyphs.warning,
              color: context.colorScheme.error,
            ),
            title: Text(
              status.error,
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        if (needsLogin && !interactive)
          ListItem(
            leading: const GlyphIcon(AppGlyphs.key),
            title: Text(appLocalizations.tailscaleAuthKeyInvalid),
            subtitle: Text(appLocalizations.tailscaleKeyExpired),
          ),
        if (needsLogin && interactive)
          ListItem(
            leading: const GlyphIcon(AppGlyphs.openExternal),
            title: Text(
              status != null && status.authUrl.isNotEmpty
                  ? appLocalizations.tailscaleOpenLoginPage
                  : appLocalizations.tailscaleSigningIn,
            ),
            subtitle: Text(
              timedOut
                  ? appLocalizations.tailscaleLoginTimeout
                  : appLocalizations.tailscaleLoginWaiting,
            ),
            trailing: busy ? const ActivityIndicator(size: 16) : null,
            onTap: status != null && status.authUrl.isNotEmpty
                ? () => dialogs.openUrl(status.authUrl)
                : busy
                ? null
                : () => _handleLogin(network),
          ),
        if (status?.state == TailscaleState.needsApproval)
          ListItem(
            leading: const GlyphIcon(AppGlyphs.info),
            title: Text(appLocalizations.tailscaleNeedsApproval),
            subtitle: Text(appLocalizations.tailscaleCheckNeedsApproval),
          ),
        if (!interactive && needsLogin && !busy)
          ListItem(
            leading: const GlyphIcon(AppGlyphs.edit),
            title: Text(appLocalizations.tailscaleEnterAuthKey),
            onTap: () => _handleEdit(network),
          ),
      ],
    );
  }

  Widget _buildDeviceSection(
    AppLocalizations appLocalizations,
    TailscaleNetworkStatus? status,
  ) {
    final self = status?.self;
    final items = <Widget>[
      if (self != null)
        ListItem(
          leading: const GlyphIcon(AppGlyphs.target),
          title: Text(self.name),
          subtitle: self.ips.isEmpty ? null : Text(self.ips.join(', ')),
          trailing: TonalChip(
            label: self.online
                ? appLocalizations.tailscaleOnline
                : appLocalizations.tailscaleOffline,
            color: self.online
                ? context.colorScheme.successContainer
                : context.colorScheme.surfaceContainerHighest,
            foregroundColor: self.online
                ? context.colorScheme.onSuccessContainer
                : context.colorScheme.onSurfaceVariant,
          ),
          onTap: self.ips.isEmpty
              ? null
              : () => _handleCopy(self.ips.join(', ')),
        ),
      if (status != null && status.account.isNotEmpty)
        ListItem(
          leading: const GlyphIcon(AppGlyphs.profiles),
          title: Text(appLocalizations.tailscaleAccount),
          subtitle: Text(status.account),
        ),
      if (status != null && status.tailnet.isNotEmpty)
        ListItem(
          leading: const GlyphIcon(AppGlyphs.link),
          title: Text(appLocalizations.tailscaleTailnet),
          subtitle: Text(status.tailnet),
        ),
    ];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return generateSection(
      title: appLocalizations.tailscaleThisDevice,
      items: items,
    );
  }

  Widget _buildAdvancedSection(
    AppLocalizations appLocalizations,
    TailscaleNetwork network,
    TailscaleNetworkStatus? status,
  ) {
    final exitNodes = status?.exitNodes ?? const <TailscaleDevice>[];
    final byId = {for (final device in exitNodes) device.id: device};
    final options = <String>[
      '',
      'auto',
      for (final device in exitNodes) device.id,
      if (network.exitNode.isNotEmpty &&
          network.exitNode != 'auto' &&
          !byId.containsKey(network.exitNode))
        network.exitNode,
    ];
    String labelOf(String value) {
      return switch (value) {
        '' => appLocalizations.tailscaleExitNodeNone,
        'auto' => appLocalizations.tailscaleExitNodeAuto,
        _ => byId[value]?.name ?? value,
      };
    }

    return generateSection(
      title: appLocalizations.tailscaleAdvanced,
      footer: [
        appLocalizations.tailscaleExitNodeHint,
        appLocalizations.tailscaleAutoRouteDesc,
      ].join('\n'),
      items: [
        ListItem<String>.options(
          leading: const GlyphIcon(AppGlyphs.target),
          title: Text(appLocalizations.tailscaleExitNode),
          options: options,
          value: network.exitNode,
          textBuilder: labelOf,
          onChanged: (value) {
            _handleSaveNetwork(network.copyWith(exitNode: value));
          },
        ),
        ListItem.toggle(
          leading: const GlyphIcon(AppGlyphs.rules),
          title: Text(appLocalizations.tailscaleAcceptRoutes),
          value: network.acceptRoutes,
          onChanged: (value) {
            _handleSaveNetwork(network.copyWith(acceptRoutes: value));
          },
        ),
        ListItem.toggle(
          leading: const GlyphIcon(AppGlyphs.dashboard),
          title: Text(appLocalizations.tailscaleExitNodeAllowLan),
          value: network.exitNodeAllowLanAccess,
          onChanged: (value) {
            _handleSaveNetwork(network.copyWith(exitNodeAllowLanAccess: value));
          },
        ),
      ],
    );
  }

  Widget _buildDevicesSection(
    AppLocalizations appLocalizations,
    TailscaleNetworkStatus? status,
  ) {
    final devices = status?.devices ?? const <TailscaleDevice>[];
    if (devices.isEmpty) {
      return const SizedBox.shrink();
    }
    return generateSection(
      title: appLocalizations.tailscaleDevices,
      items: [
        for (final device in devices)
          ListItem(
            leading: const GlyphIcon(AppGlyphs.target),
            title: Text(device.name),
            subtitle: Text(
              [
                _connectionLabel(appLocalizations, device),
                if (device.ips.isNotEmpty) device.ips.first,
              ].join('\n'),
            ),
            trailing: TonalChip(
              label: device.online
                  ? appLocalizations.tailscaleOnline
                  : appLocalizations.tailscaleOffline,
              color: device.online
                  ? context.colorScheme.successContainer
                  : context.colorScheme.surfaceContainerHighest,
              foregroundColor: device.online
                  ? context.colorScheme.onSuccessContainer
                  : context.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildActions(
    AppLocalizations appLocalizations,
    TailscaleNetwork network,
    TailscaleNetworkStatus? status,
    TailscaleData data,
  ) {
    final busy = data.busy.contains(network.id);
    final signedIn =
        status != null &&
        status.state != TailscaleState.needsLogin &&
        status.state != TailscaleState.stopped;
    return generateSection(
      items: [
        if (signedIn)
          ListItem(
            leading: const GlyphIcon(AppGlyphs.lockOpen),
            title: Text(appLocalizations.tailscaleLogout),
            onTap: busy ? null : () => _handleLogout(network),
          ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.checkCircle),
          title: Text(appLocalizations.tailscaleCheckSettings),
          onTap: busy ? null : () => _handleCheck(network),
        ),
        ListItem(
          leading: GlyphIcon(
            AppGlyphs.delete,
            color: context.colorScheme.error,
          ),
          title: Text(
            appLocalizations.tailscaleRemoveNetwork,
            style: TextStyle(color: context.colorScheme.error),
          ),
          onTap: busy ? null : () => _handleRemove(network),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final network = ref
        .watch(
          tailscaleNetworksProvider.select(
            (networks) => networks.where((item) => item.id == widget.networkId),
          ),
        )
        .firstOrNull;
    if (network == null) {
      return Scaffold(
        title: appLocalizations.tailscale,
        body: const SizedBox.shrink(),
      );
    }
    final data = ref.watch(tailscaleActionProvider);
    final status = data.statuses[network.id];
    return Scaffold(
      title: network.name,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.edit,
          tooltip: appLocalizations.edit,
          onPressed: () => _handleEdit(network),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
          top: context.sectionsTopPadding,
          bottom: 20 + context.bottomInset,
        ),
        children: [
          ErrorBanner(
            message: data.available
                ? null
                : appLocalizations.tailscaleUnavailableHint,
          ),
          _buildStatusSection(appLocalizations, network, status, data),
          _buildDeviceSection(appLocalizations, status),
          _buildAdvancedSection(appLocalizations, network, status),
          _buildDevicesSection(appLocalizations, status),
          _buildActions(appLocalizations, network, status, data),
        ],
      ),
    );
  }
}

class _TailscaleNetworkForm extends ConsumerStatefulWidget {
  const _TailscaleNetworkForm({this.network});

  final TailscaleNetwork? network;

  @override
  ConsumerState<_TailscaleNetworkForm> createState() =>
      _TailscaleNetworkFormState();
}

class _TailscaleNetworkFormState extends ConsumerState<_TailscaleNetworkForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _hostnameController;
  late final TextEditingController _controlUrlController;
  late final TextEditingController _authKeyController;
  late TailscaleLoginMethod _loginMethod;
  bool _attempted = false;
  bool _saving = false;
  bool _authKeySaved = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final network = widget.network;
    _nameController = TextEditingController(text: network?.name);
    _hostnameController = TextEditingController(text: network?.hostname);
    _controlUrlController = TextEditingController(text: network?.controlUrl);
    _authKeyController = TextEditingController();
    _loginMethod = network?.loginMethod ?? TailscaleLoginMethod.authKey;
    if (network != null) {
      _loadSavedAuthKey(network.id);
    }
  }

  Future<void> _loadSavedAuthKey(String id) async {
    final saved = await preferences.getTailscaleAuthKey(id);
    if (mounted) {
      setState(() {
        _authKeySaved = saved != null && saved.isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostnameController.dispose();
    _controlUrlController.dispose();
    _authKeyController.dispose();
    super.dispose();
  }

  String? _issue(AppLocalizations appLocalizations) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return appLocalizations.tailscaleNameInvalid;
    }
    final others = ref
        .read(tailscaleNetworksProvider)
        .where((network) => network.id != widget.network?.id)
        .map((network) => network.name.toLowerCase());
    if (others.contains(name.toLowerCase())) {
      return appLocalizations.tailscaleNameInUse;
    }
    final hostname = _hostnameController.text.trim();
    if (hostname.isNotEmpty &&
        !RegExp(
          r'^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$',
        ).hasMatch(hostname)) {
      return appLocalizations.tailscaleHostnameInvalid;
    }
    final controlUrl = _controlUrlController.text.trim();
    if (controlUrl.isNotEmpty) {
      final uri = Uri.tryParse(controlUrl);
      if (uri == null ||
          !const {'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        return appLocalizations.tailscaleControlUrlInvalid;
      }
    }
    if (_loginMethod == TailscaleLoginMethod.authKey &&
        _authKeyController.text.trim().isEmpty &&
        !_authKeySaved) {
      return appLocalizations.emptyTip(appLocalizations.tailscaleAuthKey);
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (_saving) {
      return;
    }
    final appLocalizations = context.appLocalizations;
    final issue = _issue(appLocalizations);
    if (issue != null) {
      setState(() {
        _attempted = true;
      });
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final network = TailscaleNetwork(
      id: widget.network?.id ?? generateRandomSecret(16),
      name: _nameController.text.trim(),
      hostname: _hostnameController.text.trim(),
      controlUrl: _controlUrlController.text.trim(),
      loginMethod: _loginMethod,
      exitNode: widget.network?.exitNode ?? '',
      acceptRoutes: widget.network?.acceptRoutes ?? false,
      exitNodeAllowLanAccess: widget.network?.exitNodeAllowLanAccess ?? false,
    );
    final authKey = _loginMethod == TailscaleLoginMethod.authKey
        ? _authKeyController.text.trim()
        : '';
    final action = ref.read(tailscaleActionProvider.notifier);
    try {
      await action.saveNetwork(
        network,
        authKey: authKey.isEmpty ? null : authKey,
      );
      final status = ref.read(tailscaleActionProvider).statuses[network.id];
      final needsLogin = status?.state == TailscaleState.needsLogin;
      if (_loginMethod == TailscaleLoginMethod.interactive &&
          status != null &&
          (needsLogin || widget.network == null)) {
        await action.login(network.id);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = userFacingErrorMessage(error, appLocalizations);
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _saving = false;
      });
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final issue = _attempted ? _issue(appLocalizations) : null;
    return FormPage(
      title: widget.network == null
          ? appLocalizations.tailscaleAddNetwork
          : appLocalizations.edit,
      onSave: _handleSave,
      saveLabel: appLocalizations.tailscaleSaveAndLogin,
      saving: _saving,
      error: issue ?? _saveError,
      children: [
        generateSection(
          items: [
            FormRow(
              title: appLocalizations.tailscaleNetworkName,
              invalid:
                  issue == appLocalizations.tailscaleNameInvalid ||
                  issue == appLocalizations.tailscaleNameInUse,
              trailing: FormRowTextField(
                controller: _nameController,
                autofocus: widget.network == null,
                hintText: appLocalizations.required,
                textInputAction: TextInputAction.next,
                inputFormatters: TextInputLimits.limit(TextInputLimits.name),
                onChanged: (_) {
                  if (_attempted) {
                    setState(() {});
                  }
                },
              ),
            ),
            FormRow(
              title: appLocalizations.tailscaleHostname,
              invalid: issue == appLocalizations.tailscaleHostnameInvalid,
              trailing: FormRowTextField(
                controller: _hostnameController,
                hintText: appLocalizations.optional,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                inputFormatters: TextInputLimits.limit(TextInputLimits.domain),
                onChanged: (_) {
                  if (_attempted) {
                    setState(() {});
                  }
                },
              ),
            ),
            FormRow(
              title: appLocalizations.tailscaleControlUrl,
              invalid: issue == appLocalizations.tailscaleControlUrlInvalid,
              trailing: FormRowTextField(
                controller: _controlUrlController,
                hintText: defaultTailscaleControlUrl,
                autocorrect: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                inputFormatters: TextInputLimits.limit(TextInputLimits.url),
                onChanged: (_) {
                  if (_attempted) {
                    setState(() {});
                  }
                },
              ),
            ),
          ],
        ),
        generateSection(
          items: [
            ListItem<TailscaleLoginMethod>.options(
              leading: const GlyphIcon(AppGlyphs.key),
              title: Text(appLocalizations.tailscaleLoginMethod),
              options: TailscaleLoginMethod.values,
              value: _loginMethod,
              textBuilder: (method) => switch (method) {
                TailscaleLoginMethod.authKey =>
                  appLocalizations.tailscaleAuthKey,
                TailscaleLoginMethod.interactive =>
                  appLocalizations.tailscaleInteractiveLogin,
              },
              onChanged: (method) {
                setState(() {
                  _loginMethod = method;
                });
              },
            ),
            if (_loginMethod == TailscaleLoginMethod.authKey)
              FormRow(
                title: appLocalizations.tailscaleAuthKey,
                invalid:
                    issue ==
                    appLocalizations.emptyTip(
                      appLocalizations.tailscaleAuthKey,
                    ),
                trailing: FormRowSecretTextField(
                  controller: _authKeyController,
                  hintText: _authKeySaved
                      ? appLocalizations.tailscaleAuthKeySaved
                      : appLocalizations.tailscaleEnterAuthKey,
                  textInputAction: TextInputAction.done,
                  inputFormatters: TextInputLimits.limit(
                    TextInputLimits.password,
                  ),
                  onChanged: (_) {
                    if (_attempted) {
                      setState(() {});
                    }
                  },
                  onFieldSubmitted: (_) => _handleSave(),
                ),
              ),
          ],
        ),
        ListFooter(
          text: [
            appLocalizations.tailscaleLoginHint,
            appLocalizations.tailscaleControlUrlHint,
            appLocalizations.tailscaleLoginFooter,
          ].join('\n'),
        ),
      ],
    );
  }
}
