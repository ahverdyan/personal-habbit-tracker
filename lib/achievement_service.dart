import 'package:cloud_firestore/cloud_firestore.dart';
import 'achievement_master.dart';
import 'user_achievement.dart';
import 'calendar_logic.dart';
import 'habit_model.dart';
import 'app_refresh.dart';

class AchievementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<UserAchievement>> getUserAchievements(String userId) async {
    try {
      final masterSnapshot = await _firestore
          .collection('achievements')
          .orderBy('order')
          .get();

      if (masterSnapshot.docs.isEmpty) return [];

      final userAchievementsSnapshot = await _firestore
          .collection('user_achievements')
          .where('userId', isEqualTo: userId)
          .get();

      final habitsSnapshot = await _firestore
          .collection('habits')
          .where('userId', isEqualTo: userId)
          .get();

      final habits =
          habitsSnapshot.docs.map((d) => Habit.fromFirestore(d)).toList();

      final storedByAchievementId = <String, UserAchievement>{};
      for (final doc in userAchievementsSnapshot.docs) {
        final ua = UserAchievement.fromFirestore(doc);
        if (ua.isUnlocked) {
          storedByAchievementId[ua.achievementId] = ua;
        }
      }

      final List<UserAchievement> result = [];

      for (final masterDoc in masterSnapshot.docs) {
        final achievementId = masterDoc.id;
        final masterData = AchievementMaster.fromFirestore(masterDoc);
        final computedProgress =
            _computeProgress(achievementId, habits, userId);

        UserAchievement userAchievement;

        if (storedByAchievementId.containsKey(achievementId)) {
          userAchievement = storedByAchievementId[achievementId]!;
          userAchievement.currentProgress = computedProgress;
        } else {
          userAchievement = UserAchievement(
            id: '',
            userId: userId,
            achievementId: achievementId,
            currentProgress: computedProgress,
            isUnlocked: computedProgress >= masterData.targetValue,
            createdAt: DateTime.now(),
          );
        }

        final shouldBeUnlocked =
            computedProgress >= masterData.targetValue;
        if (shouldBeUnlocked && !userAchievement.isUnlocked) {
          userAchievement.isUnlocked = true;
          await _saveUnlockedAchievement(
            userId: userId,
            achievementId: achievementId,
            progress: computedProgress,
          );
          userAchievement.isUnlocked = true;
        }

        userAchievement.masterData = masterData;
        userAchievement.isUnlocked =
            userAchievement.isUnlocked || shouldBeUnlocked;
        userAchievement.currentProgress = computedProgress;
        result.add(userAchievement);
      }

      return result;
    } catch (error) {
      return [];
    }
  }

  int _computeProgress(String achievementId, List<Habit> habits, String userId) {
    switch (achievementId) {
      case 'first_habit':
        return habits.isNotEmpty ? 1 : 0;
      case 'complete_habit':
        return _totalCompletions(habits);
      case 'all_completed':
        return _countPerfectDays(habits);
      default:
        return 0;
    }
  }

  int _totalCompletions(List<Habit> habits) {
    int total = 0;
    for (final h in habits) {
      total += h.completedDates.length;
    }
    return total;
  }

  int _countPerfectDays(List<Habit> habits) {
    if (habits.isEmpty) return 0;

    final scheduledDays = habits
        .map((h) => CalendarLogic.normalize(h.scheduledDate))
        .toSet();

    int perfectDays = 0;
    for (final day in scheduledDays) {
      if (day.isAfter(CalendarLogic.today)) continue;
      if (CalendarLogic.isDayFullyCompleted(habits, day)) {
        perfectDays++;
      }
    }
    return perfectDays;
  }

  Future<void> _saveUnlockedAchievement({
    required String userId,
    required String achievementId,
    required int progress,
  }) async {
    final query = await _firestore
        .collection('user_achievements')
        .where('userId', isEqualTo: userId)
        .where('achievementId', isEqualTo: achievementId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({
        'currentProgress': progress,
        'isUnlocked': true,
        'unlockedAt': FieldValue.serverTimestamp(),
      });
      AppRefresh.notify();
      return;
    }

    await _firestore.collection('user_achievements').add({
      'userId': userId,
      'achievementId': achievementId,
      'currentProgress': progress,
      'isUnlocked': true,
      'unlockedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    AppRefresh.notify();
  }

  Future<void> checkAchievementsAfterHabitChange(String userId) async {
    try {
      final habitsSnapshot = await _firestore
          .collection('habits')
          .where('userId', isEqualTo: userId)
          .get();

      final habits =
          habitsSnapshot.docs.map((d) => Habit.fromFirestore(d)).toList();

      final masterSnapshot = await _firestore.collection('achievements').get();

      for (final masterDoc in masterSnapshot.docs) {
        final achievementId = masterDoc.id;
        final masterData = AchievementMaster.fromFirestore(masterDoc);
        final progress = _computeProgress(achievementId, habits, userId);

        if (progress >= masterData.targetValue) {
          await _saveUnlockedAchievement(
            userId: userId,
            achievementId: achievementId,
            progress: progress,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> checkFirstHabitAchievement(String userId) async {
    await checkAchievementsAfterHabitChange(userId);
  }

  Future<void> checkHabitCompletionAchievement(String userId) async {
    await checkAchievementsAfterHabitChange(userId);
  }

  Future<void> checkAllCompletedAchievement(String userId) async {
    await checkAchievementsAfterHabitChange(userId);
  }
}
