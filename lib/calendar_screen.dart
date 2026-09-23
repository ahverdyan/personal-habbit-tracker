import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:pht/habit_service.dart';
import 'package:pht/habit_model.dart';
import 'package:pht/calendar_logic.dart';
import 'package:pht/edit_habit_screen.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  final HabitService _habitService = HabitService();
  List<Habit> _habits = [];
  bool _habitsReady = false;
  StreamSubscription<List<Habit>>? _habitsSub;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _habitsSub?.cancel();
    super.dispose();
  }

  void _selectDay(DateTime day) {
    final normalized = CalendarLogic.normalize(day);
    if (CalendarLogic.isSameDay(normalized, _selectedDay)) return;
    setState(() {
      _selectedDay = normalized;
      _focusedDay = normalized;
    });
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
    } catch (_) {
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

  @override
  Widget build(BuildContext context) {
    final dayEntries = CalendarLogic.habitsForDay(_habits, _selectedDay);
    final listKey = ValueKey(
      '${_selectedDay.year}-${_selectedDay.month}-${_selectedDay.day}',
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Center(
          child: Text(
            'Календарь',
            style: TextStyle(fontSize: 25, color: Colors.white),
          ),
        ),
      ),
      body: !_habitsReady
          ? Center(child: CircularProgressIndicator(color: Colors.purple))
          : Container(
              margin: EdgeInsets.only(top: 30),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  TableCalendar(
                    locale: 'ru_RU',
                    firstDay: DateTime.utc(2024, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        CalendarLogic.isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      _selectDay(selectedDay);
                    },
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    calendarBuilders: CalendarBuilders(
                      todayBuilder: (context, day, _) => _buildDayCell(
                        day,
                        isToday: true,
                        isSelected: CalendarLogic.isSameDay(day, _selectedDay),
                      ),
                      selectedBuilder: (context, day, _) => _buildDayCell(
                        day,
                        isToday: CalendarLogic.isSameDay(day, CalendarLogic.today),
                        isSelected: true,
                      ),
                      defaultBuilder: (context, day, _) =>
                          _buildDayCell(day),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Привычки за ${_selectedDay.day}.${_selectedDay.month}.${_selectedDay.year}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: dayEntries.isEmpty
                          ? Center(
                              key: listKey,
                              child: Text(
                                'Нет привычек на этот день',
                                style: TextStyle(color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              key: listKey,
                              itemCount: dayEntries.length,
                              itemBuilder: (context, index) {
                                return _buildHabitTile(dayEntries[index]);
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDayCell(
    DateTime day, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    final pastAllDone =
        CalendarLogic.isPastDayFullyCompleted(_habits, day);

    Color bg;
    Color textColor;

    if (isToday) {
      bg = Colors.deepPurple;
      textColor = Colors.white;
    } else if (isSelected) {
      bg = Colors.purple.shade200;
      textColor = Colors.white;
    } else if (pastAllDone) {
      bg = Colors.green;
      textColor = Colors.white;
    } else {
      bg = Colors.transparent;
      textColor = Colors.black;
    }

    return Container(
      margin: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHabitTile(HabitDayEntry entry) {
    final habit = entry.habit;
    final isDone = entry.status == HabitDayStatus.completed;

    final card = Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onLongPress: () => _openEditHabit(habit),
              child: Text(
                habit.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  decoration: isDone
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: Colors.grey,
                  color: isDone ? Colors.grey[600] : Colors.black87,
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDone ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isDone ? 'Выполнено' : 'Не выполнено',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey[700]),
            onPressed: () => _openEditHabit(habit),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );

    return Dismissible(
      key: Key('cal-${habit.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: 20),
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        margin: EdgeInsets.only(bottom: 12),
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
            content: Text('«${habit.name}» будет удалена.'),
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
}
