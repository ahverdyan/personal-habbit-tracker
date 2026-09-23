import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'calendar_logic.dart';
import 'ru_date_format.dart';

Future<DateTime?> showRuDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = 'Выберите дату',
}) {
  DateTime selected = CalendarLogic.normalize(initialDate);
  DateTime focused = selected;

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(helpText, style: TextStyle(fontSize: 18)),
            content: SizedBox(
              width: 340,
              child: TableCalendar(
                locale: 'ru_RU',
                firstDay: CalendarLogic.normalize(firstDate),
                lastDay: CalendarLogic.normalize(lastDate),
                focusedDay: focused,
                selectedDayPredicate: (day) =>
                    CalendarLogic.isSameDay(day, selected),
                onDaySelected: (newSelected, newFocused) {
                  setDialogState(() {
                    selected = CalendarLogic.normalize(newSelected);
                    focused = newFocused;
                  });
                },
                onPageChanged: (newFocused) {
                  setDialogState(() => focused = newFocused);
                },
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Месяц',
                },
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.purple),
                  rightChevronIcon:
                      Icon(Icons.chevron_right, color: Colors.purple),
                ),
                calendarBuilders: CalendarBuilders(
                  headerTitleBuilder: (context, day) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        RuDateFormat.monthYear(day),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(color: Colors.white),
                  selectedDecoration: BoxDecoration(
                    color: Colors.purple.shade300,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(color: Colors.white),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: Text('Выбрать', style: TextStyle(color: Colors.purple)),
              ),
            ],
          );
        },
      );
    },
  );
}
