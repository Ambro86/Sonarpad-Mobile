import 'app_localizations.dart';

extension LocalizedDynamicLabels on AppLocalizations {
  String radioLanguageLabel(String code) => switch (code) {
        'it' => radioLanguageIt,
        'en' => radioLanguageEn,
        'tr' => radioLanguageTr,
        'de' => radioLanguageDe,
        'es' => radioLanguageEs,
        'pt' => radioLanguagePt,
        'sv' => radioLanguageSv,
        'vi' => radioLanguageVi,
        'cs' => radioLanguageCs,
        'pl' => radioLanguagePl,
        'fr' => radioLanguageFr,
        'sr' => radioLanguageSr,
        'uk' => radioLanguageUk,
        'hi' => radioLanguageHi,
        'lt' => radioLanguageLt,
        'ru' => radioLanguageRu,
        'zh' => radioLanguageZh,
        _ => code,
      };

  String radioCountryLabel(String code) => switch (code) {
        'it' => radioCountryOptionIt,
        'us' => radioCountryOptionUs,
        'gb' => radioCountryOptionGb,
        'tr' => radioCountryOptionTr,
        'fr' => radioCountryOptionFr,
        'es' => radioCountryOptionEs,
        'de' => radioCountryOptionDe,
        'ch' => radioCountryOptionCh,
        'at' => radioCountryOptionAt,
        'be' => radioCountryOptionBe,
        'nl' => radioCountryOptionNl,
        'pt' => radioCountryOptionPt,
        'br' => radioCountryOptionBr,
        'ar' => radioCountryOptionAr,
        'mx' => radioCountryOptionMx,
        'ca' => radioCountryOptionCa,
        'au' => radioCountryOptionAu,
        'ie' => radioCountryOptionIe,
        'se' => radioCountryOptionSe,
        'pl' => radioCountryOptionPl,
        'jp' => radioCountryOptionJp,
        _ => code.toUpperCase(),
      };

  String radioGenreLabel(String value) => switch (value) {
        'all' => radioGenreOptionAll,
        'news' => radioGenreOptionNews,
        'music' => radioGenreOptionMusic,
        'sport' => radioGenreOptionSport,
        'talk' => radioGenreOptionTalk,
        'pop' => radioGenreOptionPop,
        'rock' => radioGenreOptionRock,
        'classical' => radioGenreOptionClassical,
        'jazz' => radioGenreOptionJazz,
        'dance' => radioGenreOptionDance,
        'blues' => radioGenreOptionBlues,
        'country' => radioGenreOptionCountry,
        'hiphop' => radioGenreOptionHiphop,
        'electronic' => radioGenreOptionElectronic,
        'latin' => radioGenreOptionLatin,
        'reggae' => radioGenreOptionReggae,
        'metal' => radioGenreOptionMetal,
        'folk' => radioGenreOptionFolk,
        'religion' => radioGenreOptionReligion,
        'local' => radioGenreOptionLocal,
        'culture' => radioGenreOptionCulture,
        'oldies' => radioGenreOptionOldies,
        'kids' => radioGenreOptionKids,
        'ambient' => radioGenreOptionAmbient,
        _ => value,
      };

  String radioCommunityLanguageLabel(String value) => switch (value) {
        'italian' => radioCommunityLanguageItalian,
        'english' => radioCommunityLanguageEnglish,
        'turkish' => radioCommunityLanguageTurkish,
        'spanish' => radioCommunityLanguageSpanish,
        'french' => radioCommunityLanguageFrench,
        'german' => radioCommunityLanguageGerman,
        'portuguese' => radioCommunityLanguagePortuguese,
        'swedish' => radioCommunityLanguageSwedish,
        'vietnamese' => radioCommunityLanguageVietnamese,
        'czech' => radioCommunityLanguageCzech,
        'polish' => radioCommunityLanguagePolish,
        'serbian' => radioCommunityLanguageSerbian,
        'ukrainian' => radioCommunityLanguageUkrainian,
        'lithuanian' => radioCommunityLanguageLithuanian,
        'russian' => radioCommunityLanguageRussian,
        'chinese' => radioCommunityLanguageChinese,
        'hindi' => radioCommunityLanguageHindi,
        _ => value,
      };


  String formatDistance(double meters) {
    if (meters < 1000) return routeDistanceMeters(meters.round());
    return routeDistanceKilometers((meters / 1000).toStringAsFixed(1));
  }

  String formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return routeDurationMinutes(minutes);
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return routeDurationHoursMinutes(hours, mins);
  }


  bool get _isPortugueseLocale =>
      localeName == 'pt' || localeName.toLowerCase().replaceAll('-', '_') == 'pt_br';

  bool get _isBrazilianPortugueseLocale =>
      localeName.toLowerCase().replaceAll('-', '_') == 'pt_br';

  /// Localizes application-owned technical errors that may originate in
  /// services without a BuildContext. Unknown backend/system details are
  /// preserved, while Sonarpad's own Italian/English fallback text is
  /// translated for Portuguese locales.
  String localizeTechnicalError(Object? error) {
    var text = error?.toString().trim() ?? '';
    if (!_isPortugueseLocale || text.isEmpty) return text;

    text = text.replaceFirst(
      RegExp(r'^(?:Exception|Bad state|TimeoutException|FormatException|FileSystemException):\s*'),
      '',
    );

    final br = _isBrazilianPortugueseLocale;
    final fileWord = br ? 'arquivo' : 'ficheiro';
    final mediaFile = br ? 'arquivo de mídia' : 'ficheiro multimédia';

    final exact = <String, String>{
      'Nessun testo esportabile per l\'audiolibro.':
          'Nenhum texto disponível para exportar como audiolivro.',
      'Nessun blocco audio generabile.':
          'Não há blocos de áudio que possam ser gerados.',
      'Nessun file audio da unire.':
          br ? 'Não há arquivos de áudio para unir.' : 'Não há ficheiros de áudio para unir.',
      'Audiolibro non trovato.':
          'Audiolivro não encontrado.',
      'Codice di autorizzazione non trovato':
          'Código de autorização não encontrado.',
      'Token Dropbox non ricevuto':
          'Token do Dropbox não recebido.',
      'ID Gutenberg non valido.':
          'ID do Gutenberg inválido.',
      'Download Gutenberg troppo lento. Riprova tra poco o scegli un altro formato.':
          'O download do Gutenberg está muito lento. Tente novamente daqui a pouco ou escolha outro formato.',
      'Archivio ZIP Gutenberg senza file di testo leggibile.':
          br
              ? 'O arquivo ZIP do Gutenberg não contém um arquivo de texto legível.'
              : 'O ficheiro ZIP do Gutenberg não contém um ficheiro de texto legível.',
      'Nessun testo trovato nel documento, neanche tramite scansione visiva OCR.':
          'Nenhum texto foi encontrado no documento, nem mesmo com OCR.',
      'Struttura DOCX non valida: word/document.xml non trovato.':
          'Estrutura DOCX inválida: word/document.xml não encontrado.',
      'Nessun testo trovato nel documento DOCX.':
          'Nenhum texto foi encontrado no documento DOCX.',
      'Nessun testo trovato nell\'EPUB.':
          'Nenhum texto foi encontrado no EPUB.',
      'Impossibile analizzare le tracce del file multimediale.':
          'Não foi possível analisar as faixas do $mediaFile.',
      'Il file non contiene tracce esportabili.':
          'O $fileWord não contém faixas que possam ser exportadas.',
      'Il file sorgente non è più disponibile.':
          'O $fileWord de origem já não está disponível.',
      'Non ci sono parti valide da esportare.':
          'Não há partes válidas para exportar.',
      'Le parti da esportare sono sovrapposte o disordinate.':
          'As partes a exportar estão sobrepostas ou fora de ordem.',
      'Il file non contiene una traccia audio valida.':
          'O $fileWord não contém uma faixa de áudio válida.',
      'L’effetto DSP richiede una traccia audio.':
          'O efeito DSP requer uma faixa de áudio.',
      'Nessun effetto DSP da elaborare.':
          'Não há efeitos DSP para processar.',
      'Video initialize failed':
          'Falha ao inicializar o vídeo.',
      'Audio source failed':
          'Falha na fonte de áudio.',
      'Nessun flusso riproducibile disponibile.':
          'Nenhum fluxo reproduzível disponível.',
      'Risposta SonarTube non valida.':
          'Resposta do SonarTube inválida.',
      'Errore SonarTube':
          'Erro do SonarTube',
      'È possibile risolvere soltanto un video.':
          'Só é possível resolver um vídeo.',
      'Impossibile generare il pacchetto EPUB.':
          'Não foi possível gerar o pacote EPUB.',
      'Impossibile generare il pacchetto DOCX.':
          'Não foi possível gerar o pacote DOCX.',
      'Nessun log trovato.':
          'Nenhum log encontrado.',
      'Richiesta rifiutata':
          'Pedido recusado.',
      'Sorgente già presente':
          'Fonte já existente.',
      'Radio Browser non raggiungibile':
          'Radio Browser indisponível.',
      'Registrazione gia in corso.':
          br ? 'Já existe uma gravação em andamento.' : 'Já existe uma gravação em curso.',
      'Registrazione non creata dallo stream.':
          br
              ? 'A gravação não foi criada a partir da transmissão.'
              : 'A gravação não foi criada a partir do fluxo.',
      'A recording is already active.':
          br ? 'Já existe uma gravação em andamento.' : 'Já existe uma gravação em curso.',
      'Il file non contiene tracce audio o video utilizzabili.':
          br
              ? 'O arquivo não contém faixas de áudio ou vídeo utilizáveis.'
              : 'O ficheiro não contém faixas de áudio ou vídeo utilizáveis.',
    };
    text = exact[text] ?? text;

    final replacements = <(RegExp, String Function(Match))>[
      (
        RegExp(r'^Failed to load now playing movies:\s*(.*)$', dotAll: true),
        (m) => 'Erro ao carregar filmes em cartaz: ${m[1]}',
      ),
      (
        RegExp(r'^Failed to load upcoming movies:\s*(.*)$', dotAll: true),
        (m) => 'Erro ao carregar próximos lançamentos: ${m[1]}',
      ),
      (
        RegExp(r"^Formato \.([A-Z0-9]+) non supportato per l'estrazione del testo\.$"),
        (m) => 'Formato .${m[1]} não suportado para extração de texto.',
      ),
      (
        RegExp(r'^Errore durante la lettura del file:\s*(.*)$', dotAll: true),
        (m) => 'Erro ao ler o $fileWord: ${m[1]}',
      ),
      (
        RegExp(r'^Errore durante la scansione OCR del PDF:\s*(.*)$', dotAll: true),
        (m) => 'Erro durante a leitura OCR do PDF: ${m[1]}',
      ),
      (
        RegExp(r'^File audiolibro non creato o troppo piccolo:\s*(.*)$', dotAll: true),
        (m) => 'O $fileWord do audiolivro não foi criado ou é muito pequeno: ${m[1]}',
      ),
      (
        RegExp(r'^File Edge troppo piccolo:\s*(.*)$', dotAll: true),
        (m) => 'O $fileWord Edge é muito pequeno: ${m[1]}',
      ),
      (
        RegExp(r'^Errore LibriVox\s+(.*)$', dotAll: true),
        (m) => 'Erro no LibriVox: ${m[1]}',
      ),
      (
        RegExp(r'^Errore Gutenberg\s+(.*)$', dotAll: true),
        (m) => 'Erro no Gutenberg: ${m[1]}',
      ),
      (
        RegExp(r'^Errore feed podcast:\s*(.*)$', dotAll: true),
        (m) => 'Erro no feed do podcast: ${m[1]}',
      ),
      (
        RegExp(r'^Ricerca podcast non riuscita:\s*(.*)$', dotAll: true),
        (m) => 'Falha na pesquisa de podcasts: ${m[1]}',
      ),
      (
        RegExp(r'^Lookup podcast non riuscito:\s*(.*)$', dotAll: true),
        (m) => 'Falha na consulta do podcast: ${m[1]}',
      ),
      (
        RegExp(r'^Podcast per nazione non raggiungibili:\s*(.*)$', dotAll: true),
        (m) => 'Podcasts por país indisponíveis: ${m[1]}',
      ),
      (
        RegExp(r'^Categorie podcast non raggiungibili:\s*(.*)$', dotAll: true),
        (m) => 'Categorias de podcasts indisponíveis: ${m[1]}',
      ),
      (
        RegExp(r'^Ricerca Spreaker non riuscita:\s*(.*)$', dotAll: true),
        (m) => 'Falha na pesquisa no Spreaker: ${m[1]}',
      ),
      (
        RegExp(r'^Feed non raggiungibile:\s*(.*)$', dotAll: true),
        (m) => 'Feed indisponível: ${m[1]}',
      ),
      (
        RegExp(r'^Download non riuscito:\s*(.*)$', dotAll: true),
        (m) => br ? 'Falha no download: ${m[1]}' : 'Falha na transferência: ${m[1]}',
      ),
      (
        RegExp(r'^Articolo non raggiungibile:\s*(.*)$', dotAll: true),
        (m) => 'Artigo indisponível: ${m[1]}',
      ),
      (
        RegExp(r'^Errore PoetryDB\s+(.*)$', dotAll: true),
        (m) => 'Erro no PoetryDB: ${m[1]}',
      ),
      (
        RegExp(r'^Errore RSS (.+):\s*(.*)$', dotAll: true),
        (m) => 'Erro RSS ${m[1]}: ${m[2]}',
      ),
      (
        RegExp(r'^Impossibile caricare (.+): RSS primario e fallback Google News non disponibili\. Primario: (.*); fallback: (.*)$', dotAll: true),
        (m) => 'Não foi possível carregar ${m[1]}: o RSS principal e o fallback do Google Notícias não estão disponíveis. Principal: ${m[2]}; fallback: ${m[3]}',
      ),
      (
        RegExp(r'^Impossibile caricare (.+): RSS primario non disponibile e fallback Google News senza articoli\. Primario: (.*)$', dotAll: true),
        (m) => 'Não foi possível carregar ${m[1]}: o RSS principal não está disponível e o fallback do Google Notícias não retornou artigos. Principal: ${m[2]}',
      ),
      (
        RegExp(r'^Cartella inaccessibile per via delle protezioni di sistema \(Android Scoped Storage\)\. Prova ad importare i file singolarmente\.(?:,\s*path\s*=.*)?$', dotAll: true),
        (m) => br
            ? 'Pasta inacessível devido às proteções do sistema (Android Scoped Storage). Tente importar os arquivos individualmente.'
            : 'Pasta inacessível devido às proteções do sistema (Android Scoped Storage). Tente importar os ficheiros individualmente.',
      ),
      (
        RegExp(r'^Errore di lettura della cartella \(potenziali limiti permessi\):\s*(.*?)(?:,\s*path\s*=.*)?$', dotAll: true),
        (m) => 'Erro ao ler a pasta (possíveis limitações de permissões): ${m[1]}',
      ),
      (
        RegExp(r'^Errore durante la lettura dei log:\s*(.*)$', dotAll: true),
        (m) => 'Erro ao ler os logs: ${m[1]}',
      ),
      (
        RegExp(r'^Errore download EPUB\s+(.*)$', dotAll: true),
        (m) => br ? 'Erro ao baixar EPUB: ${m[1]}' : 'Erro ao transferir EPUB: ${m[1]}',
      ),
      (
        RegExp(r'^Errore download\s+(.*)$', dotAll: true),
        (m) => br ? 'Erro ao baixar: ${m[1]}' : 'Erro ao transferir: ${m[1]}',
      ),
      (
        RegExp(r'^Errore nel login Dropbox:\s*(.*)$', dotAll: true),
        (m) => 'Erro ao entrar no Dropbox: ${m[1]}',
      ),
      (
        RegExp(r'^Errore elenco cartella:\s*(.*)$', dotAll: true),
        (m) => 'Erro ao listar a pasta: ${m[1]}',
      ),
      (
        RegExp(r'^Errore download file:\s*(.*)$', dotAll: true),
        (m) => br
            ? 'Erro ao baixar o $fileWord: ${m[1]}'
            : 'Erro ao transferir o $fileWord: ${m[1]}',
      ),
      (
        RegExp(r'^Timeout durante la creazione del file TTS di sistema$'),
        (m) => br
            ? 'Tempo limite excedido ao criar o arquivo TTS do sistema.'
            : 'Tempo limite excedido ao criar o ficheiro TTS do sistema.',
      ),
      (
        RegExp(r'^Esportazione con voce di sistema non riuscita\. Dettagli:\s*(.*)$', dotAll: true),
        (m) => 'Falha na exportação com a voz do sistema. Detalhes: ${m[1]}',
      ),
      (
        RegExp(r'^Errore durante (.*) dopo (\d+) tentativi\. Ultimo errore:\s*(.*)$', dotAll: true),
        (m) {
          var label = m[1] ?? '';
          label = label
              .replaceFirst(RegExp(r'^Edge chunk '), 'bloco Edge ')
              .replaceFirst(RegExp(r'^system chunk '), 'bloco do sistema ');
          return 'Erro durante $label após ${m[2]} tentativas. Último erro: ${m[3]}';
        },
      ),
      (
        RegExp(r'^Il file (.+) non è stato creato\.$', dotAll: true),
        (m) => 'O $fileWord ${_ptMediaLabel(m[1] ?? '', br)} não foi criado.',
      ),
      (
        RegExp(r'^Il file (.+) è vuoto\.$', dotAll: true),
        (m) => 'O $fileWord ${_ptMediaLabel(m[1] ?? '', br)} está vazio.',
      ),
      (
        RegExp(r'^Il file (.+) non contiene la traccia video attesa\.$', dotAll: true),
        (m) => 'O $fileWord ${_ptMediaLabel(m[1] ?? '', br)} não contém a faixa de vídeo esperada.',
      ),
      (
        RegExp(r'^Il file (.+) non contiene la traccia audio attesa\.$', dotAll: true),
        (m) => 'O $fileWord ${_ptMediaLabel(m[1] ?? '', br)} não contém a faixa de áudio esperada.',
      ),
      (
        RegExp(r'^Il file audio (.+) non contiene una traccia audio\.$', dotAll: true),
        (m) => 'O $fileWord de áudio ${_ptMediaLabel(m[1] ?? '', br)} não contém uma faixa de áudio.',
      ),
      (
        RegExp(r'^Il file (.+) ha una durata non valida\.$', dotAll: true),
        (m) => 'O $fileWord ${_ptMediaLabel(m[1] ?? '', br)} tem uma duração inválida.',
      ),
      (
        RegExp(r'^Durata non valida per (.+): attesa (.+), ottenuta (.+)\.$', dotAll: true),
        (m) => 'Duração inválida para ${_ptMediaLabel(m[1] ?? '', br)}: esperada ${m[2]}, obtida ${m[3]}.',
      ),
      (
        RegExp(r'^Il file di destinazione esiste già:\s*(.*)$', dotAll: true),
        (m) => 'O $fileWord de destino já existe: ${m[1]}',
      ),
      (
        RegExp(r'^Impossibile completare il salvataggio in modo sicuro:\s*(.*)$', dotAll: true),
        (m) => br
            ? 'Não foi possível concluir o salvamento com segurança: ${m[1]}'
            : 'Não foi possível concluir a gravação em segurança: ${m[1]}',
      ),
      (
        RegExp(r'^Impossibile scrivere il file temporaneo nella cartella scelta:\s*(.*)$', dotAll: true),
        (m) => 'Não foi possível gravar o $fileWord temporário na pasta escolhida: ${m[1]}',
      ),
      (
        RegExp(r'^La parte (\d+) contiene limiti non validi\.$'),
        (m) => 'A parte ${m[1]} contém limites inválidos.',
      ),
      (
        RegExp(r'^La parte (\d+) è troppo breve per produrre un file valido \((.*)\)\.$', dotAll: true),
        (m) => 'A parte ${m[1]} é curta demais para produzir um $fileWord válido (${m[2]}).',
      ),
      (
        RegExp(r'^La parte (\d+) supera la durata del file sorgente\.$'),
        (m) => 'A parte ${m[1]} ultrapassa a duração do $fileWord de origem.',
      ),
      (
        RegExp(r'^Il file sorgente è cambiato durante il salvataggio\. Riaprilo e ripeti il taglio\.$'),
        (m) => br
            ? 'O $fileWord de origem mudou durante o salvamento. Abra-o novamente e repita o corte.'
            : 'O $fileWord de origem mudou durante a gravação. Volte a abri-lo e repita o corte.',
      ),
      (
        RegExp(r'^Il motore DSP non ha prodotto audio per (.+)\.$', dotAll: true),
        (m) => 'O mecanismo DSP não produziu áudio para ${m[1]}.',
      ),
    ];

    for (final replacement in replacements) {
      final match = replacement.$1.firstMatch(text);
      if (match != null) {
        text = replacement.$2(match);
        break;
      }
    }
    return text;
  }

  String mediaCutterExportPartProgress(int index, int total) =>
      _isPortugueseLocale ? 'Parte $index de $total' : 'Parte $index di $total';

  String get mediaCutterExportFinalVerification =>
      _isPortugueseLocale ? 'Verificação final' : 'Verifica finale';

  String get mediaCutterExportMergeParts =>
      _isPortugueseLocale ? 'União das partes' : 'Unione delle parti';

  String get mediaCutterExportFileCheck => _isPortugueseLocale
      ? (_isBrazilianPortugueseLocale
          ? 'Verificação do arquivo'
          : 'Verificação do ficheiro')
      : 'Controllo del file';

  String get mediaCutterExportPublishing =>
      _isPortugueseLocale ? 'Publicação' : 'Pubblicazione';

  String get mediaCutterExportCompletion =>
      _isPortugueseLocale ? 'Conclusão' : 'Completamento';

}


String _ptMediaLabel(String value, bool brazil) {
  return value
      .replaceAll('file finale', brazil ? 'arquivo final' : 'ficheiro final')
      .replaceAll('unione veloce', 'união rápida')
      .replaceAll('segmento', 'segmento');
}

