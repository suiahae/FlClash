// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../tailscale.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TailscaleNetwork {

 String get id; String get name; String get hostname; String get controlUrl; TailscaleLoginMethod get loginMethod; String get exitNode; bool get acceptRoutes; bool get exitNodeAllowLanAccess;
/// Create a copy of TailscaleNetwork
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleNetworkCopyWith<TailscaleNetwork> get copyWith => _$TailscaleNetworkCopyWithImpl<TailscaleNetwork>(this as TailscaleNetwork, _$identity);

  /// Serializes this TailscaleNetwork to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleNetwork;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleNetwork&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.hostname, _this.hostname) || other.hostname == _this.hostname)&&(identical(other.controlUrl, _this.controlUrl) || other.controlUrl == _this.controlUrl)&&(identical(other.loginMethod, _this.loginMethod) || other.loginMethod == _this.loginMethod)&&(identical(other.exitNode, _this.exitNode) || other.exitNode == _this.exitNode)&&(identical(other.acceptRoutes, _this.acceptRoutes) || other.acceptRoutes == _this.acceptRoutes)&&(identical(other.exitNodeAllowLanAccess, _this.exitNodeAllowLanAccess) || other.exitNodeAllowLanAccess == _this.exitNodeAllowLanAccess));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleNetwork;
  return Object.hash(runtimeType,_this.id,_this.name,_this.hostname,_this.controlUrl,_this.loginMethod,_this.exitNode,_this.acceptRoutes,_this.exitNodeAllowLanAccess);
}

@override
String toString() {
  final _this = this as TailscaleNetwork;
  return 'TailscaleNetwork(id: ${_this.id}, name: ${_this.name}, hostname: ${_this.hostname}, controlUrl: ${_this.controlUrl}, loginMethod: ${_this.loginMethod}, exitNode: ${_this.exitNode}, acceptRoutes: ${_this.acceptRoutes}, exitNodeAllowLanAccess: ${_this.exitNodeAllowLanAccess})';
}


}

/// @nodoc
abstract mixin class $TailscaleNetworkCopyWith<$Res>  {
  factory $TailscaleNetworkCopyWith(TailscaleNetwork value, $Res Function(TailscaleNetwork) _then) = _$TailscaleNetworkCopyWithImpl;
@useResult
$Res call({
 String id, String name, String hostname, String controlUrl, TailscaleLoginMethod loginMethod, String exitNode, bool acceptRoutes, bool exitNodeAllowLanAccess
});




}
/// @nodoc
class _$TailscaleNetworkCopyWithImpl<$Res>
    implements $TailscaleNetworkCopyWith<$Res> {
  _$TailscaleNetworkCopyWithImpl(this._self, this._then);

  final TailscaleNetwork _self;
  final $Res Function(TailscaleNetwork) _then;

/// Create a copy of TailscaleNetwork
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? hostname = null,Object? controlUrl = null,Object? loginMethod = null,Object? exitNode = null,Object? acceptRoutes = null,Object? exitNodeAllowLanAccess = null,}) {
  return _then(TailscaleNetwork(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,hostname: null == hostname ? _self.hostname : hostname // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,loginMethod: null == loginMethod ? _self.loginMethod : loginMethod // ignore: cast_nullable_to_non_nullable
as TailscaleLoginMethod,exitNode: null == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as String,acceptRoutes: null == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as bool,exitNodeAllowLanAccess: null == exitNodeAllowLanAccess ? _self.exitNodeAllowLanAccess : exitNodeAllowLanAccess // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleNetwork].
extension TailscaleNetworkPatterns on TailscaleNetwork {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleNetwork value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleNetwork() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleNetwork value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleNetwork():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleNetwork value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleNetwork() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String hostname,  String controlUrl,  TailscaleLoginMethod loginMethod,  String exitNode,  bool acceptRoutes,  bool exitNodeAllowLanAccess)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleNetwork() when $default != null:
return $default(_that.id,_that.name,_that.hostname,_that.controlUrl,_that.loginMethod,_that.exitNode,_that.acceptRoutes,_that.exitNodeAllowLanAccess);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String hostname,  String controlUrl,  TailscaleLoginMethod loginMethod,  String exitNode,  bool acceptRoutes,  bool exitNodeAllowLanAccess)  $default,) {final _that = this;
switch (_that) {
case _TailscaleNetwork():
return $default(_that.id,_that.name,_that.hostname,_that.controlUrl,_that.loginMethod,_that.exitNode,_that.acceptRoutes,_that.exitNodeAllowLanAccess);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String hostname,  String controlUrl,  TailscaleLoginMethod loginMethod,  String exitNode,  bool acceptRoutes,  bool exitNodeAllowLanAccess)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleNetwork() when $default != null:
return $default(_that.id,_that.name,_that.hostname,_that.controlUrl,_that.loginMethod,_that.exitNode,_that.acceptRoutes,_that.exitNodeAllowLanAccess);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleNetwork implements TailscaleNetwork {
  const _TailscaleNetwork({required this.id, required this.name, this.hostname = '', this.controlUrl = defaultTailscaleControlUrl, this.loginMethod = TailscaleLoginMethod.authKey, this.exitNode = '', this.acceptRoutes = false, this.exitNodeAllowLanAccess = false});
  factory _TailscaleNetwork.fromJson(Map<String, dynamic> json) => _$TailscaleNetworkFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  String hostname;
@override@JsonKey() final  String controlUrl;
@override@JsonKey() final  TailscaleLoginMethod loginMethod;
@override@JsonKey() final  String exitNode;
@override@JsonKey() final  bool acceptRoutes;
@override@JsonKey() final  bool exitNodeAllowLanAccess;

/// Create a copy of TailscaleNetwork
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleNetworkCopyWith<_TailscaleNetwork> get copyWith => __$TailscaleNetworkCopyWithImpl<_TailscaleNetwork>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleNetworkToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleNetwork&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.hostname, hostname) || other.hostname == hostname)&&(identical(other.controlUrl, controlUrl) || other.controlUrl == controlUrl)&&(identical(other.loginMethod, loginMethod) || other.loginMethod == loginMethod)&&(identical(other.exitNode, exitNode) || other.exitNode == exitNode)&&(identical(other.acceptRoutes, acceptRoutes) || other.acceptRoutes == acceptRoutes)&&(identical(other.exitNodeAllowLanAccess, exitNodeAllowLanAccess) || other.exitNodeAllowLanAccess == exitNodeAllowLanAccess));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,hostname,controlUrl,loginMethod,exitNode,acceptRoutes,exitNodeAllowLanAccess);
}

@override
String toString() {
    return 'TailscaleNetwork(id: $id, name: $name, hostname: $hostname, controlUrl: $controlUrl, loginMethod: $loginMethod, exitNode: $exitNode, acceptRoutes: $acceptRoutes, exitNodeAllowLanAccess: $exitNodeAllowLanAccess)';
}


}

/// @nodoc
abstract mixin class _$TailscaleNetworkCopyWith<$Res> implements $TailscaleNetworkCopyWith<$Res> {
  factory _$TailscaleNetworkCopyWith(_TailscaleNetwork value, $Res Function(_TailscaleNetwork) _then) = __$TailscaleNetworkCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String hostname, String controlUrl, TailscaleLoginMethod loginMethod, String exitNode, bool acceptRoutes, bool exitNodeAllowLanAccess
});




}
/// @nodoc
class __$TailscaleNetworkCopyWithImpl<$Res>
    implements _$TailscaleNetworkCopyWith<$Res> {
  __$TailscaleNetworkCopyWithImpl(this._self, this._then);

  final _TailscaleNetwork _self;
  final $Res Function(_TailscaleNetwork) _then;

/// Create a copy of TailscaleNetwork
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? hostname = null,Object? controlUrl = null,Object? loginMethod = null,Object? exitNode = null,Object? acceptRoutes = null,Object? exitNodeAllowLanAccess = null,}) {
  return _then(_TailscaleNetwork(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,hostname: null == hostname ? _self.hostname : hostname // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,loginMethod: null == loginMethod ? _self.loginMethod : loginMethod // ignore: cast_nullable_to_non_nullable
as TailscaleLoginMethod,exitNode: null == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as String,acceptRoutes: null == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as bool,exitNodeAllowLanAccess: null == exitNodeAllowLanAccess ? _self.exitNodeAllowLanAccess : exitNodeAllowLanAccess // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
