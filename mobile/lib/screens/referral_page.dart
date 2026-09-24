import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

const _rBlue = Color(0xFF4F8CFF);
const _rPurple = Color(0xFF8B5CF6);

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
  void initState() { super.initState(); future = SupabaseService.referralInfo(); }
  @override
  void dispose() { claim.dispose(); super.dispose(); }

  Future<void> _claim() async {
    final code = claim.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => busy = true);
    try {
      await SupabaseService.claimReferral(code);
      claim.clear();
      setState(() => future = SupabaseService.referralInfo());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code applied.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code copied.')));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Referral Center', style: TextStyle(fontWeight: FontWeight.w900))),
        body: FutureBuilder<ReferralInfo>(
          future: future,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return Center(child: Text('${s.error}'));
            final r = s.data!;
            return RefreshIndicator(
              onRefresh: () async { setState(() => future = SupabaseService.referralInfo()); await future; },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(21),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF071127), Color(0xFF173A83), _rPurple]),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: _rPurple.withOpacity(.18), blurRadius: 28, offset: const Offset(0, 12))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.groups_rounded, color: Colors.white)),
                      const SizedBox(height: 14),
                      const Text('Invite & grow together', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      const Text('Share your code with friends and track your referral activity.', style: TextStyle(color: Colors.white70, height: 1.4)),
                      const SizedBox(height: 18),
                      const Text('YOUR REFERRAL CODE', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withOpacity(.12))),
                        child: Row(children: [Expanded(child: Text(r.code, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2))), IconButton(onPressed: () => _copy(r.code), icon: const Icon(Icons.copy_rounded, color: Colors.white))]),
                      ),
                      const SizedBox(height: 13),
                      Row(children: [
                        Expanded(child: _Stat('Successful referrals', '${r.successfulReferrals}', Icons.verified_rounded)),
                        const SizedBox(width: 10),
                        const Expanded(child: _Stat('Invite reward', 'Program', Icons.redeem_rounded)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Theme.of(c).colorScheme.surface, borderRadius: BorderRadius.circular(23), border: Border.all(color: Theme.of(c).dividerColor.withOpacity(.45))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Have a referral code?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      const Text('Enter a friend’s code to apply it to your account.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 13),
                      TextField(controller: claim, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Referral code', prefixIcon: Icon(Icons.redeem_rounded))),
                      const SizedBox(height: 13),
                      SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: busy ? null : _claim, icon: const Icon(Icons.check_rounded), label: Text(busy ? 'Applying...' : 'Apply code'))),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  const _InfoRow(icon: Icons.info_outline_rounded, text: 'Referral rewards are handled according to your ZenexPay program rules.'),
                ],
              ),
            );
          },
        ),
      );
}

class _Stat extends StatelessWidget { final String title, value; final IconData icon; const _Stat(this.title, this.value, this.icon); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(.09), borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, color: Colors.white, size: 21), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 9)), const SizedBox(height: 2), Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))]))])); }
class _InfoRow extends StatelessWidget { final IconData icon; final String text; const _InfoRow({required this.icon, required this.text}); @override Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 17, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)))]); }
