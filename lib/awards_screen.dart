import 'package:flutter/material.dart';
import 'achievement_service.dart';
import 'user_achievement.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_refresh.dart';

class AwardsScreen extends StatefulWidget {
  @override
  _AwardsScreenState createState() => _AwardsScreenState();
}

class _AwardsScreenState extends State<AwardsScreen> {
  final AchievementService _achievementService = AchievementService();
  List<UserAchievement> _achievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    AppRefresh.tick.addListener(_onRefreshTick);
    _loadAchievements();
  }

  @override
  void dispose() {
    AppRefresh.tick.removeListener(_onRefreshTick);
    super.dispose();
  }

  void _onRefreshTick() {
    _loadAchievements(silent: true);
  }

  Future<void> _loadAchievements({bool silent = false}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!silent && mounted) setState(() => _isLoading = true);

    final achievements = await _achievementService.getUserAchievements(userId);

    achievements.sort((a, b) {
      if (a.isUnlocked && !b.isUnlocked) return -1;
      if (!a.isUnlocked && b.isUnlocked) return 1;
      return (a.masterData?.order ?? 0).compareTo(b.masterData?.order ?? 0);
    });

    if (mounted) {
      setState(() {
        _achievements = achievements;
        _isLoading = false;
      });
    }
  }

  Widget _buildAchievementItem(UserAchievement userAchievement) {
    final master = userAchievement.masterData;
    if (master == null) return SizedBox();

    final isUnlocked = userAchievement.isUnlocked;
    final progress = userAchievement.currentProgress;
    final target = master.targetValue;

    return Container(
      margin: EdgeInsets.only(bottom: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isUnlocked ? Colors.green : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Center(
              child: master.icon.isNotEmpty && master.icon.contains('assets/')
                  ? Image.asset(
                      master.icon,
                      width: 35,
                      height: 35,
                      color: isUnlocked ? Colors.green : Colors.grey[500],
                    )
                  : Icon(
                      isUnlocked
                          ? Icons.emoji_events
                          : Icons.emoji_events_outlined,
                      color: isUnlocked ? Colors.green : Colors.grey[500],
                      size: 35,
                    ),
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  master.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isUnlocked ? Colors.green : Colors.black,
                    decoration: isUnlocked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  master.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                if (!isUnlocked)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: target > 0
                            ? (progress / target).clamp(0.0, 1.0)
                            : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.purple),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$progress/$target',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (isUnlocked)
                  Text(
                    '✅ Выполнено',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Center(
          child: Text(
            'Достижения',
            style: TextStyle(
              fontSize: 25,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: Container(
        margin: EdgeInsets.only(top: 30),
        padding: EdgeInsets.only(left: 20, right: 20, top: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.purple))
            : _achievements.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events,
                            size: 60, color: Colors.grey[300]),
                        SizedBox(height: 20),
                        Text(
                          'Нет достижений',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAchievements,
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          ..._achievements.map(_buildAchievementItem).toList(),
                          SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
