import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'donations_screen.dart';
import '../l10n/app_localizations.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.info)),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final versionText = snapshot.hasData 
              ? 'Versione ${snapshot.data!.version} (Build ${snapshot.data!.buildNumber})' 
              : '';
              
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.appTitle,
                  style: Theme.of(context).textTheme.headlineMedium),
              if (versionText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(versionText, style: Theme.of(context).textTheme.titleMedium),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DonationsScreen()),
                  );
                },
                icon: const Icon(Icons.favorite),
                label: Text(l10n.donations),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              Text(l10n.infoDescription,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                excludeSemantics: true,
                label: 'Visita il sito di Sonarpad',
                child: InkWell(
                  onTap: () async {
                    final url = Uri.parse('https://sonarpad.com');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  child: const Text(
                    'Visita il sito di Sonarpad: https://sonarpad.com',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.infoAuthor, style: Theme.of(context).textTheme.titleMedium),
            ],
          );
        }
      ),
    );
  }
}
