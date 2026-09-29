import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/accessibility_feedback_service.dart';
import '../services/app_settings_service.dart';
import '../services/home_customization_service.dart';
import '../services/raiplay_service.dart';
import '../services/raiplay_sound_service.dart';
import '../services/tv_service.dart';
import '../utils/home_item_catalog.dart';
import '../widgets/universal_accessible_view.dart';
import 'category_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settings = AppSettingsService();
  final _customization = HomeCustomizationService();
  final _raiPlaySoundService = RaiPlaySoundService();
  final _raiPlayService = RaiPlayService();
  final _settingsFocusNode = FocusNode(debugLabel: 'home-settings');
  bool _isSecretCodeValid = false;
  bool _isTvCodeValid = false;
  bool _isRaiPlayValid = false;
  bool _isGroupingEnabled = false;
  Set<String> _hiddenHomeItemIds = <String>{};
  List<String> _homeItemOrder = List<String>.from(HomeItemIds.defaultFlatOrder);
  List<String> _readingOrder = List<String>.from(HomeItemIds.readingOrder);
  List<String> _mediaOrder = List<String>.from(HomeItemIds.mediaOrder);
  List<String> _utilityOrder = List<String>.from(HomeItemIds.utilityOrder);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _settingsFocusNode.dispose();
    super.dispose();
  }

  void _restoreSettingsFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _settingsFocusNode.requestFocus();
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (!mounted) return;
        _settingsFocusNode.requestFocus();
      });
    });
  }

  Future<void> _load() async {
    final code = await _settings.getTvSecretCode();
    final isValidTv = TvService().isSecretCodeValid(code);
    final isValidRaiSound = _raiPlaySoundService.isSecretCodeValid(code);
    final isValidRaiPlay = _raiPlayService.isSecretCodeValid(code);
    final isGroupingEnabled = await _settings.isHomeGroupingEnabled();
    final hiddenIds = await _customization.loadHiddenItemIds();
    final itemOrder = await _customization.loadItemOrder();
    final readingOrder = await _customization.loadCategoryOrder(
      categoryId: 'reading',
      defaultOrder: HomeItemIds.readingOrder,
    );
    final mediaOrder = await _customization.loadCategoryOrder(
      categoryId: 'media',
      defaultOrder: HomeItemIds.mediaOrder,
    );
    final utilityOrder = await _customization.loadCategoryOrder(
      categoryId: 'utilities',
      defaultOrder: HomeItemIds.utilityOrder,
    );
    if (!mounted) return;
    setState(() {
      _isTvCodeValid = isValidTv;
      _isSecretCodeValid = isValidRaiSound;
      _isRaiPlayValid = isValidRaiPlay;
      _isGroupingEnabled = isGroupingEnabled;
      _hiddenHomeItemIds = hiddenIds;
      _homeItemOrder = itemOrder;
      _readingOrder = readingOrder;
      _mediaOrder = mediaOrder;
      _utilityOrder = utilityOrder;
    });
  }

  bool _isVisible(String id) =>
      HomeItemIds.alwaysVisible.contains(id) || !_hiddenHomeItemIds.contains(id);

  Future<void> _openSettings(BuildContext context) async {
    final appLanguage = await AccessibilityFeedbackService.goNamed<String>(
      context,
      routeName: '/settings',
    );
    if (!context.mounted) return;
    await _load();
    if (!context.mounted) return;
    if (appLanguage != null) {
      final targetLocale = SonarpadApp.localeForLanguageCode(appLanguage);
      if (targetLocale != Localizations.localeOf(context)) {
        await Future<void>.delayed(Duration.zero);
        if (!context.mounted) return;
        SonarpadApp.setLocale(context, targetLocale);
      }
    }
    _restoreSettingsFocus();
  }

  _HomeButton _buttonForId(
    BuildContext context,
    AppLocalizations l10n,
    String id,
  ) {
    if (id == HomeItemIds.settings) {
      return _HomeButton(
        id: id,
        label: homeItemLabel(l10n, id),
        focusNode: _settingsFocusNode,
        onPressed: () => _openSettings(context),
      );
    }
    if (id == HomeItemIds.info) {
      return _HomeButton(
        id: id,
        label: homeItemLabel(l10n, id),
        onPressed: () => AccessibilityFeedbackService.goNamed(
          context,
          routeName: '/info',
        ),
      );
    }

    final routeName = switch (id) {
      HomeItemIds.documents => '/documents',
      HomeItemIds.calendar => '/calendar',
      HomeItemIds.news => '/news',
      HomeItemIds.weather => '/meteo',
      HomeItemIds.podcasts => '/podcasts',
      HomeItemIds.sonarTube => '/sonartube',
      HomeItemIds.createAiAudioDescription => '/create_ai_audiodescription',
      HomeItemIds.convertMedia => '/convert_media',
      HomeItemIds.mediaCutter => '/media_cutter',
      HomeItemIds.cinema => '/cinema',
      HomeItemIds.radio => '/radio',
      HomeItemIds.tv => '/tv',
      HomeItemIds.raiPlaySound => '/raiplaysound',
      HomeItemIds.raiPlay => '/raiplay',
      HomeItemIds.la7Play => '/la7play',
      HomeItemIds.audioDescriptions => '/audiodescriptions',
      HomeItemIds.sonarpadAudioDescriptions => '/sonarpad_audiodescriptions',
      HomeItemIds.wikipedia => '/wikipedia',
      HomeItemIds.voiceDictionary => '/voice_dictionary',
      HomeItemIds.digitalLibrary => '/bdciechi',
      HomeItemIds.route => '/route',
      HomeItemIds.openingHours => '/orari_apertura',
      HomeItemIds.directory => '/italiaonline',
      HomeItemIds.pharmacy => '/aifa',
      _ => '/',
    };

    return _HomeButton(
      id: id,
      label: homeItemLabel(l10n, id),
      onPressed: () => AccessibilityFeedbackService.goNamed(
        context,
        routeName: routeName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final availableIds = availableHomeItemIds(
      isItalian: l10n.localeName == 'it',
      isTvCodeValid: _isTvCodeValid,
      isRaiPlayValid: _isRaiPlayValid,
      isRaiPlaySoundCodeValid: _isSecretCodeValid,
    );

    List<_HomeButton> buttonsFor(List<String> ids) => ids
        .where((id) => availableIds.contains(id) && _isVisible(id))
        .map((id) => _buttonForId(context, l10n, id))
        .toList(growable: false);

    List<Widget> children;
    if (_isGroupingEnabled) {
      final readingItems = buttonsFor(_readingOrder);
      final mediaItems = buttonsFor(_mediaOrder);
      final utilityItems = buttonsFor(_utilityOrder);
      children = [
        if (readingItems.isNotEmpty)
          _categoryButton(
            context,
            id: 'category_reading',
            title: l10n.categoryReading,
            items: readingItems,
          ),
        if (mediaItems.isNotEmpty)
          _categoryButton(
            context,
            id: 'category_media',
            title: l10n.categoryMedia,
            items: mediaItems,
          ),
        if (utilityItems.isNotEmpty)
          _categoryButton(
            context,
            id: 'category_utilities',
            title: l10n.categoryUtilities,
            items: utilityItems,
          ),
        _buttonForId(context, l10n, HomeItemIds.settings),
        _buttonForId(context, l10n, HomeItemIds.info),
      ];
    } else {
      final visibleOrder = _customization.visibleOrderedIds(
        fullOrder: _homeItemOrder,
        availableIds: availableIds,
        hiddenIds: _hiddenHomeItemIds,
      );
      children = visibleOrder
          .map((id) => _buttonForId(context, l10n, id))
          .toList(growable: false);
    }

    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? UniversalAccessibleList(
                sections: [
                  AccessibleListSection(
                    flutterHeader: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          excludeSemantics: true,
                          child: Image.asset(
                            'assets/images/Sonarpad_Logo.png',
                            height: 92,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            errorBuilder: (context, error, stackTrace) => Text(
                              l10n.appTitle,
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                    rows: children
                        .whereType<_HomeButton>()
                        .map(
                          (button) => AccessibleListRow(
                            id: 'home_${button.id}',
                            title: button.label,
                            onActivate: button.onPressed,
                            flutterChild: button,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                padding: const EdgeInsets.all(16),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Semantics(
                    excludeSemantics: true,
                    child: Image.asset(
                      'assets/images/Sonarpad_Logo.png',
                      height: 92,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (context, error, stackTrace) => Text(
                        l10n.appTitle,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
      ),
    );
  }

  _HomeButton _categoryButton(
    BuildContext context, {
    required String id,
    required String title,
    required List<_HomeButton> items,
  }) {
    return _HomeButton(
      id: id,
      label: title,
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryScreen(
              title: title,
              accessibleItems: items
                  .map(
                    (item) => CategoryAccessibleItem(
                      label: item.label,
                      onPressed: item.onPressed,
                      flutterChild: item,
                    ),
                  )
                  .toList(growable: false),
              children: items,
            ),
          ),
        );
      },
    );
  }
}

class _HomeButton extends StatelessWidget {
  final String id;
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  const _HomeButton({
    required this.id,
    required this.label,
    required this.onPressed,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton(
        focusNode: focusNode,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}
