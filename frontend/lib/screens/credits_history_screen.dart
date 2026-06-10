import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../models/credits.dart';
import '../services/credits_service.dart';
import '../theme.dart';

/// Full credit ledger: current balance on top, every grant/spend below.
class CreditsHistoryScreen extends StatefulWidget {
  const CreditsHistoryScreen({super.key});

  @override
  State<CreditsHistoryScreen> createState() => _CreditsHistoryScreenState();
}

class _CreditsHistoryScreenState extends State<CreditsHistoryScreen> {
  late Future<List<CreditTransaction>> _future;

  @override
  void initState() {
    super.initState();
    _future = api.getCreditTransactions();
    CreditsService.instance.refresh();
  }

  Future<void> _reload() async {
    setState(() => _future = api.getCreditTransactions());
    await CreditsService.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfacePage,
      appBar: AppBar(
        title: const Text('Credits'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: RefreshIndicator(
        color: kBrand,
        onRefresh: _reload,
        child: FutureBuilder<List<CreditTransaction>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: kBrand),
              );
            }
            if (snap.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text(dioErrorMessage(snap.error!),
                        style: kStyleSecondary.copyWith(color: kRedFg)),
                  ),
                ],
              );
            }
            final txns = snap.data ?? const [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _balanceCard(),
                const SizedBox(height: 20),
                const Text('HISTORY', style: kStyleLabel),
                const SizedBox(height: 8),
                if (txns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('No transactions yet.',
                        style: kStyleSecondary.copyWith(color: kTextTertiary)),
                  ),
                for (final t in txns) _txnRow(t),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _balanceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBrand,
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      child: Row(
        children: [
          const Icon(Icons.toll_outlined, color: kTextOnBrand, size: 30),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current balance',
                  style: TextStyle(color: kTextOnBrand, fontSize: 13)),
              const SizedBox(height: 2),
              ListenableBuilder(
                listenable: CreditsService.instance,
                builder: (context, _) => Text(
                  '${CreditsService.instance.balance ?? '—'} credits',
                  style: const TextStyle(
                    color: kTextOnBrand,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _txnRow(CreditTransaction t) {
    final grant = t.isGrant;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBorderHairline, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: grant ? kBrandSubtle : kSurfacePage,
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(t.kind),
                size: 18, color: grant ? kTextBrand : kTextSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.description ?? _labelFor(t.kind),
                  style: kStyleBody.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM yyyy · HH:mm').format(t.createdAt),
                  style: kStyleSecondary.copyWith(color: kTextTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${grant ? '+' : ''}${t.amount}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: grant ? kTextBrand : kTextPrimary,
                ),
              ),
              Text('bal ${t.balanceAfter}',
                  style: kStyleSecondary.copyWith(color: kTextTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'image':
        return Icons.image_outlined;
      case 'voice':
        return Icons.mic_none_outlined;
      case 'text':
        return Icons.chat_bubble_outline;
      case 'initial':
        return Icons.card_giftcard_outlined;
      default:
        return Icons.toll_outlined;
    }
  }

  String _labelFor(String kind) {
    switch (kind) {
      case 'image':
        return 'Image AI call';
      case 'voice':
        return 'Voice AI call';
      case 'text':
        return 'Text AI call';
      case 'initial':
        return 'Welcome credits';
      default:
        return 'Transaction';
    }
  }
}
