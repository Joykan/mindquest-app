/// What a chat item shows.
enum ChatItemKind {
  /// A plain text bubble.
  text,

  /// A bot question with five mood faces to tap.
  moodPicker,

  /// The week's moods drawn as a graph.
  moodGraph,

  /// A caring message with a button to the helplines.
  support,

  /// A small centred note, e.g. "Continuing your chat from 09:41".
  note,
}

/// One item in the chat list.
class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.fromUser,
    this.kind = ChatItemKind.text,
  });

  final String text;
  final bool fromUser;
  final ChatItemKind kind;
}

/// A helpline shown when a crisis message is detected.
class Helpline {
  const Helpline({
    required this.name,
    required this.phone,
    this.description,
    this.descriptionSw,
    this.nameSw,
  });

  factory Helpline.fromJson(Map<String, dynamic> json) => Helpline(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        description: json['description'] as String?,
        descriptionSw: json['description_sw'] as String?,
      );

  final String name;
  final String phone;
  final String? description;
  final String? descriptionSw;

  /// Only for names that are not the organisation's own name.
  final String? nameSw;

  String nameIn(String language) =>
      language == 'sw' && (nameSw ?? '').isNotEmpty ? nameSw! : name;

  String? describe(String language) =>
      language == 'sw' && (descriptionSw ?? '').isNotEmpty
          ? descriptionSw
          : description;
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
