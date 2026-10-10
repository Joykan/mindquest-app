/// One bubble in the chat list.
class ChatMessage {
  const ChatMessage({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;
}

/// A helpline shown when a crisis message is detected.
class Helpline {
  const Helpline({required this.name, required this.phone, this.description});

  factory Helpline.fromJson(Map<String, dynamic> json) => Helpline(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        description: json['description'] as String?,
      );

  final String name;
  final String phone;
  final String? description;
}

/// What the chat Edge Function sends back for one message.
class ChatReply {
  const ChatReply({
    required this.reply,
    this.sessionId,
    this.crisis = false,
    this.helplines = const <Helpline>[],
  });

  factory ChatReply.fromJson(Map<String, dynamic> json) => ChatReply(
        reply: json['reply'] as String? ?? '',
        sessionId: json['session_id'] as String?,
        crisis: json['crisis'] == true,
        helplines: (json['helplines'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic h) => Helpline.fromJson(h as Map<String, dynamic>))
            .toList(),
      );

  final String reply;
  final String? sessionId;
  final bool crisis;
  final List<Helpline> helplines;
}
