import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'donations_screen.dart';
import 'changelog_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/changelog_service.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  Future<void> _openChangelog(BuildContext context) async {
    try {
      final appLanguage = await AppSettingsService().loadAppLanguage();
      final entry = await ChangelogService().loadCurrentEntry();
      if (!context.mounted || entry == null) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/info/changelog'),
          builder: (_) => ChangelogScreen(
            entry: entry,
            languageCode: appLanguage,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
            showStatusMessage(context, l10n.changelogLoadError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.info)),
      body: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final versionText = snapshot.hasData
                ? l10n.versionBuild(
                    snapshot.data!.version,
                    snapshot.data!.buildNumber,
                  )
                : '';

            if (useSharedAccessibleViewModel) {
              return UniversalAccessibleList(
                sections: [AccessibleListSection(rows: [
                  AccessibleListRow(id: 'title', kind: 'header', title: l10n.appTitle),
                  if (versionText.isNotEmpty) AccessibleListRow(id: 'version', kind: 'text', title: versionText),
                  AccessibleListRow(id: 'donations', title: l10n.donations),
                  AccessibleListRow(id: 'changelog', title: l10n.whatIsNew),
                  AccessibleListRow(id: 'description', kind: 'text', title: l10n.infoDescription),
                  AccessibleListRow(id: 'website', title: l10n.visitSonarpadSiteWithUrl('https://sonarpad.com')),
                  AccessibleListRow(id: 'author', kind: 'text', title: l10n.infoAuthor),
                ])],
                onEvent: (event) async {
                  if (event.type != 'activate') return;
                  if (event.id == 'donations') {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonationsScreen()));
                  } else if (event.id == 'changelog') {
                    await _openChangelog(context);
                  } else if (event.id == 'website') {
                    final url = Uri.parse('https://sonarpad.com');
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  }
                },
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.appTitle,
                    style: Theme.of(context).textTheme.headlineMedium),
                if (versionText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(versionText,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const DonationsScreen()),
                    );
                  },
                  icon: const Icon(Icons.favorite),
                  label: Text(l10n.donations),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _openChangelog(context),
                  icon: const Icon(Icons.new_releases),
                  label: Text(l10n.whatIsNew),
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
                  label: l10n.visitSonarpadSite,
                  child: InkWell(
                    onTap: () async {
                      final url = Uri.parse('https://sonarpad.com');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    child: Text(
                      l10n.visitSonarpadSiteWithUrl('https://sonarpad.com'),
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.infoAuthor,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            );
          }),
    );
  }
}
