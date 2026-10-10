import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/progress_repository.dart';
import 'chat_models.dart';

/// One past conversation, for the Past chats list.
class ChatSessionSummary {
  const ChatSessionSummary({
    required this.id,
    required this.startedAt,
    required this.preview,
    required this.messageCount,
    this.open = false,
  });

  final String id;

  /// In Nairobi time.
  final DateTime startedAt;

  /// The user's first message.
  final String preview;
  final int messageCount;

  /// Not ended yet (the current chat).
  final bool open;
}

/// A conversation picked up where the user left it.
class RestoredChat {
  const RestoredChat({required this.startedAt, required this.messages});

  final DateTime startedAt;
  final List<ChatMessage> messages;
}

/// Sends messages and manages conversations.
///
/// The chat screen only talks to this interface, so tests can use a fake
/// (the default methods do nothing).
abstract class ChatBackend {
  Future<ChatReply> send(String text);

  /// Ends the current conversation; the next message starts a new one.
  Future<void> startNewChat() async {}

  /// The latest unfinished conversation, if the last message was recent.
  Future<RestoredChat?> restore() async => null;

  /// Recent conversations, newest first.
  Future<List<ChatSessionSummary>> loadPastChats() async => const <ChatSessionSummary>[];

  /// All messages of one conversation, oldest first.
  Future<List<ChatMessage>> loadTranscript(String sessionId) async => const <ChatMessage>[];
}

/// Talks to the `chat` Edge Function (supabase/functions/chat) and reads the
/// user's own sessions and messages (row-level security limits them).
class SupabaseChatBackend extends ChatBackend {
  SupabaseChatBackend([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  String? _sessionId;

  /// A conversation is picked up again only if its last message is this recent.
  static const Duration resumeWithin = Duration(hours: 12);

  @override
  Future<ChatReply> send(String text) async {
    final FunctionResponse response = await _client.functions.invoke(
      'chat',
      body: <String, dynamic>{
        'text': text,
        if (_sessionId != null) 'session_id': _sessionId,
      },
    );

    final ChatReply reply = ChatReply.fromJson(Map<String, dynamic>.from(response.data as Map));
    _sessionId = reply.sessionId ?? _sessionId;
    return reply;
  }

  @override
  Future<void> startNewChat() async {
    final String? id = _sessionId;
    _sessionId = null;
    if (id == null) return;
    await _client
        .from('chat_sessions')
        .update(<String, dynamic>{'ended_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .isFilter('ended_at', null);
  }

  static List<ChatMessage> _messages(List<dynamic> rows) => <ChatMessage>[
        for (final dynamic m in rows)
          ChatMessage(
            text: (m as Map<String, dynamic>)['content'] as String,
            fromUser: m['sender'] == 'user',
          ),
      ];

  @override
  Future<RestoredChat?> restore() async {
    final Map<String, dynamic>? session = await _client
        .from('chat_sessions')
        .select('id, started_at')
        .isFilter('ended_at', null)
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (session == null) return null;
    final List<dynamic> rows = await _client
        .from('messages')
        .select('sender, content, created_at')
        .eq('session_id', session['id'] as String)
        .order('created_at');
    final DateTime last = rows.isEmpty
        ? DateTime.parse(session['started_at'] as String)
        : DateTime.parse((rows.last as Map<String, dynamic>)['created_at'] as String);
    if (rows.isEmpty || DateTime.now().toUtc().difference(last) > resumeWithin) {
      // Too old to pick up: close it, so the next message starts a new chat.
      _sessionId = session['id'] as String;
      await startNewChat();
      return null;
    }
    _sessionId = session['id'] as String;
    return RestoredChat(
      startedAt: nairobiNow(DateTime.parse(session['started_at'] as String)),
      messages: _messages(rows),
    );
  }

  @override
  Future<List<ChatSessionSummary>> loadPastChats() async {
    final List<dynamic> rows = await _client
        .from('chat_sessions')
        .select('id, started_at, ended_at, messages(sender, content, created_at)')
        .order('started_at', ascending: false)
        .order('created_at', referencedTable: 'messages')
        .limit(30);
    return <ChatSessionSummary>[
      for (final dynamic r in rows)
        if (((r as Map<String, dynamic>)['messages'] as List<dynamic>).isNotEmpty)
          ChatSessionSummary(
            id: r['id'] as String,
            startedAt: nairobiNow(DateTime.parse(r['started_at'] as String)),
            open: r['ended_at'] == null,
            messageCount: (r['messages'] as List<dynamic>).length,
            preview: () {
              for (final dynamic m in r['messages'] as List<dynamic>) {
                if ((m as Map<String, dynamic>)['sender'] == 'user') return m['content'] as String;
              }
              return '';
            }(),
          ),
    ];
  }

  @override
  Future<List<ChatMessage>> loadTranscript(String sessionId) async {
    final List<dynamic> rows = await _client
        .from('messages')
        .select('sender, content, created_at')
        .eq('session_id', sessionId)
        .order('created_at');
    return _messages(rows);
  }
}
