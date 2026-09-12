import 'package:flutter/services.dart';

class AppHaptics {
  static void lightClick() {
    HapticFeedback.selectionClick();
  }

  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  static void mediumImpact() {
    HapticFeedback.lightImpact();
  }

  static void heavyImpact() {
    HapticFeedback.mediumImpact();
  }

  static void successNotification() {
    HapticFeedback.mediumImpact();
  }
}

