import 'habit_model.dart';

enum HabitDayStatus {
  completed,
  missed,
  pending,
}

class HabitDayEntry {
  final Habit habit;
  final HabitDayStatus status;

  const HabitDayEntry({required this.habit, required this.status});
}

class CalendarLogic {
  static DateTime normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime get today => normalize(DateTime.now());

  static bool isSameDay(DateTime a, DateTime b) {
    final na = normalize(a);
    final nb = normalize(b);
    return na.year == nb.year && na.month == nb.month && na.day == nb.day;
  }

  static bool isBeforeDay(DateTime day, DateTime reference) {
    return normalize(day).isBefore(normalize(reference));
  }

  static bool isAfterDay(DateTime day, DateTime reference) {
    return normalize(day).isAfter(normalize(reference));
  }

  static bool isHabitActiveOnDay(Habit habit, DateTime day) {
    return isSameDay(habit.scheduledDate, day);
  }

  static bool isCompletedOnDay(Habit habit, DateTime day) {
    return habit.completedDates.any((d) => isSameDay(d, day));
  }

  static HabitDayStatus getHabitStatus(Habit habit, DateTime day) {
    if (isCompletedOnDay(habit, day)) {
      return HabitDayStatus.completed;
    }
    if (isBeforeDay(day, today)) {
      return HabitDayStatus.missed;
    }
    return HabitDayStatus.pending;
  }

  static List<HabitDayEntry> habitsForDay(List<Habit> habits, DateTime day) {
    final entries = <HabitDayEntry>[];
    for (final habit in habits) {
      if (!isHabitActiveOnDay(habit, day)) continue;
      entries.add(HabitDayEntry(
        habit: habit,
        status: getHabitStatus(habit, day),
      ));
    }
    entries.sort((a, b) {
      final order = {
        HabitDayStatus.pending: 0,
        HabitDayStatus.missed: 1,
        HabitDayStatus.completed: 2,
      };
      final cmp = (order[a.status] ?? 0).compareTo(order[b.status] ?? 0);
      if (cmp != 0) return cmp;
      return a.habit.name.compareTo(b.habit.name);
    });
    return entries;
  }

  static Set<DateTime> daysWithScheduledHabits(
    List<Habit> habits, {
    DateTime? from,
    DateTime? to,
  }) {
    if (habits.isEmpty) return {};

    final start = from != null ? normalize(from) : today;
    final end =
        to != null ? normalize(to) : start.add(const Duration(days: 365));
    final result = <DateTime>{};

    for (final habit in habits) {
      final d = normalize(habit.scheduledDate);
      if (!d.isBefore(start) && !d.isAfter(end)) {
        result.add(d);
      }
    }
    return result;
  }

  static bool isDayFullyCompleted(List<Habit> habits, DateTime day) {
    final active = habits.where((h) => isHabitActiveOnDay(h, day)).toList();
    if (active.isEmpty) return false;
    return active.every((h) => isCompletedOnDay(h, day));
  }


  static bool isPastDayFullyCompleted(List<Habit> habits, DateTime day) {
    if (!isBeforeDay(day, today)) return false;
    return isDayFullyCompleted(habits, day);
  }

  static bool canToggleOnDay(DateTime day) {
    return isSameDay(day, today);
  }

  static bool canScheduleHabitOn(DateTime date) {
    return !isBeforeDay(date, today);
  }

  static int calculateStreak(List<Habit> habits) {
    if (habits.isEmpty) return 0;

    int streak = 0;
    var day = today;

    while (true) {
      final active = habits.where((h) => isHabitActiveOnDay(h, day)).toList();
      if (active.isEmpty) {
        day = day.subtract(const Duration(days: 1));
        if (day.isBefore(today.subtract(const Duration(days: 3650)))) break;
        continue;
      }
      if (!active.every((h) => isCompletedOnDay(h, day))) {
        if (isSameDay(day, today)) {
          day = day.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
      streak++;
      day = day.subtract(const Duration(days: 1));
      if (streak > 3650) break;
    }
    return streak;
  }
}
