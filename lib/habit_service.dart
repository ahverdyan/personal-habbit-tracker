import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'habit_model.dart';
import 'achievement_service.dart';
import 'calendar_logic.dart';
import 'firestore_dates.dart';
import 'app_refresh.dart';

class HabitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Habit>> getHabitsStream() {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('habits')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList();
    });
  }

  Future<void> addHabit({
    required String name,
    required String priority,
    DateTime? startDate,
  }) async {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final effectiveStart = CalendarLogic.normalize(
      startDate ?? DateTime.now(),
    );

    if (!CalendarLogic.canScheduleHabitOn(effectiveStart)) {
      throw Exception('Нельзя запланировать привычку на прошедшую дату');
    }

    final existingHabits = await _firestore
        .collection('habits')
        .where('userId', isEqualTo: userId)
        .get();

    final isFirstHabit = existingHabits.docs.isEmpty;
    final now = DateTime.now();

    final newHabit = Habit(
      id: '',
      name: name,
      priority: priority,
      completed: false,
      userId: userId,
      createdAt: now,
      startDate: effectiveStart,
      completedDates: [],
    );

    await _firestore.collection('habits').add(newHabit.toMap());

    try {
      await AchievementService().checkAchievementsAfterHabitChange(userId);
      AppRefresh.notify();
    } catch (e) {
      print('Ошибка проверки ачивки при создании привычки: $e');
    }
  }

  Future<void> updateHabit({
    required Habit habit,
    required String name,
    required String priority,
    DateTime? startDate,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final updates = <String, dynamic>{
      'name': name.trim(),
      'priority': priority,
    };

    if (startDate != null) {
      final normalized = CalendarLogic.normalize(startDate);
      if (!CalendarLogic.canScheduleHabitOn(normalized)) {
        throw Exception('Нельзя установить дату старта в прошлом');
      }
      updates['startDate'] = FirestoreDates.toTimestamp(normalized);
    }

    await _firestore.collection('habits').doc(habit.id).update(updates);
    AppRefresh.notify();
  }

  Future<void> deleteHabit(String habitId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('habits').doc(habitId).delete();

    try {
      await AchievementService().checkAchievementsAfterHabitChange(userId);
      AppRefresh.notify();
    } catch (_) {}
  }

  Future<void> toggleHabitCompletion(Habit habit, DateTime day) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    if (!CalendarLogic.canToggleOnDay(day)) return;
    if (!CalendarLogic.isHabitActiveOnDay(habit, day)) return;

    final normalizedDay = CalendarLogic.normalize(day);
    final isCurrentlyDone = CalendarLogic.isCompletedOnDay(habit, normalizedDay);

    List<DateTime> newCompletedDates = List.from(habit.completedDates);

    if (isCurrentlyDone) {
      newCompletedDates.removeWhere(
        (date) => CalendarLogic.isSameDay(date, normalizedDay),
      );
    } else {
      newCompletedDates.add(normalizedDay);
    }

    final today = CalendarLogic.today;
    final completedToday = newCompletedDates.any(
      (d) => CalendarLogic.isSameDay(d, today),
    );

    await _firestore.collection('habits').doc(habit.id).update({
      'completed': completedToday,
      'completedDates': newCompletedDates
          .map((date) => FirestoreDates.toTimestamp(date))
          .toList(),
    });

    try {
      await AchievementService().checkAchievementsAfterHabitChange(userId);
      AppRefresh.notify();
    } catch (e) {
      print('Ошибка проверки ачивки: $e');
    }
  }
}
