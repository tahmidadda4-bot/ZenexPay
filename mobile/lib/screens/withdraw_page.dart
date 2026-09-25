import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../zenex_ui.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  late Future<Map<String, dynamic>?> wallet;
  final amount = TextEditingController();
  final account = TextEditingController();
  String method = 'bkash';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    wallet = SupabaseService.wallet();
  }

  @override
  void dispose() {
    amount.dispose();
    account.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = double.tryParse(amount.text.trim());
    if (value == null || value <= 0 || account.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount and account number.')),
      );
      return;
    }

    setState(() => busy = true);
    try {
      await SupabaseService.withdraw(
        amount: value,
        method: method,
        account: account.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal request submitted.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      // Never expose raw Supabase/PostgREST/PostgreSQL exceptions to users.
      // Convert the backend's insufficient-balance error into a clear,
      // user-friendly message instead.
      final raw = e.toString().toLowerCase();
      final isInsufficientBalance =
          raw.contains('insufficient balance') ||
          raw.contains('p0001') ||
          raw.contains('insufficient_balance');

      final message = isInsufficientBalance
          ? 'Insufficient balance. Your available balance is not enough for this withdrawal.'
          : 'We could not process your withdrawal. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: wallet,
            builder: (_, snapshot) => _AvailableBalance(value: snapshot.data?['balance']),
          ),
          const SizedBox(height: 18),
          Text('Select Method', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _Method(value: 'bkash', title: 'bKash', icon: Icons.account_balance_wallet_rounded, selected: method == 'bkash', onTap: () => setState(() => method = 'bkash')),
          const SizedBox(height: 8),
          _Method(value: 'nagad', title: 'Nagad', icon: Icons.payments_rounded, selected: method == 'nagad', onTap: () => setState(() => method = 'nagad')),
          const SizedBox(height: 8),
          _Method(value: 'bank', title: 'Bank Transfer', icon: Icons.account_balance_rounded, selected: method == 'bank', onTap: () => setState(() => method = 'bank')),
          const SizedBox(height: 20),
          Text('Amount', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          TextField(
            controller: amount,
            enabled: !busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Enter amount',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(.55)),
              prefixText: '৳ ',
              prefixStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              prefixIcon: Icon(Icons.currency_exchange_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(.72)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: account,
            enabled: !busy,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: method == 'bank' ? 'Bank account number' : 'Mobile account number',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(.55)),
              prefixIcon: Icon(Icons.credit_card_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(.72)),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: busy ? null : _submit,
              child: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Withdraw'),
            ),
          ),
          const SizedBox(height: 10),
          Center(child: Text('Processing time may vary by payment method.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(.55), fontSize: 11))),
        ],
      ),
    );
  }
}

class _AvailableBalance extends StatelessWidget {
  final dynamic value;
  const _AvailableBalance({required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF111B38), Color(0xFF1B2460)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kBlue.withOpacity(.28)),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: kBlue),
            const SizedBox(width: 12),
            const Expanded(child: Text('Available Balance', style: TextStyle(color: Colors.white70))),
            Text('৳ ${zenexMoney(value)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _Method extends StatelessWidget {
  final String value;
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Method({required this.value, required this.title, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? kBlue.withOpacity(.12) : scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? kBlue : scheme.outlineVariant.withOpacity(.45)),
        ),
        child: Row(
          children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: kPurple.withOpacity(.14), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: kPurple)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800))),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? kBlue : scheme.onSurface.withOpacity(isDark ? .38 : .45)),
          ],
        ),
      ),
    );
  }
}
