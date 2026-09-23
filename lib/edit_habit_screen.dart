import 'package:flutter/material.dart';
import 'habit_model.dart';
import 'habit_service.dart';
import 'calendar_logic.dart';

class EditHabitScreen extends StatefulWidget {
  final Habit habit;

  const EditHabitScreen({required this.habit});

  @override
  _EditHabitScreenState createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends State<EditHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedPriority;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _priorities = [
    {'value': 'высокий', 'color': Colors.red, 'label': 'Высокий'},
    {'value': 'средний', 'color': Colors.orange, 'label': 'Средний'},
    {'value': 'низкий', 'color': Colors.green, 'label': 'Низкий'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.habit.name);
    _selectedPriority = widget.habit.priority;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await HabitService().updateHabit(
        habit: widget.habit,
        name: _nameController.text.trim(),
        priority: _selectedPriority,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = CalendarLogic.normalize(widget.habit.effectiveStartDate);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Редактировать',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'Старт: ${start.day}.${start.month}.${start.year}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Название',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 2) {
                          return 'Минимум 2 символа';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    Text('Приоритет',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: _priorities.map((p) {
                        final selected = _selectedPriority == p['value'];
                        return ChoiceChip(
                          label: Text(p['label']),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _selectedPriority = p['value']);
                          },
                          selectedColor: p['color'],
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : p['color'],
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Сохранить',
                                style: TextStyle(
                                  color: Colors.white,
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
