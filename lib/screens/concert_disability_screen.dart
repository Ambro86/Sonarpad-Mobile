import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../l10n/ticketone_strings.dart';
import '../utils/app_logger.dart';
import '../services/concert_disability_contacts.dart';
import '../widgets/universal_accessible_view.dart';

/// Information and official hand-off, not a booking or an eligibility decision.
/// Documents and accreditation requests stay with the event's organiser.
class ConcertDisabilityScreen extends StatelessWidget {
  const ConcertDisabilityScreen({
    super.key,
    required this.eventTitle,
    this.organiser = '',
    this.openEvent,
    this.opener,
    this.contact,
  });

  final String eventTitle, organiser;
  final ConcertDisabilityContact? contact;
  final Future<void> Function()? openEvent;
  final Future<bool> Function(Uri, LaunchMode)? opener;

  static bool isVivo(String organiser) => RegExp(
    r'^Vivo Concerti\s+(?:s\.?\s*r\.?\s*l\.?)(?:\s|,|$)',
    caseSensitive: false,
  ).hasMatch(organiser.trim());

  Future<void> _open(BuildContext context, Uri uri, String action) async {
    final mode = uri.scheme == 'https'
        ? LaunchMode.inAppBrowserView
        : LaunchMode.externalApplication;
    try {
      final opened =
          await (opener?.call(uri, mode) ?? launchUrl(uri, mode: mode));
      if (!opened) throw StateError('Open failed');
      await AppLogger.log('[Concerts] disability_open action=$action');
    } catch (_) {
      await AppLogger.log('[Concerts] disability_open_failed action=$action');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorOpening)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TicketOneStrings(AppLocalizations.of(context).localeName);
    final selected = contact ?? ConcertDisabilityContact.match(organiser);
    final vivo =
        selected?.name == 'Vivo Concerti' ||
        (contact == null && isVivo(organiser));
    AccessibleListRow text(String id, String value) => AccessibleListRow(
      id: id,
      title: value,
      kind: 'text',
      accessibilityButtonTrait: false,
    );
    AccessibleListRow link(String id, String title, Uri uri) =>
        AccessibleListRow(
          id: id,
          title: title,
          kind: 'button',
          onActivate: () => _open(context, uri, id),
        );
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(t.t('disabilityTitle'))),
      body: SafeArea(
        child: UniversalAccessibleList(
          initialFocusId: 'disability-event',
          padding: const EdgeInsets.all(16),
          sections: [
            AccessibleListSection(
              rows: [
                text('disability-event', eventTitle),
                text('disability-help', t.t('disabilityHelp')),
                text(
                  'disability-organiser',
                  organiser.isEmpty
                      ? t.t('disabilityUnknownOrganiser')
                      : '${t.t('disabilityOrganiser')}: $organiser',
                ),
                text('disability-conditions', t.t('disabilityConditions')),
                if (vivo) ...[
                  text('disability-vivo-help', t.t('disabilityVivoHelp')),
                  link(
                    'disability-vivo-info',
                    t.t('disabilityOfficialInstructions'),
                    Uri.parse('https://www.vivoconcerti.com/servizio-clienti'),
                  ),
                  link(
                    'disability-vivo-mail',
                    t.t('disabilityWriteOrganiser'),
                    Uri(scheme: 'mailto', path: 'info@vivoconcerti.com'),
                  ),
                  text(
                    'disability-calendar-help',
                    t.t('disabilityCalendarHelp'),
                  ),
                  link(
                    'disability-calendar',
                    t.t('disabilityCalendar'),
                    Uri.parse('https://www.mani-amiche.it/agenda.php'),
                  ),
                ],
                if (selected != null && !vivo) ...[
                  text('disability-selected', selected.name),
                  link(
                    'disability-contact-info',
                    '${t.t('disabilityContactInstructions')}: ${selected.name}',
                    Uri.parse(selected.instructions),
                  ),
                  for (final email in selected.emails)
                    link(
                      'disability-mail-$email',
                      '${t.t('disabilityContactEmail')}: $email',
                      Uri(scheme: 'mailto', path: email),
                    ),
                ],
                AccessibleListRow(
                  id: 'disability-choose-organiser',
                  title: t.t('disabilityChooseOrganiser'),
                  kind: 'button',
                  onActivate: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (chooserContext) => Scaffold(
                        appBar: SonarpadAppBar(
                          title: Text(t.t('disabilityChooseOrganiser')),
                        ),
                        body: SafeArea(
                          child: UniversalAccessibleList(
                            initialFocusId: 'disability-choose-help',
                            sections: [
                              AccessibleListSection(
                                rows: [
                                  text(
                                    'disability-choose-help',
                                    t.t('disabilityChooseHelp'),
                                  ),
                                  for (final profile
                                      in ConcertDisabilityContact.all)
                                    AccessibleListRow(
                                      id: profile.id,
                                      title: profile.name,
                                      kind: 'button',
                                      onActivate: () =>
                                          Navigator.of(
                                            chooserContext,
                                          ).push<void>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ConcertDisabilityScreen(
                                                    eventTitle: eventTitle,
                                                    organiser: organiser,
                                                    openEvent: openEvent,
                                                    opener: opener,
                                                    contact: profile,
                                                  ),
                                            ),
                                          ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                link(
                  'disability-directory',
                  t.t('disabilityDirectory'),
                  Uri.parse(
                    'https://www.ticketone.it/campaign/diversamente-abili/',
                  ),
                ),
                if (openEvent != null)
                  AccessibleListRow(
                    id: 'disability-open-event',
                    title: t.t('disabilityReadOrganiser'),
                    kind: 'button',
                    onActivate: openEvent,
                  ),
                text(
                  'disability-request-not-booking',
                  t.t('disabilityRequestNotice'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
