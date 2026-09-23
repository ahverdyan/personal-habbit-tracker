
import 'package:cloud_firestore/cloud_firestore.dart';
import 'achievement_master.dart';

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class UserAchievement {
  final String id;
  final String userId;
  final String achievementId;
  int currentProgress;
  bool isUnlocked;
  DateTime? unlockedAt;
  DateTime createdAt;
  
  AchievementMaster? masterData;
  
  UserAchievement({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.currentProgress,
    required this.isUnlocked,
    this.unlockedAt,
    required this.createdAt,
  });
  
  factory UserAchievement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserAchievement(
      id: doc.id,
      userId: data['userId'] ?? '',
      achievementId: data['achievementId'] ?? '',
      currentProgress: (data['currentProgress'] ?? 0) as int,
      isUnlocked: (data['isUnlocked'] ?? false) as bool,
      unlockedAt: data.containsKey('unlockedAt') 
          ? (data['unlockedAt'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}