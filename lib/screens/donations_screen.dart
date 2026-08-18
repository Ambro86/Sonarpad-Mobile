import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../widgets/universal_accessible_view.dart';

class DonationsScreen extends StatelessWidget {
  const DonationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.donations)),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [AccessibleListSection(rows: [
                AccessibleListRow(id: 'intro', kind: 'text', title: l10n.donationsIntro),
                const AccessibleListRow(id: 'paypal_header', kind: 'header', title: 'PayPal'),
                AccessibleListRow(id: 'paypal_desc', kind: 'text', title: l10n.donationsPaypalDesc),
                AccessibleListRow(id: 'paypal', title: l10n.donateWithPaypal, kind: 'button'),
                AccessibleListRow(id: 'bank_header', kind: 'header', title: l10n.bankTransferTitle),
                AccessibleListRow(id: 'bank_desc', kind: 'text', title: l10n.donationsBankDesc),
                AccessibleListRow(id: 'thanks', kind: 'text', title: l10n.donationsThanks),
              ])],
              onEvent: (event) async {
                if (event.id == 'paypal' && event.type == 'activate') {
                  final url = Uri.parse('https://www.paypal.me/ambrogio86');
                  if (await canLaunchUrl(url)) await launchUrl(url);
                }
              },
            )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.donationsIntro,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text('PayPal', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l10n.donationsPaypalDesc,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final url = Uri.parse('https://www.paypal.me/ambrogio86');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            icon: const Icon(Icons.favorite),
            label: Text(l10n.donateWithPaypal),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.bankTransferTitle,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l10n.donationsBankDesc,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text(l10n.donationsThanks,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
