import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_models.dart';

/// Sends a message and returns the bot's reply.
///
/// The chat screen only talks to this interface, so tests can use a fake.
abstract class ChatBackend {
  Future<ChatReply> send(String text);
}

/// Talks to the `chat` Edge Function (supabase/functions/chat).
class SupabaseChatBackend implements ChatBackend {
  SupabaseChatBackend([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  String? _sessionId;

  @override
  Future<ChatReply> send(String text) async {
    // Until the sign-in screens exist, chat as an anonymous user.
    if (_client.auth.currentSession == null) {
      await _client.auth.signInAnonymously();
    }

    final FunctionResponse response = await _client.functions.invoke(
      'chat',
      body: <String, dynamic>{
        'text': text,
        if (_sessionId != null) 'session_id': _sessionId,
      },
    );

    final ChatReply reply =
        ChatReply.fromJson(Map<String, dynamic>.from(response.data as Map));
    _sessionId = reply.sessionId ?? _sessionId;
    return reply;
  }
}
