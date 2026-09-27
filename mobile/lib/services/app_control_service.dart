import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppControl {
  final bool maintenanceMode;
  final String maintenanceMessage;
  final String minimumAppVersion;
  final String latestAppVersion;
  final bool forceUpdate;
  final bool withdrawalsEnabled;
  final bool registrationEnabled;
  final bool taskSystemEnabled;
  final bool dailyCheckinEnabled;
  final bool dailyMissionsEnabled;
  final bool referralSystemEnabled;
  final bool supportEnabled;
  final double minimumWithdrawal;
  final double maximumWithdrawal;
  final double dailyWithdrawalLimit;

  const AppControl({
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.minimumAppVersion,
    required this.latestAppVersion,
    required this.forceUpdate,
    required this.withdrawalsEnabled,
    required this.registrationEnabled,
    required this.taskSystemEnabled,
    required this.dailyCheckinEnabled,
    required this.dailyMissionsEnabled,
    required this.referralSystemEnabled,
    required this.supportEnabled,
    required this.minimumWithdrawal,
    required this.maximumWithdrawal,
    required this.dailyWithdrawalLimit,
  });

  factory AppControl.defaults() => const AppControl(
        maintenanceMode: false,
        maintenanceMessage: 'System maintenance is in progress. Please try again later.',
        minimumAppVersion: '1.0.0',
        latestAppVersion: '1.0.0',
        forceUpdate: false,
        withdrawalsEnabled: true,
        registrationEnabled: true,
        taskSystemEnabled: true,
        dailyCheckinEnabled: true,
        dailyMissionsEnabled: true,
        referralSystemEnabled: true,
        supportEnabled: true,
        minimumWithdrawal: 100,
        maximumWithdrawal: 50000,
        dailyWithdrawalLimit: 100000,
      );

  static AppControl fromRows(List<Map<String, dynamic>> rows) {
    final values = <String, dynamic>{};
    for (final row in rows) {
      values['${row['key']}'] = row['value'];
    }

    dynamic value(String key, dynamic fallback) => values[key] ?? fallback;
    dynamic decodeStored(dynamic v) {
      if (v is String) {
        final text = v.trim();
        if (text.isEmpty) return text;
        try {
          return jsonDecode(text);
        } catch (_) {
          return v;
        }
      }
      return v;
    }

    bool boolValue(String key, bool fallback) {
      final v = decodeStored(value(key, fallback));
      if (v is bool) return v;
      return '$v'.toLowerCase() == 'true';
    }

    double numberValue(String key, double fallback) {
      final v = decodeStored(value(key, {'amount': fallback}));
      if (v is Map && v['amount'] != null) return double.tryParse('${v['amount']}') ?? fallback;
      return double.tryParse('$v') ?? fallback;
    }

    String stringValue(String key, String fallback) {
      final v = decodeStored(value(key, fallback));
      if (v is Map && v['value'] != null) return '${v['value']}';
      return '$v';
    }

    return AppControl(
      maintenanceMode: boolValue('maintenance_mode', false),
      maintenanceMessage: stringValue(
        'maintenance_message',
        'System maintenance is in progress. Please try again later.',
      ),
      minimumAppVersion: stringValue('minimum_app_version', '1.0.0'),
      latestAppVersion: stringValue('latest_app_version', '1.0.0'),
      forceUpdate: boolValue('force_update', false),
      withdrawalsEnabled: boolValue('withdrawals_enabled', true),
      registrationEnabled: boolValue('new_registrations_enabled', true),
      taskSystemEnabled: boolValue('task_system_enabled', true),
      dailyCheckinEnabled: boolValue('daily_checkin_enabled', true),
      dailyMissionsEnabled: boolValue('daily_missions_enabled', true),
      referralSystemEnabled: boolValue('referral_system_enabled', true),
      supportEnabled: boolValue('support_enabled', true),
      minimumWithdrawal: numberValue('minimum_withdrawal', 100),
      maximumWithdrawal: numberValue('maximum_withdrawal', 50000),
      dailyWithdrawalLimit: numberValue('daily_withdrawal_limit', 100000),
    );
  }

  bool requiresUpdate(String currentVersion) {
    if (!forceUpdate) return false;
    return _compareVersions(currentVersion, minimumAppVersion) < 0;
  }

  static int _compareVersions(String a, String b) {
    final ap = a.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final bp = b.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final av = i < ap.length ? ap[i] : 0;
      final bv = i < bp.length ? bp[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}

class AppControlService {
  static final client = Supabase.instance.client;

  static Future<AppControl> load() async {
    final data = await client.from('app_settings').select('key,value');
    return AppControl.fromRows(List<Map<String, dynamic>>.from(data));
  }

  static Future<bool> featureEnabled(String key, {bool fallback = true}) async {
    try {
      final row = await client.from('app_settings').select('value').eq('key', key).maybeSingle();
      final value = row?['value'];
      if (value is bool) return value;
      return value == null ? fallback : '$value'.toLowerCase() == 'true';
    } catch (_) {
      return fallback;
    }
  }
}

class AppControlGate extends StatefulWidget {
  final Widget child;
  final String currentVersion;

  const AppControlGate({
    super.key,
    required this.child,
    required this.currentVersion,
  });

  @override
  State<AppControlGate> createState() => _AppControlGateState();
}

class _AppControlGateState extends State<AppControlGate> {
  AppControl? control;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await AppControlService.load();
      if (mounted) setState(() => control = result);
    } catch (e) {
      // A control-plane outage must not lock existing users out of the app.
      if (mounted) setState(() => control = AppControl.defaults());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = control;
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (c.maintenanceMode) {
      return _ControlPage(
        icon: Icons.build_circle_outlined,
        title: 'System Maintenance',
        message: c.maintenanceMessage,
        buttonText: 'Try Again',
        onPressed: () {
          setState(() => control = null);
          _load();
        },
      );
    }

    if (c.requiresUpdate(widget.currentVersion)) {
      return _ControlPage(
        icon: Icons.system_update_alt_rounded,
        title: 'Update Required',
        message: 'A newer version of ZenexPay is required. Please update the app to continue.',
        buttonText: 'Check Again',
        onPressed: () {
          setState(() => control = null);
          _load();
        },
      );
    }

    return widget.child;
  }
}

class _ControlPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  const _ControlPage({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 74, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 20),
                  Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.5)),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: onPressed, child: Text(buttonText)),
                ],
              ),
            ),
          ),
        ),
      );
}
