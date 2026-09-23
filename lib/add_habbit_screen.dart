import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'habit_service.dart';
import 'calendar_logic.dart';

class AddHabitScreen extends StatefulWidget {
  final DateTime? initialStartDate;

  const AddHabitScreen({super.key, this.initialStartDate});

  @override
  _AddHabitScreenState createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _habitNameController = TextEditingController();
  String _selectedPriority = 'средний';
  bool _isLoading = false;
  late DateTime _startDate;

  final List<Map<String, dynamic>> _priorities = [
    {'value': 'высокий', 'color': Colors.red, 'label': 'Высокий'},
    {'value': 'средний', 'color': Colors.orange, 'label': 'Средний'},
    {'value': 'низкий', 'color': Colors.green, 'label': 'Низкий'},
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialStartDate ?? CalendarLogic.today;
    _startDate = CalendarLogic.canScheduleHabitOn(initial)
        ? CalendarLogic.normalize(initial)
        : CalendarLogic.today;
  }

  Future<void> _pickStartDate() async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    final picked = await showDatePicker(
      context: rootContext,
      initialDate: _startDate,
      firstDate: CalendarLogic.today,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('ru', 'RU'),
      helpText: 'День привычки',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.purple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startDate = CalendarLogic.normalize(picked));
    }
  }

  void _saveHabit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: пользователь не авторизован'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await HabitService().addHabit(
        name: _habitNameController.text.trim(),
        priority: _selectedPriority,
        startDate: _startDate,
      );

      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Привычка «${_habitNameController.text}» создана!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', 'Ошибка: '),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _habitNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_startDate.day}.${_startDate.month}.${_startDate.year}';

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Новая привычка',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Название',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _habitNameController,
                      decoration: InputDecoration(
                        hintText: 'Сделать зарядку',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.purple, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите название привычки';
                        }
                        if (value.length < 2) {
                          return 'Название должно быть длиннее';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    Text(
                      'День начала',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: Icon(Icons.calendar_today, color: Colors.purple),
                      label: Text(
                        dateLabel,
                        style: TextStyle(color: Colors.black87),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48),
                        side: BorderSide(color: Colors.purple.shade200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Твое будущее — в твоих руках',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Приоритет',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: _priorities.map((priority) {
                        bool isSelected =
                            _selectedPriority == priority['value'];
                        return ChoiceChip(
                          label: Text(
                            priority['label'],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : priority['color'],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPriority = priority['value'];
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: priority['color'],
                          side: BorderSide(
                            color: priority['color'],
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveHabit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Добавить',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
