import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/features/chat/chat_models.dart';
import 'package:mindquest/features/chat/offline_chipu.dart';

void main() {
  test('a mood command is recognised in English and Kiswahili', () {
    expect(isMoodCommand('Log my mood.'), isTrue);
    expect(isMoodCommand('please record my mood'), isTrue);
    expect(isMoodCommand('mood check-in'), isTrue);
    expect(isMoodCommand('rekodi hisia zangu'), isTrue);
    expect(isMoodCommand("I'm in a bad mood about exams"), isFalse);
  });

  test('offline, Chipu still offers breathing and a mood check-in', () {
    final OfflineAnswer breathe = offlineAnswer('Help me breathe', 'en');
    expect(breathe.kind, ChatItemKind.breathing);
    expect(breathe.move, OfflineMove.breathing);
    expect(offlineAnswer('nataka kupumua', 'sw').move, OfflineMove.breathing);
    final OfflineAnswer mood = offlineAnswer('log my mood', 'en');
    expect(mood.kind, ChatItemKind.moodPicker);
    expect(mood.move, OfflineMove.mood);
  });

  test('offline encouragement and "feeling better" get a kind reply', () {
    final OfflineAnswer e = offlineAnswer('Encourage me.', 'en', Random(1));
    expect(e.kind, ChatItemKind.text);
    expect(e.text, isNot(contains("You're offline")));
    expect(offlineAnswer('I now feel better', 'en').text,
        contains('a bit better'));
  });

  test('anything else says Chipu is offline, in the chosen language', () {
    expect(offlineAnswer("I'm stressed about exams", 'en').text,
        contains("You're offline"));
    expect(offlineAnswer('nina msongo', 'sw').text, contains('Huna mtandao'));
  });

  test('only messages Chipu can answer on the phone are marked as known', () {
    expect(offlineAnswer('encourage me', 'en').known, isTrue);
    expect(offlineAnswer('help me breathe', 'en').known, isTrue);
    expect(offlineAnswer('tell me a story', 'en').known, isFalse);
  });
}
