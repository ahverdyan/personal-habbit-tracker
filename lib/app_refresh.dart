import 'package:flutter/foundation.dart';

class AppRefresh {
  static final ValueNotifier<int> tick = ValueNotifier(0);
  static final ValueNotifier<int> profileTick = ValueNotifier(0);

  static void notify() {
    tick.value++;
  }

  static void notifyProfile() {
    profileTick.value++;
  }
}
