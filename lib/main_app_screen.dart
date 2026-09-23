import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pht/awards_screen.dart';
import 'package:pht/calendar_screen.dart';
import 'package:pht/settings_screen.dart';
import 'package:pht/profile_settings_screen.dart';
import 'add_habbit_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'habit_service.dart';
import 'habit_model.dart';
import 'calendar_logic.dart';
import 'edit_habit_screen.dart';
import 'user_service.dart';
import 'app_refresh.dart';

class MainAppScreen extends StatefulWidget {
  @override
  _MainAppScreenState createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _selectedIndex = 0;
  final GlobalKey<_HomeScreenState> _homeKey = GlobalKey<_HomeScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _homeKey),
      CalendarScreen(),
      Container(),
      AwardsScreen(),
      SettingsScreen(),
    ];
    UserService().ensureUserProfileExists();
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      _showAddScreen(context);
    } else {
      setState(() {
        _selectedIndex = index;
      });
      if (index == 3) {
        AppRefresh.notify();
      }
    }
  }

  void _showAddScreen(BuildContext context) {
    final selectedDay =
        _homeKey.currentState?.selectedDay ?? CalendarLogic.today;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: AddHabitScreen(initialStartDate: selectedDay),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Container(padding: EdgeInsets.only(top: 15), child: Icon(Icons.home, size: 25)),
            activeIcon: Container(padding: EdgeInsets.only(top: 15), child: Icon(Icons.home, size: 32)),
            label: ''
          ),
          BottomNavigationBarItem(
            icon: Container(padding: EdgeInsets.only(top: 15), child: Icon(Icons.calendar_month_sharp, size: 25)),
            activeIcon: Container(padding: EdgeInsets.only(top: 15), child: Icon(Icons.calendar_month_sharp, size: 32)),
            label: ''
          ),
          BottomNavigationBarItem(
            icon: CircleAvatar(radius: 27.5, backgroundImage: AssetImage('assets/botnavigation/add.png')),
            label: ''
          ),
          BottomNavigationBarItem(
            icon: Container(padding: EdgeInsets.only(top: 15), child: Icon(Icons.checklist, size: 25)),
            activeIcon: Container(padding: EdgeInsets.only(top: 15), child: Icon(Icons.checklist, size: 32)),
            label: ''
          ),
          BottomNavigationBarItem(
            icon: Container(padding: EdgeInsets.only(top: 15), child: Icon(Icons.settings, size: 25)),
            activeIcon: Container(padding: EdgeInsets.only(top: 15), child: Icon(Icons.settings, size: 32)),
            label: ''
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime get selectedDay => _selectedDay;
  final HabitService _habitService = HabitService();
  String _userName = '';
  bool _isLoadingName = true;

  DateTime _selectedDay = DateTime.now();
  late final DateTime _today;
  late final List<DateTime> _weekDays;

  List<Habit> _habits = [];
  bool _habitsReady = false;
  StreamSubscription<List<Habit>>? _habitsSub;
  VoidCallback? _profileRefreshListener;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _selectedDay = CalendarLogic.normalize(_today);

    _weekDays = List.generate(5, (index) {
      return CalendarLogic.normalize(_today.add(Duration(days: index - 2)));
    });

    _habitsSub = _habitService.getHabitsStream().listen(
      (habits) {
        if (mounted) {
          setState(() {
            _habits = habits;
            _habitsReady = true;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _habitsReady = true);
      },
    );

    _profileRefreshListener = () => _loadUserName();
    AppRefresh.profileTick.addListener(_profileRefreshListener!);

    _loadUserName();
  }

  @override
  void dispose() {
    _habitsSub?.cancel();
    if (_profileRefreshListener != null) {
      AppRefresh.profileTick.removeListener(_profileRefreshListener!);
    }
    super.dispose();
  }

  Future<void> _openProfile() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileSettingsScreen(),
      ),
    );

    if (!mounted) return;

    if (result != null && result.isNotEmpty) {
      setState(() => _userName = result);
    } else {
      await _loadUserName();
    }
  }

  void _selectDay(DateTime day) {
    final normalized = CalendarLogic.normalize(day);
    if (CalendarLogic.isSameDay(normalized, _selectedDay)) return;
    setState(() => _selectedDay = normalized);
  }

  String _getWeekdayShort(int weekday) {
    switch (weekday) {
      case 1:
        return 'ПН';
      case 2:
        return 'ВТ';
      case 3:
        return 'СР';
      case 4:
        return 'ЧТ';
      case 5:
        return 'ПТ';
      case 6:
        return 'СБ';
      case 7:
        return 'ВС';
      default:
        return '';
    }
  }

  List<Habit> _habitsForSelectedDay(List<Habit> habits) {
    return habits
        .where((h) => CalendarLogic.isHabitActiveOnDay(h, _selectedDay))
        .toList();
  }


  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _userName = 'Гость';
        _isLoadingName = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final name = data['name'] as String?;

        if (name != null && name.isNotEmpty) {
          setState(() {
            _userName = name;
            _isLoadingName = false;
          });
          return;
        }
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final name = data['name'] as String?;

        if (name != null && name.isNotEmpty) {
          setState(() {
            _userName = name;
            _isLoadingName = false;
          });
          return;
        }
      }

      setState(() {
        _userName =  'Гость';
        _isLoadingName = false;
      });

    } catch (error) {
      print('Ошибка загрузки имени: $error');
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _userName =  'Гость';
        _isLoadingName = false;
      });
    }
  }

  void _toggleHabitCompletion(Habit habit) async {
    if (!CalendarLogic.isSameDay(_selectedDay, CalendarLogic.today)) return;
    try {
      await _habitService.toggleHabitCompletion(habit, _selectedDay);
    } catch (error) {
      print('Ошибка при обновлении привычки: $error');
    }
  }

  Future<void> _deleteHabit(Habit habit) async {
    try {
      await _habitService.deleteHabit(habit.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Привычка «${habit.name}» удалена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openEditHabit(Habit habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: EditHabitScreen(habit: habit),
      ),
    );
  }

  int _getPriorityValue(String priority) {
    switch (priority) {
      case 'высокий':
        return 3;
      case 'средний':
        return 2;
      case 'низкий':
        return 1;
      default:
        return 0;
    }
  }

  List<Habit> _sortHabitsByPriority(List<Habit> habits) {
    habits.sort((a, b) {
      final aDone = CalendarLogic.isCompletedOnDay(a, _selectedDay);
      final bDone = CalendarLogic.isCompletedOnDay(b, _selectedDay);
      if (aDone && !bDone) return 1;
      if (!aDone && bDone) return -1;

      int priorityCompare = _getPriorityValue(b.priority).compareTo(_getPriorityValue(a.priority));
      if (priorityCompare != 0) return priorityCompare;

      return b.createdAt.compareTo(a.createdAt);
    });

    return habits;
  }

  Widget _buildTopStats(List<Habit> dayHabits) {
    int completedCount = dayHabits
        .where((h) => CalendarLogic.isCompletedOnDay(h, _selectedDay))
        .length;
    int totalCount = dayHabits.length;
    double progress = totalCount == 0 ? 0.0 : completedCount / totalCount;
    int percentage = (progress * 100).round();

    return Container(
      padding: EdgeInsets.fromLTRB(25, 25, 25, 25),
      decoration: BoxDecoration(
        color: Colors.black,
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey('progress-$percentage'),
            tween: Tween<double>(
              begin: 0,
              end: progress,
            ),
            duration: Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: value == 0
                        ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white10,
                      ),
                    )
                        : CircularProgressIndicator(
                      value: value,
                      strokeWidth: 6,
                      backgroundColor: Colors.white10,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                  ),

                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),

          SizedBox(width: 50),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Задач выполнено',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '${completedCount} из ${totalCount}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 25, 20, 25),
      decoration: BoxDecoration(
        color: Colors.black,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _weekDays.map((day) {
          final isSelected = CalendarLogic.isSameDay(_selectedDay, day);
          final isToday = CalendarLogic.isSameDay(day, CalendarLogic.today);

          return GestureDetector(
            onTap: () => _selectDay(day),
            child: _buildDayItem(
              day.day.toString(),
              _getWeekdayShort(day.weekday),
              isSelected: isSelected,
              isToday: isToday,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayItem(String day, String weekday,
      {bool isSelected = false, bool isToday = false}) {
    return Column(
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.purple
                : isToday
                    ? Colors.deepPurple.withOpacity(0.35)
                    : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? Colors.purple
                  : isToday
                      ? Colors.deepPurple
                      : Colors.grey[700]!,
              width: isToday && !isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          weekday,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(String priority) {
    return priority == 'высокий'
        ? Colors.red
        : priority == 'средний'
        ? Colors.orange
        : Colors.green;
  }

  Widget _buildHabitItem(Habit habit) {
    final status = CalendarLogic.getHabitStatus(habit, _selectedDay);
    final isCompleted = status == HabitDayStatus.completed;
    final isMissed = status == HabitDayStatus.missed;
    final isViewingToday =
        CalendarLogic.isSameDay(_selectedDay, CalendarLogic.today);
    Color priorityColor = _getPriorityColor(habit.priority);

    final card = Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMissed
            ? Colors.red.shade50
            : isCompleted
                ? Colors.green.shade50
                : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.all(
          color: isMissed
              ? Colors.red.shade200
              : isCompleted
                  ? Colors.green.shade300
                  : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (isViewingToday)
            GestureDetector(
              onTap: () => _toggleHabitCompletion(habit),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? Colors.green : Colors.transparent,
                  border: Border.all(
                    color: isCompleted
                        ? Colors.green
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, color: Colors.white, size: 24)
                      : SizedBox(),
                ),
              ),
            )
          else
            SizedBox(width: 8),

          SizedBox(width: isViewingToday ? 16 : 8),

          Expanded(
            child: GestureDetector(
              onLongPress: () => _openEditHabit(habit),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: TextStyle(
                    color: isMissed
                        ? Colors.red.shade700
                        : isCompleted
                            ? Colors.green.shade800
                            : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    decoration: isCompleted || isMissed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor:
                        isMissed ? Colors.red : Colors.green.shade600,
                    decorationThickness: 2,
                  ),
                ),

                SizedBox(height: 6),

                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.shade100
                        : priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCompleted
                          ? Colors.green.shade400
                          : priorityColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    habit.priority,
                    style: TextStyle(
                      color: isCompleted
                          ? Colors.green.shade800
                          : priorityColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),

          IconButton(
            icon: Icon(Icons.edit_outlined, color: Colors.grey[600], size: 22),
            onPressed: () => _openEditHabit(habit),
            tooltip: 'Редактировать',
          ),
        ],
      ),
    );

    return Dismissible(
      key: Key(habit.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: 20),
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Удалить привычку?'),
            content: Text('«${habit.name}» будет удалена безвозвратно.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Удалить', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteHabit(habit),
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            GestureDetector(
              onTap: _openProfile,
              child: CircleAvatar(
                backgroundImage: AssetImage('assets/icon.png'),
                radius: 24,
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoadingName ? '' : _userName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Рады вас видеть!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: !_habitsReady
          ? Center(child: CircularProgressIndicator(color: Colors.purple))
          : Builder(builder: (context) {
          final dayHabits = _habitsForSelectedDay(_habits);
          final sortedHabits = _sortHabitsByPriority(List.from(dayHabits));
          final listKey = ValueKey(
            '${_selectedDay.year}-${_selectedDay.month}-${_selectedDay.day}',
          );

          return Column(
            children: [
              Column(
                children: [
                  _buildTopStats(dayHabits),
                  _buildWeekCalendar(),
                ],
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Твои привычки',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'На день: ${dayHabits.length}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: dayHabits.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_task,
                                      size: 60,
                                      color: Colors.grey[300],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      _habits.isEmpty
                                          ? 'Нет привычек'
                                          : 'Нет привычек на этот день',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 18,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      _habits.isEmpty
                                          ? 'Нажмите «+», чтобы добавить первую привычку'
                                          : 'Выберите другой день или добавьте новую привычку',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : AnimatedSwitcher(
                                duration: Duration(milliseconds: 180),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: ListView.builder(
                                  key: listKey,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  itemCount: sortedHabits.length,
                                  itemBuilder: (context, index) {
                                    return _buildHabitItem(sortedHabits[index]);
                                  },
                                )
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
    );
  }
}