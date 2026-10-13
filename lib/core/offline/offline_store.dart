import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// True when [e] means the server could not be reached (no internet, a
/// timeout), not that the server answered with an error.
bool isOfflineError(Object e) {
  if (e is TimeoutException) return true;
  if (e is AuthRetryableFetchException) return true;
  if (e is PostgrestException || e is AuthException || e is FunctionException) {
    return false;
  }
  final String s = e.toString();
  return s.contains('SocketException') ||
      s.contains('ClientException') ||
      s.contains('Failed host lookup') ||
      s.contains('Network is unreachable') ||
      s.contains('Connection refused') ||
      s.contains('Connection reset') ||
      s.contains('Connection closed') ||
      s.contains('HandshakeException') ||
      s.contains('XMLHttpRequest');
}

/// A random id (UUID version 4), made on the phone so a check-in saved
/// offline keeps the same id when it reaches the server.
String newId([Random? random]) {
  final Random r = random ?? Random.secure();
  final List<int> b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final String h = b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Whether the app is showing saved data, and how much is waiting to sync.
/// The offline banner listens to this.
class ConnectionStatus extends ChangeNotifier {
  bool _offline = false;
  DateTime? _savedAt;
  int _pending = 0;

  /// The last request could not reach the server.
  bool get offline => _offline;

  /// When the data on screen was saved (shown while offline).
  DateTime? get savedAt => _savedAt;

  /// Check-ins and article reads waiting to be sent.
  int get pending => _pending;

  void markOnline() {
    if (!_offline) return;
    _offline = false;
    notifyListeners();
  }

  void markOffline([DateTime? savedAt]) {
    if (_offline && savedAt == _savedAt) return;
    _offline = true;
    _savedAt = savedAt ?? _savedAt;
    notifyListeners();
  }

  void setPending(int n) {
    if (n == _pending) return;
    _pending = n;
    notifyListeners();
  }
}

/// Something done without internet, waiting to be sent to the server.
class PendingAction {
  const PendingAction(
      {required this.id, required this.kind, required this.data});

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
        id: json['id'] as String,
        kind: json['kind'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
      );

  final String id;

  /// 'mood' (a check-in) or 'read' (an article marked as read).
  final String kind;

  /// The row to insert.
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'id': id, 'kind': kind, 'data': data};
}

typedef PendingSender = Future<void> Function(Map<String, dynamic> data);

/// Offline support (step 10).
///
/// - [load] saves a copy of what the server returns, per user, on the phone.
///   Without internet it returns that copy instead, so the app still opens
///   and shows the user's last data.
/// - Check-ins and article reads made offline are kept in a queue
///   ([addPending]) and sent, oldest first, when the internet is back
///   ([flush]). That happens when the app opens or comes back to the front,
///   every 30 seconds while something is waiting, and before each load.
class OfflineStore with WidgetsBindingObserver {
  OfflineStore(
    this._prefs, {
    required this.userId,
    ConnectionStatus? status,
    this.timeout = const Duration(seconds: 15),
  }) : status = status ?? ConnectionStatus() {
    _updatePending();
  }

  final SharedPreferences _prefs;

  /// The signed-in user's id (null when signed out).
  final String? Function() userId;
  final ConnectionStatus status;

  /// How long to wait for the server before using the saved copy.
  final Duration timeout;

  final Map<String, PendingSender> _senders = <String, PendingSender>{};

  /// Called after something waiting was sent, so screens reload.
  VoidCallback? onSynced;

  bool _started = false;
  Future<int>? _flushing;

  static const String _prefix = 'offline.';

  String _key(String uid, String name) => '$_prefix$uid.$name';

  /// Runs [remote] and saves the result. If the server can't be reached,
  /// returns the saved copy (or rethrows if there is none).
  Future<dynamic> load(String name, Future<dynamic> Function() remote) async {
    final String? uid = userId();
    try {
      final dynamic value = await remote().timeout(timeout);
      status.markOnline();
      if (uid != null) {
        await _prefs.setString(
          _key(uid, 'cache.$name'),
          jsonEncode(<String, dynamic>{
            'at': DateTime.now().toUtc().toIso8601String(),
            'value': value,
          }),
        );
      }
      return value;
    } catch (e) {
      if (!isOfflineError(e)) rethrow;
      final String? raw =
          uid == null ? null : _prefs.getString(_key(uid, 'cache.$name'));
      if (raw == null) {
        status.markOffline();
        rethrow;
      }
      final Map<String, dynamic> saved =
          jsonDecode(raw) as Map<String, dynamic>;
      status.markOffline(DateTime.parse(saved['at'] as String));
      return saved['value'];
    }
  }

  /// The saved copy of [name], if any (without asking the server).
  dynamic saved(String name) {
    final String? uid = userId();
    final String? raw =
        uid == null ? null : _prefs.getString(_key(uid, 'cache.$name'));
    if (raw == null) return null;
    return (jsonDecode(raw) as Map<String, dynamic>)['value'];
  }

  /// Tells the store how to send a waiting action of this [kind].
  void register(String kind, PendingSender send) => _senders[kind] = send;

  /// Everything waiting to be sent, oldest first.
  List<PendingAction> pending([String? kind]) {
    final String? uid = userId();
    if (uid == null) return const <PendingAction>[];
    final String? raw = _prefs.getString(_key(uid, 'queue'));
    if (raw == null) return const <PendingAction>[];
    return <PendingAction>[
      for (final dynamic a in jsonDecode(raw) as List<dynamic>)
        PendingAction.fromJson(a as Map<String, dynamic>),
    ].where((PendingAction a) => kind == null || a.kind == kind).toList();
  }

  bool isPending(String id) => pending().any((PendingAction a) => a.id == id);

  Future<void> _save(String uid, List<PendingAction> queue) async {
    await _prefs.setString(_key(uid, 'queue'),
        jsonEncode(queue.map((PendingAction a) => a.toJson()).toList()));
    _updatePending();
  }

  void _updatePending() => status.setPending(pending().length);

  Future<void> addPending(PendingAction action) async {
    final String? uid = userId();
    if (uid == null) return;
    await _save(uid, <PendingAction>[...pending(), action]);
  }

  Future<void> removePending(String id) async {
    final String? uid = userId();
    if (uid == null) return;
    await _save(uid, pending().where((PendingAction a) => a.id != id).toList());
  }

  /// Sends what is waiting, oldest first, and returns how many were sent.
  /// Stops at the first one that can't be sent (e.g. still no internet).
  Future<int> flush() {
    if (pending().isEmpty) return Future<int>.value(0);
    return _flushing ??= _flush().whenComplete(() => _flushing = null);
  }

  Future<int> _flush() async {
    int sent = 0;
    for (final PendingAction a in pending()) {
      final PendingSender? send = _senders[a.kind];
      if (send == null) continue;
      bool delivered = true;
      try {
        await send(a.data).timeout(timeout);
        status.markOnline();
      } on PostgrestException catch (e) {
        final String code = e.code ?? '';
        // 23505: it was saved before (the reply got lost), so it is done.
        // Other 23xxx/22xxx/42xxx: the server will never accept it (e.g. a
        // check-in older than 7 days), so it is dropped instead of blocking
        // everything behind it. Anything else (login expired, server busy):
        // try again later.
        final bool done = code == '23505';
        final bool rejected = code.startsWith('23') ||
            code.startsWith('22') ||
            code.startsWith('42');
        if (!done && !rejected) break;
        if (!done) {
          delivered = false;
          debugPrint('Offline ${a.kind} ${a.id} was rejected: ${e.message}');
        }
      } catch (e) {
        if (isOfflineError(e)) status.markOffline();
        break;
      }
      await removePending(a.id);
      if (delivered) sent++;
    }
    _updatePending();
    if (sent > 0) onSynced?.call();
    return sent;
  }

  /// Removes everything saved for the signed-in user (on sign out).
  Future<void> clearUser(String uid) async {
    for (final String k in _prefs.getKeys().toList()) {
      if (k.startsWith('$_prefix$uid.')) await _prefs.remove(k);
    }
    _updatePending();
  }

  /// A small request used to notice that the internet is back.
  Future<void> Function()? probe;

  /// Sends what is waiting and checks whether the internet is back. Runs
  /// every 30 seconds, when the app comes to the front, and from the
  /// offline banner's Retry.
  Future<void> retry() async {
    await flush();
    final Future<void> Function()? ping = probe;
    if (!status.offline || ping == null) return;
    try {
      await ping().timeout(timeout);
      status.markOnline();
      onSynced?.call(); // screens reload with fresh data
    } catch (_) {
      // Still offline.
    }
  }

  /// Starts syncing in the background (called once from main).
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    Timer.periodic(const Duration(seconds: 30), (_) {
      if (pending().isNotEmpty || status.offline) unawaited(retry());
    });
    unawaited(flush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePending();
      unawaited(retry());
    }
  }
}
