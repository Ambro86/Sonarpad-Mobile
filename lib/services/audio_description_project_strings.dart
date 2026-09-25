import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

class AudioDescriptionProjectStrings {
  const AudioDescriptionProjectStrings(this._l10n);
  final AppLocalizations _l10n;

  static AudioDescriptionProjectStrings of(BuildContext context) =>
      AudioDescriptionProjectStrings(AppLocalizations.of(context));

  String operator [](String key) => switch (key) {
        'menu' => _l10n.audioDescriptionProjectEditorMenu,
        'title' => _l10n.audioDescriptionProjectEditorTitle,
        'open' => _l10n.audioDescriptionProjectEditorOpen,
        'project' => _l10n.audioDescriptionProjectEditorProject,
        'chooseSource' => _l10n.audioDescriptionProjectEditorChooseSource,
        'source' => _l10n.audioDescriptionProjectEditorSource,
        'description' => _l10n.audioDescriptionProjectEditorDescription,
        'text' => _l10n.audioDescriptionProjectEditorText,
        'preview' => _l10n.audioDescriptionProjectEditorPreview,
        'apply' => _l10n.audioDescriptionProjectEditorApply,
        'delete' => _l10n.audioDescriptionProjectEditorDelete,
        'deleteConfirm' => _l10n.audioDescriptionProjectEditorDeleteConfirm,
        'deleteLast' => _l10n.audioDescriptionProjectEditorDeleteLast,
        'changeVoice' => _l10n.audioDescriptionProjectEditorChangeVoice,
        'engine' => _l10n.audioDescriptionProjectEditorEngine,
        'edge' => _l10n.audioDescriptionProjectEditorEdge,
        'system' => _l10n.audioDescriptionProjectEditorSystem,
        'language' => _l10n.audioDescriptionProjectEditorLanguage,
        'voice' => _l10n.audioDescriptionProjectEditorVoice,
        'reexport' => _l10n.audioDescriptionProjectEditorReexport,
        'srt' => _l10n.audioDescriptionProjectEditorSrt,
        'vtt' => _l10n.audioDescriptionProjectEditorVtt,
        'normal' => _l10n.audioDescriptionProjectEditorNormal,
        'extended' => _l10n.audioDescriptionProjectEditorExtended,
        'ready' => _l10n.audioDescriptionProjectEditorReady,
        'applied' => _l10n.audioDescriptionProjectEditorApplied,
        'deleted' => _l10n.audioDescriptionProjectEditorDeleted,
        'voiceChanged' => _l10n.audioDescriptionProjectEditorVoiceChanged,
        'tooLong' => _l10n.audioDescriptionProjectEditorTooLong('{actual}', '{available}'),
        'sourceMissing' => _l10n.audioDescriptionProjectEditorSourceMissing,
        'invalidProject' => _l10n.audioDescriptionProjectEditorInvalidProject,
        'unsaved' => _l10n.audioDescriptionProjectEditorUnsaved,
        'working' => _l10n.audioDescriptionProjectEditorWorking,
        'completed' => _l10n.audioDescriptionProjectEditorCompleted,
        'selectFirst' => _l10n.audioDescriptionProjectEditorSelectFirst,
        'selectDescription' => _l10n.audioDescriptionProjectEditorSelectDescription,
        'details' => _l10n.audioDescriptionProjectEditorDetails('{source}', '{start}', '{end}', '{duration}', '{mode}'),
        'share' => _l10n.audioDescriptionProjectEditorShare,
        'saveDocuments' => _l10n.audioDescriptionProjectEditorSaveDocuments,
        'saved' => _l10n.audioDescriptionProjectEditorSaved,
        'cancel' => _l10n.audioDescriptionProjectEditorCancel,
        _ => key,
      };
}
