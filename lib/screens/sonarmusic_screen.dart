import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/media_playback_speed.dart';
import '../models/podcast.dart';
import '../services/app_settings_service.dart';
import '../services/recording_feature_access.dart';
import '../services/sonarmusic_library_service.dart';
import '../services/sonarmusic_service.dart';
import '../services/sonartube_service.dart';
import '../widgets/online_ai_audiodescription_action.dart';
import '../widgets/sonartube_save_media_dialog.dart';
import '../widgets/universal_accessible_view.dart';
import 'podcast_episode_player_screen.dart';

class SonarMusicScreen extends StatefulWidget {
  const SonarMusicScreen({super.key, this.collection, this.searchQuery,
    this.searchType = 'all', this.libraryType,
    this.service, this.library});
  final SonarMusicItem? collection;
  final String? searchQuery, libraryType;
  final String searchType;
  final SonarMusicService? service;
  final SonarMusicLibraryService? library;
  @override
  State<SonarMusicScreen> createState() => _SonarMusicScreenState();
}

class _SonarMusicScreenState extends State<SonarMusicScreen> {
  late final SonarMusicService _service = widget.service ?? SonarMusicService();
  late final SonarMusicLibraryService _library = widget.library ?? SonarMusicLibraryService();
  late final SonarMusicTubeAdapter _exportAdapter = SonarMusicTubeAdapter(_service);
  final TextEditingController _searchController = TextEditingController();
  final AccessibleListController _accessible = AccessibleListController(debugName: 'sonarmusic');
  final FocusNode _searchFocus = FocusNode();
  List<SonarMusicItem> _items = [];
  Set<String> _favorites = {};
  String? _nextToken, _title, _description;
  String _type = 'all';
  int _page = 1;
  bool _loading = false, _loadingMore = false, _unlocked = false;
  Object? _error;
  String? _opening;
  bool get _home => widget.collection == null && widget.searchQuery == null && widget.libraryType == null;
  bool get _busy => _opening != null;
  bool get _isCollection => widget.collection != null;

  String _label(String key) {
    final lang = AppLocalizations.of(context).localeName;
    final table = <String, List<String>>{
      'all': ['Tutto','All','Tout','Todo','Alles','Tudo','Wszystko','Vše','Все','Toate','全部'],
      'song': ['Brani','Songs','Titres','Canciones','Songs','Músicas','Utwory','Skladby','Пісні','Melodii','歌曲'],
      'video': ['Video musicali','Music videos','Clips','Vídeos musicales','Musikvideos','Vídeos musicais','Teledyski','Hudební videa','Музичні відео','Videoclipuri','音乐视频'],
      'album': ['Album','Albums','Albums','Álbumes','Alben','Álbuns','Albumy','Alba','Альбоми','Albume','专辑'],
      'artist': ['Artisti','Artists','Artistes','Artistas','Künstler','Artistas','Artyści','Umělci','Виконавці','Artiști','艺人'],
      'playlist': ['Playlist','Playlists','Playlists','Listas','Playlists','Playlists','Playlisty','Playlisty','Плейлисти','Liste','播放列表'],
      'favorites': ['Preferiti','Favorites','Favoris','Favoritos','Favoriten','Favoritos','Ulubione','Oblíbené','Улюблене','Favorite','收藏'],
      'recent': ['Ascoltati di recente','Recently played','Écoutés récemment','Recientes','Zuletzt gehört','Ouvidos recentemente','Ostatnio słuchane','Nedávno přehrané','Нещодавні','Redate recent','最近播放'],
      'open': ['Apri URL','Open URL','Ouvrir URL','Abrir URL','URL öffnen','Abrir URL','Otwórz URL','Otevřít URL','Відкрити URL','Deschide URL','打开链接'],
      'load': ['Carica altri risultati','Load more','Charger plus','Cargar más','Mehr laden','Carregar mais','Więcej','Načíst další','Більше','Încarcă mai mult','加载更多'],
      'artist_open': ['Vai all’artista','Go to artist','Voir l’artiste','Ir al artista','Zum Künstler','Ir para artista','Przejdź do artysty','Přejít na interpreta','До виконавця','Vezi artistul','查看艺人'],
      'album_open': ['Vai all’album','Go to album','Voir l’album','Ir al álbum','Zum Album','Ir para álbum','Przejdź do albumu','Přejít na album','До альбому','Vezi albumul','查看专辑'],
      'play_all': ['Riproduci tutto','Play all','Tout lire','Reproducir todo','Alles abspielen','Reproduzir tudo','Odtwórz wszystko','Přehrát vše','Відтворити все','Redă tot','播放全部'],
      'share': ['Condividi','Share','Partager','Compartir','Teilen','Compartilhar','Udostępnij','Sdílet','Поділитися','Distribuie','分享'],
      'add': ['Aggiungi ai preferiti','Add to favorites','Ajouter aux favoris','Añadir a favoritos','Zu Favoriten','Adicionar aos favoritos','Dodaj do ulubionych','Přidat mezi oblíbené','Додати в обране','Adaugă la favorite','加入收藏'],
      'remove': ['Rimuovi dai preferiti','Remove favorite','Retirer des favoris','Quitar de favoritos','Aus Favoriten entfernen','Remover dos favoritos','Usuń z ulubionych','Odebrat z oblíbených','Вилучити з обраного','Elimină favorit','取消收藏'],
      'empty': ['Nessun risultato','No results','Aucun résultat','Sin resultados','Keine Ergebnisse','Sem resultados','Brak wyników','Žádné výsledky','Немає результатів','Fără rezultate','无结果'],
      'invalid': ['Impossibile aprire questo elemento','Cannot open this item','Impossible d’ouvrir','No se puede abrir','Kann nicht geöffnet werden','Não é possível abrir','Nie można otworzyć','Nelze otevřít','Не вдалося відкрити','Nu se poate deschide','无法打开'],
      'description': ['Descrizione','Description','Description','Descripción','Beschreibung','Descrição','Opis','Popis','Опис','Descriere','说明'],
      'shuffle': ['Riproduzione casuale','Shuffle','Aléatoire','Aleatorio','Zufällig','Aleatório','Losowo','Náhodně','Випадково','Aleatoriu','随机播放'],
      'save': ['Salva media','Save media','Enregistrer le média','Guardar medio','Medien speichern','Guardar multimédia','Zapisz multimedia','Uložit média','Зберегти медіа','Salvează media','保存媒体'],
      'suggest': ['Suggerimenti','Suggestions','Suggestions','Sugerencias','Vorschläge','Sugestões','Podpowiedzi','Návrhy','Підказки','Sugestii','搜索建议'],
      'search_hint': ['Titolo, artista o album','Song, artist or album','Titre, artiste ou album','Canción, artista o álbum','Titel, Künstler oder Album','Música, artista ou álbum','Utwór, artysta lub album','Skladba, interpret nebo album','Пісня, виконавець або альбом','Melodie, artist sau album','歌曲、艺人或专辑'],
    };
    final idx = switch(lang) {'en'=>1,'fr'=>2,'es'=>3,'de'=>4,
      'pt'||'pt_BR'=>5,'pl'=>6,'cs'=>7,'uk'=>8,'ro'=>9,'zh_CN'=>10,_=>0};
    return table[key]?[idx] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _type = widget.searchType;
    _searchController.text = widget.searchQuery ?? '';
    _init();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service.setLocaleName(AppLocalizations.of(context).localeName);
  }
  Future<void> _init() async {
    final favoriteItems = await _library.favorites();
    final unlocked = await RecordingFeatureAccess.isUnlocked();
    if (!mounted) return;
    setState(() { _favorites = favoriteItems.map((e) => e.key).toSet(); _unlocked = unlocked; });
    if (!_home) await _load();
  }
  @override
  void dispose() {
    _searchController.dispose(); _searchFocus.dispose(); super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading || _loadingMore) return;
    final page = more ? _page + 1 : 1;
    final token = more ? _nextToken : null;
    setState(() { if (more) { _loadingMore = true; } else { _loading = true; _error = null; } });
    try {
      SonarMusicPage result;
      if (widget.libraryType == 'favorites') {
        result = SonarMusicPage(items: await _library.favorites());
      } else if (widget.libraryType == 'recent') {
        result = SonarMusicPage(items: await _library.recent());
      } else if (widget.collection != null) {
        result = await _service.browse(widget.collection!.browseId ?? widget.collection!.id,
            token: token, page: page);
      } else {
        result = await _service.search(widget.searchQuery ?? '', type: _type,
            token: token, page: page);
      }
      if (!mounted) return;
      setState(() {
        if (!more) _items = [];
        final seen = _items.map((e) => e.key).toSet();
        for (final item in result.items) { if (seen.add(item.key)) _items.add(item); }
        _nextToken = result.nextToken;
        _title = result.title ?? widget.collection?.title;
        _description = result.description;
        _page = page;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }
  Future<void> _suggest() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final options = await _service.suggestions(query);
    if (!mounted || options.isEmpty) {
      if (mounted) _showError(_label('empty'));
      return;
    }
    final choice = await showDialog<String>(context: context, builder: (dialog) =>
      AlertDialog(title: Text(_label('suggest')), content: SizedBox(
        width: double.maxFinite,
        child: ListView(shrinkWrap: true, children: [
          for (final text in options) ListTile(title: Text(text),
            onTap: () => Navigator.pop(dialog, text)),
        ]))));
    if (!mounted || choice == null) return;
    _searchController.text = choice;
    await _search();
  }
  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    await Navigator.push(context, MaterialPageRoute(
      settings: const RouteSettings(name: '/sonarmusic/search'),
      builder: (_) => SonarMusicScreen(searchQuery: query, searchType: _type,
        service: _service, library: _library)));
  }
  Future<void> _openLibrary(String type) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => SonarMusicScreen(libraryType: type, service: _service, library: _library)));
    await _refreshFavorites();
  }
  Future<void> _refreshFavorites() async {
    final fav = await _library.favorites();
    if (mounted) setState(() => _favorites = fav.map((e) => e.key).toSet());
  }
  Future<void> _toggleFavorite(SonarMusicItem item, {String? focusId}) async {
    await _library.toggle(item);
    await _refreshFavorites();
    if (widget.libraryType == 'favorites') await _load();
    if (focusId != null && mounted) {
      await _accessible.refreshAccessibilityRow(focusId);
    }
  }
  Future<void> _openUrl() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(context: context, builder: (dialog) =>
      AlertDialog(title: Text(_label('open')),
        content: TextField(controller: controller, autofocus: true,
          keyboardType: TextInputType.url, textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: _label('open')),
          onSubmitted: (text) => Navigator.pop(dialog, text)),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: Text(AppLocalizations.of(context).cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, controller.text), child: Text(_label('open')))]));
    controller.dispose();
    if (url == null || url.trim().isEmpty || !mounted) return;
    try {
      final item = await _service.openUrl(url);
      if (mounted) await _openItem(item);
    } catch (_) { if (mounted) _showError(_label('invalid')); }
  }
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  Future<void> _shareItem(SonarMusicItem item) async {
    final uri = item.url ?? (item.playable
      ? 'https://music.youtube.com/watch?v=${item.videoId}'
      : 'https://music.youtube.com/browse/${item.browseId ?? item.id}');
    await SharePlus.instance.share(ShareParams(text: '${item.title}\n$uri'));
  }
  bool _canSave(SonarMusicItem item) => _unlocked && item.playable;
  Future<void> _save(SonarMusicItem item) async {
    if (!_canSave(item)) return;
    await saveSonarTubeMediaWithDestination(context,
      service: _exportAdapter, item: item.toVideoItem());
  }
  Future<void> _createAd(SonarMusicItem item) async {
    if (!_canSave(item) || item.kind != 'video') return;
    await createAiAudiodescriptionFromSonarTube(context,
      service: _exportAdapter, item: item.toVideoItem());
  }
  Future<void> _openArtist(SonarMusicItem item) async {
    var id = item.kind == 'artist' ? (item.browseId ?? item.id) : item.artistId;
    var name = item.kind == 'artist' ? item.title : (item.artist ?? '');
    if ((id == null || id.isEmpty) && item.playable) {
      try {
        final channel = await SonarTubeService().channelForVideo(item.toVideoItem());
        id = channel.id; name = channel.title;
      } catch (_) { /* Some music tracks expose no artist/channel. */ }
    }
    if (!mounted || id == null || id.isEmpty) { if (mounted) _showError(_label('invalid')); return; }
    await _openItem(SonarMusicItem(kind: 'artist', id: id, browseId: id,
      title: name.isEmpty ? _label('artist') : name));
  }
  Future<void> _openVideoInfo(SonarMusicItem item, String mode) async {
    if (!item.playable || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      settings: RouteSettings(name: '/sonarmusic/$mode'),
      builder: (_) => SonarMusicVideoInfoScreen(item: item, mode: mode)));
  }
  Future<void> _openAlbum(SonarMusicItem item) async {
    if (item.albumId == null) return;
    await _openItem(SonarMusicItem(kind: 'album', id: item.albumId!,
      browseId: item.albumId, title: item.album ?? _label('album')));
  }
  Future<PodcastEpisode> _episode(SonarMusicItem item) async {
    final media = await _service.resolve(item);
    return PodcastEpisode(id: 'sonarmusic:${item.videoId}',
      title: media.title, description: media.channel ?? item.artist ?? '',
      audioUrl: media.audioUrl, videoUrl: media.videoUrl);
  }
  Future<void> _play(SonarMusicItem item, {bool shuffle = false, bool forceAutoplay = false}) async {
    if (_busy || !item.playable) return;
    setState(() => _opening = item.key);
    try {
      var queue = _items.where((i) => i.playable).toList();
      if (shuffle) queue = List.of(queue)..shuffle();
      var current = queue.indexWhere((i) => i.key == item.key);
      if (current < 0) { queue = [item]; current = 0; }
      final first = await _episode(item);
      await _library.remember(item);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final prefs = AppSettingsService();
      final autoplay = await prefs.isSonarTubeAutoplayEnabled();
      if (!mounted) return;
      SonarMusicItem currentItem() => queue[current];
      Future<PodcastEpisode?> navigate(int direction) async {
        final target = current + direction;
        if (target < 0 || target >= queue.length) return null;
        final next = queue[target];
        final result = await _episode(next); // Never advance on a failed resolve.
        await _library.remember(next);
        current = target;
        return result;
      }
      final extra = <PodcastPlayerExtraAction>[
        PodcastPlayerExtraAction(id: 'favorite', label: () =>
          _favorites.contains(currentItem().key) ? _label('remove') : _label('add'),
          icon: Icons.favorite_border, onPressed: () => _toggleFavorite(currentItem())),
        PodcastPlayerExtraAction(id: 'share', label: () => _label('share'),
          icon: Icons.share, pauseBeforeOpen: true,
          onPressed: () => _shareItem(currentItem())),
        PodcastPlayerExtraAction(id: 'artist', label: () => _label('artist_open'),
          icon: Icons.person_outline, pauseBeforeOpen: true,
          onPressed: () => _openArtist(currentItem())),
        if (item.albumId != null)
          PodcastPlayerExtraAction(id: 'album', label: () => _label('album_open'),
            icon: Icons.album_outlined, pauseBeforeOpen: true,
            onPressed: () => _openAlbum(currentItem())),
        if (item.kind == 'video') ...[
          PodcastPlayerExtraAction(id: 'comments',
            label: () => l10n.sonarTubeViewComments, icon: Icons.comment_outlined,
            pauseBeforeOpen: true,
            onPressed: () => _openVideoInfo(currentItem(), 'comments')),
          PodcastPlayerExtraAction(id: 'transcript',
            label: () => l10n.sonarTubeTranscribeVideo, icon: Icons.subject,
            pauseBeforeOpen: true,
            onPressed: () => _openVideoInfo(currentItem(), 'transcript')),
          PodcastPlayerExtraAction(id: 'description',
            label: () => l10n.sonarTubeViewDescription,
            icon: Icons.description_outlined, pauseBeforeOpen: true,
            onPressed: () => _openVideoInfo(currentItem(), 'description')),
        ],
        if (_canSave(item))
          PodcastPlayerExtraAction(id: 'save_media', label: () => _label('save'),
            icon: Icons.download_outlined, pauseBeforeOpen: true,
            onPressed: () => _save(currentItem())),
        if (_canSave(item) && item.kind == 'video')
          PodcastPlayerExtraAction(id: 'create_ad',
            label: () => l10n.audioDescriptionCreateAiTitle,
            icon: Icons.auto_awesome, pauseBeforeOpen: true,
            onPressed: () => _createAd(currentItem())),
      ];
      if (mounted) setState(() => _opening = null);
      await Navigator.push<void>(context, MaterialPageRoute(
        settings: const RouteSettings(name: '/sonarmusic/player'),
        builder: (_) => PodcastEpisodePlayerScreen(
          speedCategory: MediaPlaybackSpeedCategory.sonartube,
          episode: first,
          isVideoSupported: item.kind == 'video',
          refreshEpisode: () => _episode(currentItem()),
          navigateEpisode: queue.length > 1 ? navigate : null,
          hasPreviousEpisode: () => current > 0,
          hasNextEpisode: () => current + 1 < queue.length,
          previousEpisodeLabel: l10n.sonarTubePreviousTrack,
          nextEpisodeLabel: l10n.sonarTubeNextTrack,
          showPreviousEpisodeAction: true,
          showNextEpisodeAction: true,
          autoNavigateNext: forceAutoplay || autoplay,
          extraActions: extra,
        )));
    } catch (e) { if (mounted) _showError(e.toString()); }
    finally {
      if (mounted) {
        setState(() => _opening = null);
        await _restoreItemFocus(item);
      }
    }
  }
  Future<void> _restoreItemFocus(SonarMusicItem item) async {
    if (!mounted) return;
    final index = _items.indexWhere((entry) => entry.key == item.key);
    if (index < 0) return;
    await _accessible.focusToReturn('item_$index');
  }
  Future<void> _openItem(SonarMusicItem item) async {
    if (_busy || !mounted || !item.available) return;
    if (item.playable) return _play(item);
    if (item.browsable) {
      await Navigator.push<void>(context, MaterialPageRoute(
        settings: const RouteSettings(name: '/sonarmusic/collection'),
        builder: (_) => SonarMusicScreen(collection: item,
          service: _service, library: _library)));
      await _refreshFavorites();
      await _restoreItemFocus(item);
    }
  }
  Future<void> _playAll({bool shuffle = false}) async {
    final playable = _items.where((i) => i.playable).toList();
    if (playable.isEmpty) return;
    if (shuffle) playable.shuffle();
    await _play(playable.first, shuffle: shuffle, forceAutoplay: true);
  }

  Widget _itemVisual(SonarMusicItem item, int i) {
    final isFav = _favorites.contains(item.key);
    final subtitle = [item.kind == 'song' ? _label('song') :
      item.kind == 'video' ? _label('video') : _label(item.kind),
      if (item.artist != null) item.artist!,
      if (item.duration != null) item.duration!,
      if (item.subtitle != null) item.subtitle!].join(' · ');
    final actions = <CustomSemanticsAction, VoidCallback>{
      CustomSemanticsAction(label: isFav ? _label('remove') : _label('add')):
        () => _toggleFavorite(item, focusId: 'item_$i'),
      CustomSemanticsAction(label: _label('share')):
        () => _shareItem(item),
      if (item.playable) CustomSemanticsAction(label: _label('artist_open')):
        () => _openArtist(item),
      if (item.albumId != null) CustomSemanticsAction(label: _label('album_open')):
        () => _openAlbum(item),
      if (item.kind == 'video') ...{
        CustomSemanticsAction(label: AppLocalizations.of(context).sonarTubeViewComments):
          () => _openVideoInfo(item, 'comments'),
        CustomSemanticsAction(label: AppLocalizations.of(context).sonarTubeTranscribeVideo):
          () => _openVideoInfo(item, 'transcript'),
        CustomSemanticsAction(label: AppLocalizations.of(context).sonarTubeViewDescription):
          () => _openVideoInfo(item, 'description'),
      },
      if (_canSave(item)) CustomSemanticsAction(label: _label('save')):
        () => _save(item),
    };
    return Semantics(
      container: true, button: true, label: '${item.title}, $subtitle',
      onTap: !_busy ? () => _openItem(item) : null,
      customSemanticsActions: actions,
      child: ExcludeSemantics(child: Card(child: Column(children: [
        ListTile(
          leading: item.thumbnail != null ? Image.network(item.thumbnail!,
            width: 56, height: 56, errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.music_note)) : const Icon(Icons.music_note),
          title: Text(item.title), subtitle: Text(subtitle),
          onTap: !_busy ? () => _openItem(item) : null),
        Wrap(spacing: 4, children: [
          IconButton(tooltip: isFav ? _label('remove') : _label('add'),
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
            onPressed: () => _toggleFavorite(item, focusId: 'item_$i')),
          IconButton(tooltip: _label('share'), icon: const Icon(Icons.share),
            onPressed: () => _shareItem(item)),
          if (item.playable) IconButton(tooltip: _label('artist_open'),
            icon: const Icon(Icons.person), onPressed: () => _openArtist(item)),
          if (item.albumId != null) IconButton(tooltip: _label('album_open'),
            icon: const Icon(Icons.album), onPressed: () => _openAlbum(item)),
          if (item.kind == 'video') IconButton(
            tooltip: AppLocalizations.of(context).sonarTubeViewComments,
            icon: const Icon(Icons.comment_outlined),
            onPressed: () => _openVideoInfo(item, 'comments')),
          if (item.kind == 'video') IconButton(
            tooltip: AppLocalizations.of(context).sonarTubeTranscribeVideo,
            icon: const Icon(Icons.subject),
            onPressed: () => _openVideoInfo(item, 'transcript')),
          if (item.kind == 'video') IconButton(
            tooltip: AppLocalizations.of(context).sonarTubeViewDescription,
            icon: const Icon(Icons.description_outlined),
            onPressed: () => _openVideoInfo(item, 'description')),
          if (_canSave(item)) IconButton(tooltip: _label('save'),
            icon: const Icon(Icons.download), onPressed: () => _save(item)),
        ]),
      ]))));
  }
  Widget _buildList() {
    final l10n = AppLocalizations.of(context);
    final rows = <AccessibleListRow>[];
    if (_home) {
      for (final type in ['favorites', 'recent', 'open']) {
        rows.add(AccessibleListRow(id: type, title: _label(type), kind: 'button',
          flutterChild: OutlinedButton(onPressed: () => type == 'open'
            ? _openUrl() : _openLibrary(type), child: Text(_label(type)))));
      }
      rows.add(AccessibleListRow(id: 'search_field', title: l10n.search,
        kind: 'textField', value: _searchController.text,
        placeholder: _label('search_hint'), textInputAction: 'search',
        onSubmitted: (_) => _search(),
        flutterChild: TextField(controller: _searchController,
          focusNode: _searchFocus,
          decoration: InputDecoration(labelText: _label('search_hint'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(icon: const Icon(Icons.clear),
              tooltip: l10n.clearSearch,
              onPressed: () { _searchController.clear(); setState(() {}); _searchFocus.requestFocus(); })),
          onSubmitted: (_) => _search())));
      for (final kind in ['all', 'song', 'album', 'artist', 'playlist', 'video']) {
        rows.add(AccessibleListRow(id: 'filter_$kind', title: _label(kind),
          kind: 'button', selected: _type == kind,
          flutterChild: RadioListTile<String>(
            title: Text(_label(kind)), value: kind, selected: _type == kind)));
      }
      rows.add(AccessibleListRow(id: 'suggest', title: _label('suggest'), kind: 'button',
        flutterChild: OutlinedButton(onPressed: _suggest, child: Text(_label('suggest')))));
      rows.add(AccessibleListRow(id: 'search', title: l10n.search, kind: 'button',
        flutterChild: FilledButton(onPressed: _search, child: Text(l10n.search))));
    }
    if (_isCollection) {
      rows.add(AccessibleListRow(id: 'collection_title', title: _title ?? widget.collection!.title,
        kind: 'text', accessibilityButtonTrait: false));
      if (_description?.isNotEmpty == true) {
        rows.add(AccessibleListRow(
          id: 'description', title: _description!, kind: 'text',
          accessibilityButtonTrait: false));
      }
    }
    if ((_isCollection || widget.libraryType != null) && _items.any((e) => e.playable)) {
      rows.add(AccessibleListRow(id: 'play_all', title: _label('play_all'),
        kind: 'button', flutterChild: FilledButton.icon(
          icon: const Icon(Icons.play_arrow), label: Text(_label('play_all')),
          onPressed: _playAll)));
      rows.add(AccessibleListRow(id: 'shuffle', title: _label('shuffle'),
        kind: 'button', flutterChild: OutlinedButton.icon(
          icon: const Icon(Icons.shuffle), label: Text(_label('shuffle')),
          onPressed: () => _playAll(shuffle: true))));
    }
    if (_loading) {
      rows.add(AccessibleListRow(id: 'loading',
        title: l10n.loading, kind: 'text'));
    }
    if (_error != null) {
      rows.add(AccessibleListRow(id: 'error', title: _error.toString(), kind: 'text'));
      rows.add(AccessibleListRow(id: 'retry', title: l10n.retry,
        kind: 'button', flutterChild: FilledButton(onPressed: _load,
          child: Text(l10n.retry))));
    }
    if (!_home && !_loading && _items.isEmpty && _error == null) {
      rows.add(AccessibleListRow(id: 'empty', title: _label('empty'), kind: 'text'));
    }
    for (var i=0; i<_items.length; i++) {
      final item = _items[i];
      final isFav = _favorites.contains(item.key);
      rows.add(AccessibleListRow(id: 'item_$i', title: item.title,
        subtitle: [item.kind == 'song' ? _label('song') :
          item.kind == 'video' ? _label('video') : _label(item.kind),
          if (item.artist != null) item.artist!,
          if (item.duration != null) item.duration!,
          if (item.subtitle != null) item.subtitle!].join(' · '),
        enabled: item.available && !_busy,
        actions: [
          AccessibleCustomAction(id: 'favorite', label: isFav ? _label('remove') : _label('add')),
          AccessibleCustomAction(id: 'share', label: _label('share')),
          if (item.playable) AccessibleCustomAction(id: 'artist', label: _label('artist_open')),
          if (item.albumId != null) AccessibleCustomAction(id: 'album', label: _label('album_open')),
          if (item.kind == 'video') ...[
            AccessibleCustomAction(id: 'comments', label: l10n.sonarTubeViewComments),
            AccessibleCustomAction(id: 'transcript', label: l10n.sonarTubeTranscribeVideo),
            AccessibleCustomAction(id: 'description', label: l10n.sonarTubeViewDescription),
          ],
          if (_canSave(item)) AccessibleCustomAction(id: 'save_media', label: _label('save')),
          if (_canSave(item) && item.kind == 'video') AccessibleCustomAction(
            id: 'create_ai_audiodescription', label: l10n.audioDescriptionCreateAiTitle),
        ],
        flutterChild: _itemVisual(item, i)));
    }
    if (_nextToken != null && _nextToken!.isNotEmpty) {
      rows.add(AccessibleListRow(id: 'more', title: _label('load'),
        kind: 'button', enabled: !_loadingMore,
        flutterChild: FilledButton(onPressed: _loadingMore ? null : () => _load(more: true),
          child: Text(_loadingMore ? l10n.loading : _label('load')))));
    }
    return RadioGroup<String>(
      groupValue: _type,
      onChanged: (type) {
        if (type != null) {
          setState(() => _type = type);
        }
      },
      child: UniversalAccessibleList(debugTag: 'sonarmusic',
        controller: _accessible, sections: [AccessibleListSection(rows: rows)],
      onEvent: (event) async {
        final id = event.id ?? '';
        if (id == 'search_field' && event.type == 'textChanged') {
          _searchController.text = event.value?.toString() ?? ''; return;
        }
        if (id == 'search_field' && event.type == 'submit') { await _search(); return; }
        if (id.startsWith('item_')) {
          final index = int.tryParse(id.substring(5));
          if (index == null || index < 0 || index >= _items.length) return;
          final item = _items[index];
          if (event.type == 'activate') await _openItem(item);
          if (event.type == 'customAction') {
            switch (event.action) {
              case 'favorite': await _toggleFavorite(item, focusId: id);
              case 'share': await _shareItem(item);
              case 'artist': await _openArtist(item);
              case 'album': await _openAlbum(item);
              case 'comments': await _openVideoInfo(item, 'comments');
              case 'transcript': await _openVideoInfo(item, 'transcript');
              case 'description': await _openVideoInfo(item, 'description');
              case 'save_media': await _save(item);
              case 'create_ai_audiodescription': await _createAd(item);
            }
          }
          return;
        }
        if (event.type != 'activate') return;
        if (id == 'search') await _search();
        if (id == 'suggest') await _suggest();
        if (id == 'favorites' || id == 'recent') await _openLibrary(id);
        if (id == 'open') await _openUrl();
        if (id.startsWith('filter_')) setState(() => _type = id.substring(7));
        if (id == 'retry') await _load();
        if (id == 'more') await _load(more: true);
        if (id == 'play_all') await _playAll();
        if (id == 'shuffle') await _playAll(shuffle: true);
      }));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SonarpadAppBar(title: Text(_home ? 'SonarMusic'
      : widget.libraryType != null ? _label(widget.libraryType!)
      : _isCollection ? (_title ?? widget.collection!.title) : 'SonarMusic'),
      actions: [if (!_home) IconButton(icon: const Icon(Icons.search),
        tooltip: AppLocalizations.of(context).search,
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => SonarMusicScreen(service: _service, library: _library))) )]),
    body: SafeArea(child: _buildList()));
}

/// Read-only video information. Reuses SonarTube's existing comments,
/// transcript and description services, without duplicating their parsers.
class SonarMusicVideoInfoScreen extends StatefulWidget {
  const SonarMusicVideoInfoScreen({super.key, required this.item, required this.mode});
  final SonarMusicItem item;
  final String mode;
  @override
  State<SonarMusicVideoInfoScreen> createState() => _SonarMusicVideoInfoScreenState();
}
class _SonarMusicVideoInfoScreenState extends State<SonarMusicVideoInfoScreen> {
  final _tube = SonarTubeService();
  final _accessible = AccessibleListController(debugName: 'sonarmusic-info');
  List<String> _lines = [];
  String? _next;
  int _page = 1;
  bool _loading = false;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final video = widget.item.toVideoItem();
      List<String> lines;
      String? next;
      if (widget.mode == 'comments') {
        final page = await _tube.comments(video,
          token: more ? _next : null, page: more ? _page + 1 : 1);
        lines = page.items.map((comment) => [
          if (comment.author != null) comment.author!,
          comment.text,
          if (comment.published != null) comment.published!,
        ].join(', ')).toList();
        next = page.nextToken;
      } else if (widget.mode == 'transcript') {
        final transcript = await _tube.transcribe(video);
        lines = transcript.paragraphs.isNotEmpty
          ? transcript.paragraphs : [transcript.text];
      } else {
        lines = [await _tube.videoDescription(video)];
      }
      if (!mounted) return;
      setState(() {
        if (more) { _lines.addAll(lines); _page++; }
        else { _lines = lines; _page = 1; }
        _next = next;
      });
    } catch (e) { if (mounted) setState(() => _error = '$e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.mode == 'comments' ? l10n.sonarTubeViewComments
      : widget.mode == 'transcript' ? l10n.sonarTubeTranscribeVideo
      : l10n.sonarTubeViewDescription;
    final rows = <AccessibleListRow>[
      if (_loading) AccessibleListRow(id: 'loading', title: l10n.loading,
        kind: 'text', accessibilityButtonTrait: false),
      if (_error != null) AccessibleListRow(id: 'error', title: _error!,
        kind: 'text', accessibilityButtonTrait: false),
      if (_error != null) AccessibleListRow(id: 'retry', title: l10n.retry,
        flutterChild: FilledButton(onPressed: _load, child: Text(l10n.retry))),
      for (var i = 0; i < _lines.length; i++) AccessibleListRow(
        id: 'text_$i', title: _lines[i], kind: 'text',
        accessibilityButtonTrait: false,
        flutterChild: Padding(padding: const EdgeInsets.all(12),
          child: SelectableText(_lines[i]))),
      if (_next != null && _next!.isNotEmpty) AccessibleListRow(
        id: 'more', title: l10n.sonarTubeLoadMore,
        flutterChild: FilledButton(onPressed: () => _load(more: true),
          child: Text(l10n.sonarTubeLoadMore))),
    ];
    return Scaffold(appBar: SonarpadAppBar(title: Text(title)),
      body: UniversalAccessibleList(controller: _accessible,
        sections: [AccessibleListSection(rows: rows)],
        onEvent: (event) async {
          if (event.type == 'activate' && event.id == 'retry') await _load();
          if (event.type == 'activate' && event.id == 'more') await _load(more: true);
        }));
  }
}
