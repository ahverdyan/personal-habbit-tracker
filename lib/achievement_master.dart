import 'package:cloud_firestore/cloud_firestore.dart';

class AchievementMaster {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int order;
  final int targetValue;
  
  AchievementMaster({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.order,
    required this.targetValue,
  });
  
  factory AchievementMaster.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AchievementMaster(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'] ?? '',
      order: data['order'] ?? 0,
      targetValue: data['targetValue'] ?? 1,
    );
  }
}