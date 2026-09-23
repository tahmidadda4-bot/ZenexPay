import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});
  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  late Future<ReferralInfo> future;
  final claim = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = SupabaseService.referralInfo();
  }

  @override
  void dispose() {
    claim.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final code = claim.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => busy = true);
    try {
      await SupabaseService.claimReferral(code);
      claim.clear();
      setState(() => future = SupabaseService.referralInfo());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Referral code applied.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: const Text('Referral Center',
              style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: FutureBuilder<ReferralInfo>(
          future: future,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) return Center(child: Text('${s.error}'));
            final r = s.data!;
            
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF111827), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.people_alt_rounded,
                          color: Colors.white, size: 34),
                      const SizedBox(height: 12),
                      const Text('Invite & grow together',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      const Text(
                          'Share your code with friends and track your referral activity.',
                          style:
                              TextStyle(color: Colors.white70, height: 1.4)),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(r.code,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2)),
                            ),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: r.code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Referral code copied.')));
                              },
                              icon: const Icon(Icons.copy_rounded,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.groups_rounded,
                                color: Colors.white, size: 28),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Successful referrals',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 3),
                                Text('${r.successfulReferrals}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 27,
                                        fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(c).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Theme.of(c).dividerColor.withOpacity(.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Have a referral code?',
                          style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: claim,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Referral code',
                          prefixIcon: Icon(Icons.redeem_rounded),
                        ),
                      ),
                      const SizedBox(height: 13),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: busy ? null : _claim,
                          child: Text(busy ? 'Applying...' : 'Apply code'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                    'Referral rewards are handled according to your ZenexPay program rules.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            );
          },
        ),
      );
}
