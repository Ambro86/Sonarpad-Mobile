import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// ARB-backed labels and messages for the audio description project editor.
class AudioDescriptionProjectStrings {
  const AudioDescriptionProjectStrings(this._l10n);

  final AppLocalizations _l10n;

  static AudioDescriptionProjectStrings of(BuildContext context) =>
      AudioDescriptionProjectStrings(AppLocalizations.of(context));

  String get menu => _l10n.audioDescriptionProjectEditorTitle;
  String get title => _l10n.audioDescriptionProjectEditorTitle;
  String get open => _l10n.audioDescriptionProjectOpen;
  String get project => _l10n.audioDescriptionProjectLabel;
  String get chooseSource => _l10n.audioDescriptionProjectChooseSource;
  String get source => _l10n.audioDescriptionProjectSource;
  String get description => _l10n.audioDescriptionProjectDescription;
  String get text => _l10n.audioDescriptionProjectDescriptionText;
  String get preview => _l10n.audioDescriptionProjectPreviewDescription;
  String get apply => _l10n.audioDescriptionProjectApplyText;
  String get delete => _l10n.audioDescriptionProjectDeleteDescription;
  String get deleteConfirm => _l10n.audioDescriptionProjectDeleteConfirmation;
  String get deleteLast => _l10n.audioDescriptionProjectCannotDeleteLast;
  String get changeVoice => _l10n.audioDescriptionProjectApplyVoice;
  String get engine => _l10n.audioDescriptionProjectReadingEngine;
  String get edge => _l10n.audioDescriptionProjectEdgeVoice;
  String get system => _l10n.audioDescriptionProjectSystemVoice;
  String get language => _l10n.audioDescriptionProjectVoiceLanguage;
  String get voice => _l10n.audioDescriptionProjectVoice;
  String get reexport => _l10n.audioDescriptionProjectReexportMp3;
  String get srt => _l10n.audioDescriptionProjectExportSrt;
  String get vtt => _l10n.audioDescriptionProjectExportVtt;
  String get normal => _l10n.audioDescriptionProjectNormalWithDucking;
  String get extended => _l10n.audioDescriptionProjectExtendedPause;
  String get ready => _l10n.audioDescriptionProjectReady;
  String get applied => _l10n.audioDescriptionProjectDescriptionApplied;
  String get deleted => _l10n.audioDescriptionProjectDescriptionDeleted;
  String get voiceChanged => _l10n.audioDescriptionProjectVoiceChanged;
  String get sourceMissing => _l10n.audioDescriptionProjectSourceMissing;
  String get invalidProject => _l10n.audioDescriptionProjectInvalid;
  String get unsaved => _l10n.audioDescriptionProjectUnsavedText;
  String get working => _l10n.audioDescriptionProjectWorking;
  String get completed => _l10n.audioDescriptionProjectExported;
  String get selectFirst => _l10n.audioDescriptionProjectSelectFirst;
  String get selectDescription => _l10n.audioDescriptionProjectSelectDescription;
  String get share => _l10n.audioDescriptionProjectShare;
  String get saveDocuments => _l10n.audioDescriptionProjectSaveDocuments;
  String get saved => _l10n.audioDescriptionProjectSavedDocuments;
  String get cancel => _l10n.audioDescriptionProjectCancel;

  String tooLong({
    required String actual,
    required String available,
  }) =>
      _l10n.audioDescriptionProjectDescriptionTooLong(actual, available);

  String details({
    required String source,
    required String start,
    required String end,
    required String duration,
    required String mode,
  }) =>
      _l10n.audioDescriptionProjectDescriptionDetails(
        source,
        start,
        end,
        duration,
        mode,
      );

  /// Keeps legacy lookup keys, including templates, available to callers.
  /// The editor uses the typed getters and methods above.
  String operator [](String key) => switch (key) {
    'menu' => menu,
    'title' => title,
    'open' => open,
    'project' => project,
    'chooseSource' => chooseSource,
    'source' => source,
    'description' => description,
    'text' => text,
    'preview' => preview,
    'apply' => apply,
    'delete' => delete,
    'deleteConfirm' => deleteConfirm,
    'deleteLast' => deleteLast,
    'changeVoice' => changeVoice,
    'engine' => engine,
    'edge' => edge,
    'system' => system,
    'language' => language,
    'voice' => voice,
    'reexport' => reexport,
    'srt' => srt,
    'vtt' => vtt,
    'normal' => normal,
    'extended' => extended,
    'ready' => ready,
    'applied' => applied,
    'deleted' => deleted,
    'voiceChanged' => voiceChanged,
    'tooLong' => tooLong(actual: '{actual}', available: '{available}'),
    'sourceMissing' => sourceMissing,
    'invalidProject' => invalidProject,
    'unsaved' => unsaved,
    'working' => working,
    'completed' => completed,
    'selectFirst' => selectFirst,
    'selectDescription' => selectDescription,
    'details' => details(
      source: '{source}',
      start: '{start}',
      end: '{end}',
      duration: '{duration}',
      mode: '{mode}',
    ),
    'share' => share,
    'saveDocuments' => saveDocuments,
    'saved' => saved,
    'cancel' => cancel,
    _ => key,
  };
}
