/// Age ranges asked at onboarding (public.profiles.age_range). A range, not a
/// date of birth, so accounts stay anonymous. MindQuest is made for youth
/// aged 15–24 (the proposal's target group).
class AgeRange {
  const AgeRange(this.id, this.en, this.sw);

  final String id;
  final String en;
  final String sw;

  String label(String language) => language == 'sw' ? sw : en;
}

const List<AgeRange> ageRanges = <AgeRange>[
  AgeRange('under_15', 'Under 15', 'Chini ya 15'),
  AgeRange('15_17', '15–17', '15–17'),
  AgeRange('18_20', '18–20', '18–20'),
  AgeRange('21_24', '21–24', '21–24'),
  AgeRange('25_plus', '25 or older', '25 au zaidi'),
  AgeRange('prefer_not', 'Prefer not to say', 'Sipendi kusema'),
];
