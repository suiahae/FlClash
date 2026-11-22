// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../tailscale.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TailscaleNetwork _$TailscaleNetworkFromJson(Map<String, dynamic> json) =>
    _TailscaleNetwork(
      id: json['id'] as String,
      name: json['name'] as String,
      hostname: json['hostname'] as String? ?? '',
      controlUrl: json['controlUrl'] as String? ?? defaultTailscaleControlUrl,
      loginMethod:
          $enumDecodeNullable(
            _$TailscaleLoginMethodEnumMap,
            json['loginMethod'],
          ) ??
          TailscaleLoginMethod.authKey,
      exitNode: json['exitNode'] as String? ?? '',
      acceptRoutes: json['acceptRoutes'] as bool? ?? false,
      exitNodeAllowLanAccess: json['exitNodeAllowLanAccess'] as bool? ?? false,
    );

Map<String, dynamic> _$TailscaleNetworkToJson(_TailscaleNetwork instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'hostname': instance.hostname,
      'controlUrl': instance.controlUrl,
      'loginMethod': _$TailscaleLoginMethodEnumMap[instance.loginMethod]!,
      'exitNode': instance.exitNode,
      'acceptRoutes': instance.acceptRoutes,
      'exitNodeAllowLanAccess': instance.exitNodeAllowLanAccess,
    };

const _$TailscaleLoginMethodEnumMap = {
  TailscaleLoginMethod.authKey: 'auth-key',
  TailscaleLoginMethod.interactive: 'interactive',
};
