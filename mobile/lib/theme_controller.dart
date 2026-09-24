import 'package:flutter/material.dart';

/// ZenexPay keeps the premium dark theme as the default.
/// Screens can still switch to light mode from Profile/Settings.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.dark);
