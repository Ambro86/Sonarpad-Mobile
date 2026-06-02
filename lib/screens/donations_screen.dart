import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

class DonationsScreen extends StatelessWidget {
  const DonationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.donations)),
      body: ListView(
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
