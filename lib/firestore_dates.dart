import 'package:cloud_firestore/cloud_firestore.dart';
import 'calendar_logic.dart';

class FirestoreDates {
  static Timestamp toTimestamp(DateTime date) {
    final n = CalendarLogic.normalize(date);
    return Timestamp.fromDate(DateTime(n.year, n.month, n.day, 12));
  }

  static DateTime fromTimestamp(Timestamp ts) {
    return CalendarLogic.normalize(ts.toDate());
  }
}
