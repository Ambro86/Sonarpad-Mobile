import 'package:flutter/widgets.dart';

class AudioDescriptionProjectStrings {
  const AudioDescriptionProjectStrings(this._m);
  final Map<String, String> _m;
  String operator [](String key) => _m[key] ?? _en[key] ?? key;

  static AudioDescriptionProjectStrings of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    var key = locale.languageCode;
    if (key == 'pt' && locale.countryCode?.toUpperCase() == 'BR') key = 'pt_BR';
    if (key == 'zh' && locale.countryCode?.toUpperCase() == 'CN') key = 'zh_CN';
    return AudioDescriptionProjectStrings(_all[key] ?? _en);
  }

  static const Map<String, String> _en = {
    'menu': 'Edit audio description project',
    'title': 'Edit audio description project',
    'open': 'Open audio description project',
    'project': 'Project',
    'chooseSource': 'Choose original video',
    'source': 'Original video',
    'description': 'Description',
    'text': 'Description text',
    'preview': 'Preview description',
    'apply': 'Apply text',
    'delete': 'Delete description',
    'deleteConfirm': 'Delete the selected description from the project?',
    'deleteLast': 'The only description in the project cannot be deleted.',
    'changeVoice': 'Apply voice to project',
    'engine': 'Reading engine',
    'edge': 'Microsoft Edge voice',
    'system': 'System / VoiceOver / Android voice',
    'language': 'Voice language',
    'voice': 'Voice',
    'reexport': 'Re-export MP3',
    'srt': 'Export as SRT',
    'vtt': 'Export as VTT',
    'normal': 'normal with ducking',
    'extended': 'extended pause',
    'ready': 'Project ready.',
    'applied': 'Description checked and saved in the project.',
    'deleted': 'Description deleted and project saved.',
    'voiceChanged': 'Voice changed and all descriptions were checked.',
    'tooLong': 'The synthesized description lasts {actual} seconds, but only {available} seconds are available. The previous text was not changed.',
    'sourceMissing': 'The original video is not available. Choose it before re-exporting the MP3.',
    'invalidProject': 'The selected file is not a valid Sonarpad audio description project.',
    'unsaved': 'Apply the current text before re-exporting the MP3.',
    'working': 'Processing project…',
    'completed': 'Project exported.',
    'selectFirst': 'Open a project first.',
    'selectDescription': 'Select a description.',
    'details': 'Scene {source} s; MP3 {start}-{end} s; voice {duration} s; {mode}',
    'share': 'Share',
    'saveDocuments': 'Save in Sonarpad Documents',
    'saved': 'Files saved in Sonarpad Documents.',
    'cancel': 'Cancel',
  };

  static Map<String, String> _merge(Map<String, String> overrides) {
    final merged = Map<String, String>.of(_en);
    merged.addAll(overrides);
    return Map<String, String>.unmodifiable(merged);
  }

  static final Map<String, Map<String, String>> _all = {
    'en': _en,
    'it': _merge({
      'menu': 'Modifica progetto audiodescrizione', 'title': 'Modifica progetto audiodescrizione',
      'open': 'Apri progetto audiodescrizione', 'project': 'Progetto', 'chooseSource': 'Scegli video originale',
      'source': 'Video originale', 'description': 'Descrizione', 'text': 'Testo della descrizione',
      'preview': 'Riproduci descrizione', 'apply': 'Applica modifica', 'delete': 'Elimina descrizione',
      'deleteConfirm': 'Eliminare la descrizione selezionata dal progetto?', 'deleteLast': 'Non è possibile eliminare l’unica descrizione del progetto.',
      'changeVoice': 'Applica voce al progetto', 'engine': 'Motore di lettura', 'edge': 'Voce Microsoft Edge',
      'system': 'Voce di sistema / VoiceOver / Android', 'language': 'Lingua della voce', 'voice': 'Voce',
      'reexport': 'Esporta nuovamente MP3', 'srt': 'Esporta come SRT', 'vtt': 'Esporta come VTT',
      'normal': 'normale con ducking', 'extended': 'pausa estesa', 'ready': 'Progetto pronto.',
      'applied': 'Descrizione verificata e salvata nel progetto.', 'deleted': 'Descrizione eliminata e progetto salvato.',
      'voiceChanged': 'Voce cambiata e tutte le descrizioni sono state verificate.',
      'tooLong': 'La descrizione sintetizzata dura {actual} secondi, ma sono disponibili solo {available} secondi. Il testo precedente non è stato modificato.',
      'sourceMissing': 'Il video originale non è disponibile. Sceglilo prima di riesportare l’MP3.',
      'invalidProject': 'Il file selezionato non è un progetto audiodescrizione Sonarpad valido.',
      'unsaved': 'Applica prima la modifica corrente, poi riesporta l’MP3.', 'working': 'Elaborazione progetto…',
      'completed': 'Progetto esportato.', 'selectFirst': 'Apri prima un progetto.', 'selectDescription': 'Seleziona una descrizione.',
      'details': 'Scena {source} s; MP3 {start}-{end} s; voce {duration} s; {mode}',
      'share': 'Condividi', 'saveDocuments': 'Salva in Documenti Sonarpad', 'saved': 'File salvati in Documenti Sonarpad.', 'cancel': 'Annulla',
    }),
    'es': _merge({ 'menu':'Modificar proyecto de audiodescripción','title':'Modificar proyecto de audiodescripción','open':'Abrir proyecto de audiodescripción','chooseSource':'Elegir vídeo original','description':'Descripción','text':'Texto de la descripción','preview':'Reproducir descripción','apply':'Aplicar modificación','delete':'Eliminar descripción','changeVoice':'Aplicar voz al proyecto','reexport':'Volver a exportar MP3','srt':'Exportar como SRT','vtt':'Exportar como VTT','working':'Procesando proyecto…','completed':'Proyecto exportado.','share':'Compartir','saveDocuments':'Guardar en Documentos de Sonarpad'}),
    'fr': _merge({ 'menu':'Modifier le projet d’audiodescription','title':'Modifier le projet d’audiodescription','open':'Ouvrir le projet d’audiodescription','chooseSource':'Choisir la vidéo originale','description':'Description','text':'Texte de la description','preview':'Lire la description','apply':'Appliquer la modification','delete':'Supprimer la description','changeVoice':'Appliquer la voix au projet','reexport':'Réexporter le MP3','srt':'Exporter en SRT','vtt':'Exporter en VTT','working':'Traitement du projet…','completed':'Projet exporté.','share':'Partager','saveDocuments':'Enregistrer dans Documents Sonarpad'}),
    'de': _merge({ 'menu':'Audiodeskriptionsprojekt bearbeiten','title':'Audiodeskriptionsprojekt bearbeiten','open':'Audiodeskriptionsprojekt öffnen','chooseSource':'Originalvideo auswählen','description':'Beschreibung','text':'Beschreibungstext','preview':'Beschreibung anhören','apply':'Änderung anwenden','delete':'Beschreibung löschen','changeVoice':'Stimme auf Projekt anwenden','reexport':'MP3 erneut exportieren','srt':'Als SRT exportieren','vtt':'Als VTT exportieren','working':'Projekt wird verarbeitet…','completed':'Projekt exportiert.','share':'Teilen','saveDocuments':'In Sonarpad-Dokumenten speichern'}),
    'pt': _merge({ 'menu':'Modificar projeto de audiodescrição','title':'Modificar projeto de audiodescrição','open':'Abrir projeto de audiodescrição','chooseSource':'Escolher vídeo original','description':'Descrição','text':'Texto da descrição','preview':'Reproduzir descrição','apply':'Aplicar alteração','delete':'Eliminar descrição','changeVoice':'Aplicar voz ao projeto','reexport':'Exportar MP3 novamente','srt':'Exportar como SRT','vtt':'Exportar como VTT','working':'A processar projeto…','completed':'Projeto exportado.','share':'Partilhar','saveDocuments':'Guardar em Documentos Sonarpad'}),
    'pt_BR': _merge({ 'menu':'Editar projeto de audiodescrição','title':'Editar projeto de audiodescrição','open':'Abrir projeto de audiodescrição','chooseSource':'Escolher vídeo original','description':'Descrição','text':'Texto da descrição','preview':'Reproduzir descrição','apply':'Aplicar alteração','delete':'Excluir descrição','changeVoice':'Aplicar voz ao projeto','reexport':'Exportar MP3 novamente','srt':'Exportar como SRT','vtt':'Exportar como VTT','working':'Processando projeto…','completed':'Projeto exportado.','share':'Compartilhar','saveDocuments':'Salvar em Documentos Sonarpad'}),
    'pl': _merge({ 'menu':'Edytuj projekt audiodeskrypcji','title':'Edytuj projekt audiodeskrypcji','open':'Otwórz projekt audiodeskrypcji','chooseSource':'Wybierz oryginalne wideo','description':'Opis','text':'Tekst opisu','preview':'Odtwórz opis','apply':'Zastosuj zmianę','delete':'Usuń opis','changeVoice':'Zastosuj głos do projektu','reexport':'Eksportuj MP3 ponownie','srt':'Eksportuj jako SRT','vtt':'Eksportuj jako VTT','working':'Przetwarzanie projektu…','completed':'Projekt wyeksportowany.','share':'Udostępnij','saveDocuments':'Zapisz w Dokumentach Sonarpad'}),
    'cs': _merge({ 'menu':'Upravit projekt audiopopisu','title':'Upravit projekt audiopopisu','open':'Otevřít projekt audiopopisu','chooseSource':'Vybrat původní video','description':'Popis','text':'Text popisu','preview':'Přehrát popis','apply':'Použít změnu','delete':'Odstranit popis','changeVoice':'Použít hlas na projekt','reexport':'Znovu exportovat MP3','srt':'Exportovat jako SRT','vtt':'Exportovat jako VTT','working':'Zpracování projektu…','completed':'Projekt exportován.','share':'Sdílet','saveDocuments':'Uložit do Dokumentů Sonarpad'}),
    'uk': _merge({ 'menu':'Редагувати проєкт аудіодескрипції','title':'Редагувати проєкт аудіодескрипції','open':'Відкрити проєкт аудіодескрипції','chooseSource':'Вибрати оригінальне відео','description':'Опис','text':'Текст опису','preview':'Відтворити опис','apply':'Застосувати зміну','delete':'Видалити опис','changeVoice':'Застосувати голос до проєкту','reexport':'Повторно експортувати MP3','srt':'Експортувати як SRT','vtt':'Експортувати як VTT','working':'Обробка проєкту…','completed':'Проєкт експортовано.','share':'Поділитися','saveDocuments':'Зберегти в Документах Sonarpad'}),
    'zh': _merge({ 'menu':'编辑音频描述项目','title':'编辑音频描述项目','open':'打开音频描述项目','chooseSource':'选择原始视频','description':'描述','text':'描述文本','preview':'播放描述','apply':'应用修改','delete':'删除描述','changeVoice':'将语音应用到项目','reexport':'重新导出 MP3','srt':'导出为 SRT','vtt':'导出为 VTT','working':'正在处理项目…','completed':'项目已导出。','share':'共享','saveDocuments':'保存到 Sonarpad 文档'}),
    'zh_CN': _merge({ 'menu':'编辑音频描述项目','title':'编辑音频描述项目','open':'打开音频描述项目','chooseSource':'选择原始视频','description':'描述','text':'描述文本','preview':'播放描述','apply':'应用修改','delete':'删除描述','changeVoice':'将语音应用到项目','reexport':'重新导出 MP3','srt':'导出为 SRT','vtt':'导出为 VTT','working':'正在处理项目…','completed':'项目已导出。','share':'共享','saveDocuments':'保存到 Sonarpad 文档'}),
  };
}
