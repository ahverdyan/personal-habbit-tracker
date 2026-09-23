import 'package:cloud_firestore/cloud_firestore.dart';
import 'calendar_logic.dart';
import 'firestore_dates.dart';

class Habit {
  final String id;
  final String name;
  final String priority;
  final bool completed;
  final String userId;
  final DateTime createdAt;
  final DateTime? startDate;
  final List<DateTime> completedDates;

  Habit({
    required this.id,
    required this.name,
    required this.priority,
    required this.completed,
    required this.userId,
    required this.createdAt,
    this.startDate,
    required this.completedDates,
  });


  DateTime get scheduledDate =>
      CalendarLogic.normalize(startDate ?? createdAt);

  DateTime get effectiveStartDate => scheduledDate;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'priority': priority,
      'completed': completed,
      'userId': userId,
      'createdAt': FirestoreDates.toTimestamp(createdAt),
      'startDate': FirestoreDates.toTimestamp(effectiveStartDate),
      'completedDates':
          completedDates.map((date) => FirestoreDates.toTimestamp(date)).toList(),
    };
  }

  factory Habit.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    final createdAt = FirestoreDates.fromTimestamp(
      data['createdAt'] as Timestamp,
    );
    List<dynamic>? completedDatesList =
        data['completedDates'] as List<dynamic>?;
    DateTime? start;
    if (data['startDate'] is Timestamp) {
      start = FirestoreDates.fromTimestamp(data['startDate'] as Timestamp);
    }

    return Habit(
      id: doc.id,
      name: data['name'] ?? '',
      priority: data['priority'] ?? 'средний',
      completed: data['completed'] ?? false,
      userId: data['userId'] ?? '',
      createdAt: createdAt,
      startDate: start,
      completedDates: completedDatesList
              ?.map((item) =>
                  FirestoreDates.fromTimestamp(item as Timestamp))
              .toList() ??
          [],
    );
  }

  Habit copyWith({
    String? name,
    String? priority,
    bool? completed,
    DateTime? startDate,
    List<DateTime>? completedDates,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      userId: userId,
      createdAt: createdAt,
      startDate: startDate ?? this.startDate,
      completedDates: completedDates ?? this.completedDates,
    );
  }
}
