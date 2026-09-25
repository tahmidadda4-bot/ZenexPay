import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../zenex_ui.dart';
import 'transaction_details_page.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  late Future<Map<String, dynamic>?> wallet;
  late Future<List<Map<String, dynamic>>> methodsFuture;
  final amount = TextEditingController();
  String? selectedMethodId;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    wallet = SupabaseService.wallet();
    methodsFuture = SupabaseService.withdrawalMethods();
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  void _reloadMethods() {
    methodsFuture = SupabaseService.withdrawalMethods();
  }

  String _label(Map<String, dynamic> method) {
    final type = '${method['method_type'] ?? ''}'.toLowerCase();
    final name = type == 'bkash'
        ? 'bKash'
        : type == 'nagad'
            ? 'Nagad'
            : 'Bank Account';
    final account = '${method['account_number'] ?? ''}';
    return '$name • $account';
  }

  Future<void> _addOrEditMethod({Map<String, dynamic>? existing}) async {
    final type = existing == null ? 'bkash' : '${existing['method_type']}';
    final controller = TextEditingController(
      text: existing == null ? '' : '${existing['account_number'] ?? ''}',
    );

    String selectedType = type;
    final existingMethods = await methodsFuture;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add withdrawal method' : 'Update withdrawal method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Method'),
                items: const [
                  DropdownMenuItem(value: 'bkash', child: Text('bKash')),
                  DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                ],
                onChanged: existing == null
                    ? (v) => setDialogState(() => selectedType = v ?? 'bkash')
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: selectedType == 'bank'
                    ? TextInputType.number
                    : TextInputType.phone,
                decoration: InputDecoration(
                  labelText: selectedType == 'bank'
                      ? 'Bank account number'
                      : 'Mobile number',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                if (existing == null && existingMethods.any((m) => '${m['method_type']}' == selectedType)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This withdrawal method is already saved. Use Edit selected to change it.')),
                  );
                  return;
                }
                try {
                  await SupabaseService.saveWithdrawalMethod(
                    methodType: selectedType,
                    accountNumber: value,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  final raw = e.toString().toLowerCase();
                  final message = raw.contains('duplicate') ||
                          raw.contains('unique') ||
                          raw.contains('phone')
                      ? 'This mobile number is already used for a withdrawal method.'
                      : 'Could not save this withdrawal method. Please check the details and try again.';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (result == true && mounted) {
      setState(_reloadMethods);
      final refreshed = await methodsFuture;
      if (!mounted) return;
      final saved = refreshed.where((m) => '${m['method_type']}' == selectedType).toList();
      setState(() {
        selectedMethodId = saved.isEmpty ? null : '${saved.first['id']}';
      });
    }
  }

  Future<void> _submit(List<Map<String, dynamic>> methods) async {
    final value = double.tryParse(amount.text.trim());
    if (value == null) {
      _show('Enter a valid withdrawal amount.');
      return;
    }
    if (value < 100) {
      _show('Minimum withdrawal is ৳100.');
      return;
    }
    if (value > 50000) {
      _show('Maximum withdrawal is ৳50,000.');
      return;
    }
    if (selectedMethodId == null) {
      _show('Select a saved withdrawal method first.');
      return;
    }

    setState(() => busy = true);
    try {
      final transaction = await SupabaseService.withdraw(
        amount: value,
        methodId: selectedMethodId!,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionDetailsPage(transaction: transaction),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().toLowerCase();
      final message = raw.contains('insufficient balance') ||
              raw.contains('insufficient_balance')
          ? 'Insufficient balance. Your available balance is not enough for this withdrawal.'
          : raw.contains('minimum withdrawal')
              ? 'Minimum withdrawal is ৳100.'
              : raw.contains('maximum withdrawal')
                  ? 'Maximum withdrawal is ৳50,000.'
                  : raw.contains('pending')
                      ? 'This withdrawal request is already being processed.'
                      : 'We could not process your withdrawal. Please try again.';
      _show(message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: methodsFuture,
        builder: (_, methodSnapshot) {
          if (methodSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (methodSnapshot.hasError) {
            return Center(child: Text('Could not load withdrawal methods.'));
          }

          final methods = methodSnapshot.data ?? [];
          final validSelected = methods.any((m) => '${m['id']}' == selectedMethodId);
          if (!validSelected && selectedMethodId != null) selectedMethodId = null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: wallet,
                builder: (_, snapshot) => _AvailableBalance(value: snapshot.data?['balance']),
              ),
              const SizedBox(height: 18),
              Text('Withdrawal Method', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedMethodId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select saved method',
                  prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                ),
                items: methods
                    .map((method) => DropdownMenuItem<String>(
                          value: '${method['id']}',
                          child: Text(_label(method), overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: busy ? null : (v) => setState(() => selectedMethodId = v),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : () => _addOrEditMethod(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add method'),
                  ),
                  const Spacer(),
                  if (selectedMethodId != null)
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              final selected = methods.firstWhere((m) => '${m['id']}' == selectedMethodId);
                              _addOrEditMethod(existing: selected);
                            },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit selected'),
                    ),
                ],
              ),
              if (methods.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Add a bKash, Nagad or Bank Account before requesting a withdrawal.'),
                ),
              const SizedBox(height: 16),
              Text('Amount', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Enter amount (৳100 – ৳50,000)',
                  prefixText: '৳ ',
                  prefixIcon: Icon(Icons.currency_exchange_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(.72)),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: busy || methods.isEmpty ? null : () => _submit(methods),
                  child: busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Withdraw Request'),
                ),
              ),
              const SizedBox(height: 10),
              Center(child: Text('Minimum ৳100 • Maximum ৳50,000', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(.55), fontSize: 11))),
            ],
          );
        },
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
