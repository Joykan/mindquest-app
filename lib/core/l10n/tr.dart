import 'package:flutter/widgets.dart';

/// The app's two languages. Every screen shows English or Kiswahili,
/// following the language the user picked (Welcome, Onboarding or Profile).
const List<String> appLanguages = <String>['en', 'sw'];

/// Puts the current language above every screen, dialog and bottom sheet.
/// Widgets read it with `context.tr(...)` and rebuild when it changes.
class LanguageScope extends InheritedWidget {
  const LanguageScope(
      {super.key, required this.language, required super.child});

  final String language;

  /// The current language, or English when there is no scope (e.g. in tests).
  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.language ??
      'en';

  @override
  bool updateShouldNotify(LanguageScope oldWidget) =>
      oldWidget.language != language;
}

/// Picks the English or Kiswahili text. Used outside widgets, e.g. when
/// building insights or reply texts.
String tr(String language, String en, String sw) => language == 'sw' ? sw : en;

extension Translate on BuildContext {
  /// 'en' or 'sw'.
  String get lang => LanguageScope.of(this);

  bool get isSw => lang == 'sw';

  /// The English or Kiswahili text, whichever the user picked.
  String tr(String en, String sw) => isSw ? sw : en;
}

const List<String> _monthsEn = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const List<String> _monthsSw = <String>[
  'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', //
  'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des',
];
const List<String> _monthsFullEn = <String>[
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
const List<String> _monthsFullSw = <String>[
  'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni', //
  'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba',
];
const List<String> _daysEn = <String>[
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];
// Common short forms on Kenyan calendars.
const List<String> _daysSw = <String>[
  'Jtt', 'Jnn', 'Jtn', 'Alh', 'Iju', 'Jmo', 'Jpi', //
];
const List<String> _daysFullEn = <String>[
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  'Sunday', //
];
const List<String> _daysFullSw = <String>[
  'Jumatatu', 'Jumanne', 'Jumatano', 'Alhamisi', 'Ijumaa', 'Jumamosi',
  'Jumapili', //
];

/// "Mon" / "Jtt" for a weekday (DateTime.monday = 1).
String shortDay(String language, int weekday) =>
    (language == 'sw' ? _daysSw : _daysEn)[weekday - 1];

/// "Monday" / "Jumatatu".
String fullDay(String language, int weekday) =>
    (language == 'sw' ? _daysFullSw : _daysFullEn)[weekday - 1];

/// "Oct" / "Okt".
String shortMonth(String language, int month) =>
    (language == 'sw' ? _monthsSw : _monthsEn)[month - 1];

/// "October" / "Oktoba".
String fullMonth(String language, int month) =>
    (language == 'sw' ? _monthsFullSw : _monthsFullEn)[month - 1];

/// "13 Oct" / "13 Okt".
String shortDate(String language, DateTime d) =>
    '${d.day} ${shortMonth(language, d.month)}';

/// "Tuesday, 13 October" / "Jumanne, 13 Oktoba".
String longDate(String language, DateTime d) =>
    '${fullDay(language, d.weekday)}, ${d.day} ${fullMonth(language, d.month)}';

/// "10:23".
String clock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
