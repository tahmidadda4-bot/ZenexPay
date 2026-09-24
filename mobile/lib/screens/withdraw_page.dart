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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
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
          const Text('Select Method', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _Method(value: 'bkash', title: 'bKash', icon: Icons.account_balance_wallet_rounded, selected: method == 'bkash', onTap: () => setState(() => method = 'bkash')),
          const SizedBox(height: 8),
          _Method(value: 'nagad', title: 'Nagad', icon: Icons.payments_rounded, selected: method == 'nagad', onTap: () => setState(() => method = 'nagad')),
          const SizedBox(height: 8),
          _Method(value: 'bank', title: 'Bank Transfer', icon: Icons.account_balance_rounded, selected: method == 'bank', onTap: () => setState(() => method = 'bank')),
          const SizedBox(height: 20),
          const Text('Amount', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          TextField(
            controller: amount,
            enabled: !busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter amount',
              prefixText: '৳ ',
              prefixIcon: Icon(Icons.currency_exchange_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: account,
            enabled: !busy,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: method == 'bank' ? 'Bank account number' : 'Mobile account number',
              prefixIcon: const Icon(Icons.credit_card_rounded),
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
          const Center(child: Text('Processing time may vary by payment method.', style: TextStyle(color: Colors.white54, fontSize: 11))),
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
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? kBlue.withOpacity(.12) : kSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? kBlue : Colors.white.withOpacity(.07)),
          ),
          child: Row(
            children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: kPurple.withOpacity(.14), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: kPurple)),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? kBlue : Colors.white38),
            ],
          ),
        ),
      );
}
