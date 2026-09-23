class RuDateFormat {
  static const List<String> monthNames = [
    'янв',
    'фев',
    'март',
    'апр',
    'май',
    'июнь',
    'июль',
    'авг',
    'сен',
    'окт',
    'нояб',
    'дек',
  ];

  static String monthName(int month) {
    assert(month >= 1 && month <= 12);
    return monthNames[month - 1];
  }

  static String monthYear(DateTime date) {
    return '${monthName(date.month)} ${date.year}';
  }
}
