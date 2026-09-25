import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/network_error.dart';
import 'referral_page.dart';

class PromoPage extends StatefulWidget {
  const PromoPage({super.key});
  @override
  State<PromoPage> createState() => _PromoPageState();
}

class _PromoPageState extends State<PromoPage> {
  late Future<List<Map<String, dynamic>>> future;
  final Set<String> busy = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => future = SupabaseService.promotions();

  Future<void> _claim(String id) async {
    setState(() => busy.add(id));
    try {
      await SupabaseService.claimPromotion(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reward added to your wallet.')),
      );
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  Future<void> _openDetails(Map<String, dynamic> promotion) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignDetailsPage(promotion: promotion),
      ),
    );
    if (changed == true && mounted) setState(_reload);
  }

  Future<void> _handleAction(Map<String, dynamic> promotion) async {
    final id = '${promotion['id']}';
    final action = '${promotion['action_label'] ?? 'View'}'.toLowerCase();
    final kind = '${promotion['kind'] ?? ''}'.toLowerCase();
    final claimed = promotion['claimed'] == true;

    if (action == 'view') {
      // Referral Bonus keeps its existing View -> Referral Center behavior.
      if (kind == 'referral') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReferralPage()),
        );
      } else {
        await _openDetails(promotion);
      }
      return;
    }

    if (action == 'claim' && !claimed && !busy.contains(id)) {
      _claim(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rewards & Announcements')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (_, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load rewards.\n${friendlyError(s.error!)}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final rows = s.data ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7A35F4), Color(0xFF146BFF)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.card_giftcard_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rewards & Announcements',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Live content from ZenexPay.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: Text('No announcements right now.'),
                    ),
                  ),
                for (final r in rows) ...[
                  _item(cs, r),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _item(ColorScheme cs, Map<String, dynamic> r) {
    final id = '${r['id']}';
    final reward = double.tryParse('${r['reward'] ?? 0}') ?? 0;
    final action = '${r['action_label'] ?? 'View'}';
    final claimable = reward > 0 && action.toLowerCase() == 'claim';
    final claimed = r['claimed'] == true;
    final kind = '${r['kind'] ?? 'announcement'}'.toLowerCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                kind == 'campaign'
                    ? Icons.campaign_rounded
                    : kind == 'announcement'
                        ? Icons.notifications_active_outlined
                        : kind == 'referral'
                            ? Icons.people_alt_rounded
                            : Icons.card_giftcard_rounded,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r['title'] ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r['description'] ?? ''}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (reward > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        'Reward: ৳ ${reward.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: claimable
                        ? FilledButton(
                            onPressed: claimed || busy.contains(id)
                                ? null
                                : () => _claim(id),
                            child: Text(
                              claimed
                                  ? 'Claimed Today'
                                  : busy.contains(id)
                                      ? 'Processing…'
                                      : action,
                            ),
                          )
                        : OutlinedButton(
                            onPressed: () => _handleAction(r),
                            child: Text(action),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CampaignDetailsPage extends StatefulWidget {
  final Map<String, dynamic> promotion;

  const CampaignDetailsPage({
    super.key,
    required this.promotion,
  });

  @override
  State<CampaignDetailsPage> createState() => _CampaignDetailsPageState();
}

class _CampaignDetailsPageState extends State<CampaignDetailsPage> {
  bool busy = false;

  Future<void> _claimReward() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await SupabaseService.claimPromotion('${widget.promotion['id']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reward added to your wallet.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('$value')?.toLocal();
    if (parsed == null) return 'Not specified';
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'campaign':
        return 'Campaign';
      case 'announcement':
        return 'Announcement';
      case 'bonus':
        return 'Bonus';
      default:
        return 'Reward';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = '${widget.promotion['title'] ?? 'Campaign'}';
    final description = '${widget.promotion['description'] ?? ''}'.trim();
    final kind = '${widget.promotion['kind'] ?? 'announcement'}'.toLowerCase();
    final reward = double.tryParse('${widget.promotion['reward'] ?? 0}') ?? 0;
    final action = '${widget.promotion['action_label'] ?? 'View'}';
    final claimed = widget.promotion['claimed'] == true;
    final isClaimable = reward > 0 && action.toLowerCase() == 'claim';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Campaign Details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7A35F4), Color(0xFF146BFF)],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.14),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        kind == 'campaign'
                            ? Icons.campaign_rounded
                            : Icons.notifications_active_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _kindLabel(kind),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (reward > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Reward  •  ৳ ${reward.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionCard(
            context,
            icon: Icons.description_outlined,
            title: 'Description',
            child: Text(
              description.isEmpty ? 'No description provided.' : description,
              style: TextStyle(
                color: cs.onSurface.withOpacity(.72),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            icon: Icons.calendar_month_outlined,
            title: 'Campaign period',
            child: Column(
              children: [
                _InfoRow(
                  label: 'Starts',
                  value: _date(widget.promotion['starts_at']),
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Ends',
                  value: widget.promotion['ends_at'] == null
                      ? 'No end date'
                      : _date(widget.promotion['ends_at']),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            icon: Icons.rule_outlined,
            title: 'How to qualify',
            child: Text(
              kind == 'campaign'
                  ? 'Follow the campaign requirements described in the campaign information. Only eligible users can claim a reward.'
                  : 'Follow the requirements described by ZenexPay for this promotion.',
              style: TextStyle(
                color: cs.onSurface.withOpacity(.72),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            icon: Icons.verified_user_outlined,
            title: 'Terms & Conditions',
            child: Text(
              'Reward availability, eligibility and claim limits are controlled by ZenexPay. A reward is credited only after the server accepts a valid claim.',
              style: TextStyle(
                color: cs.onSurface.withOpacity(.72),
                height: 1.5,
              ),
            ),
          ),
          if (isClaimable) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: claimed || busy ? null : _claimReward,
                icon: Icon(
                  claimed
                      ? Icons.check_circle_outline_rounded
                      : Icons.card_giftcard_rounded,
                ),
                label: Text(
                  claimed
                      ? 'Claimed Today'
                      : busy
                          ? 'Processing…'
                          : 'Claim Reward',
                ),
              ),
            ),
            if (!claimed)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  'The server checks eligibility and prevents duplicate claims.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(.48),
                    fontSize: 10.5,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary, size: 20),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(.50),
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ],
    );
  }
}
