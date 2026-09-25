import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// Keeps the whole app behind a connection gate.
///
/// The app is usable only while the configured backend is reachable. When the
/// connection disappears during use, the current UI is covered immediately
/// after the next check and is restored automatically when connectivity returns.
class InternetConnectionGate extends StatefulWidget {
  final Widget child;

  const InternetConnectionGate({super.key, required this.child});

  @override
  State<InternetConnectionGate> createState() => _InternetConnectionGateState();
}

class _InternetConnectionGateState extends State<InternetConnectionGate>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = true;
  bool _online = false;
  bool _requestInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNow();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _checkNow());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNow();
    }
  }

  Future<bool> _hasInternet() async {
    final uri = Uri.tryParse(AppConfig.supabaseUrl);
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host;

    try {
      final addresses = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      if (addresses.isEmpty) return false;

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3)
        ..idleTimeout = const Duration(seconds: 3)
        ..badCertificateCallback = (_, __, ___) => false;

      try {
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 4));
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close().timeout(const Duration(seconds: 4));
        await response.drain<void>();
        // Any HTTP response means the device can reach the backend host.
        return response.statusCode > 0;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkNow() async {
    if (_requestInProgress || !mounted) return;
    _requestInProgress = true;

    final result = await _hasInternet();
    if (mounted) {
      setState(() {
        _online = result;
        _checking = false;
      });
    }

    _requestInProgress = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showGate = _checking || !_online;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_online && !_checking) widget.child,
        if (showGate) const _OfflineScreen(),
      ],
    );
  }
}

class _OfflineScreen extends StatelessWidget {
  const _OfflineScreen();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF070B14) : const Color(0xFFF5F7FB);
    final foreground = dark ? Colors.white : const Color(0xFF111827);
    final muted = dark ? Colors.white70 : Colors.black54;

    return Material(
      color: background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 42,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 22),
                CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Please connect to internet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Internet not connected',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Text(
                  'ZenexPay will continue automatically when your internet connection is restored.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
