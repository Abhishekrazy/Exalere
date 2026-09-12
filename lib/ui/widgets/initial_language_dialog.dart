import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../theme/app_tokens.dart';
import 'tv/tv_popup_scope.dart';
import 'tv_focusable.dart';

class LanguageOption {
  final String name;
  final String nativeName;
  final String code;

  const LanguageOption({
    required this.name,
    required this.nativeName,
    required this.code,
  });
}

class InitialLanguageDialog extends StatefulWidget {
  final bool isModalFromSettings;

  const InitialLanguageDialog({super.key, this.isModalFromSettings = false});

  static Future<void> show(
    BuildContext context, {
    bool isModalFromSettings = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: isModalFromSettings,
      builder: (ctx) =>
          InitialLanguageDialog(isModalFromSettings: isModalFromSettings),
    );
  }

  static const List<LanguageOption> supportedLanguages = [
    LanguageOption(name: 'English', nativeName: 'English', code: 'en'),
    LanguageOption(name: 'Hindi', nativeName: 'हिन्दी', code: 'hi'),
    LanguageOption(name: 'Tamil', nativeName: 'தமிழ்', code: 'ta'),
    LanguageOption(name: 'Telugu', nativeName: 'తెలుగు', code: 'te'),
    LanguageOption(name: 'Malayalam', nativeName: 'മലയാളം', code: 'ml'),
    LanguageOption(name: 'Kannada', nativeName: 'ಕನ್ನಡ', code: 'kn'),
    LanguageOption(name: 'Bengali', nativeName: 'বাংলা', code: 'bn'),
    LanguageOption(name: 'Marathi', nativeName: 'मराठी', code: 'mr'),
    LanguageOption(name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', code: 'pa'),
    LanguageOption(name: 'Gujarati', nativeName: 'ગુજરાતી', code: 'gu'),
    LanguageOption(name: 'Spanish', nativeName: 'Español', code: 'es'),
    LanguageOption(name: 'French', nativeName: 'Français', code: 'fr'),
    LanguageOption(name: 'German', nativeName: 'Deutsch', code: 'de'),
    LanguageOption(name: 'Japanese', nativeName: '日本語', code: 'ja'),
    LanguageOption(name: 'Korean', nativeName: '한국어', code: 'ko'),
    LanguageOption(name: 'Chinese', nativeName: '中文', code: 'zh'),
    LanguageOption(name: 'Russian', nativeName: 'Русский', code: 'ru'),
    LanguageOption(name: 'Arabic', nativeName: 'العربية', code: 'ar'),
    LanguageOption(name: 'Portuguese', nativeName: 'Português', code: 'pt'),
    LanguageOption(name: 'Italian', nativeName: 'Italiano', code: 'it'),
    LanguageOption(name: 'Turkish', nativeName: 'Türkçe', code: 'tr'),
    LanguageOption(
      name: 'Original Audio',
      nativeName: 'Default Track',
      code: 'orig',
    ),
  ];

  @override
  State<InitialLanguageDialog> createState() => _InitialLanguageDialogState();
}

class _InitialLanguageDialogState extends State<InitialLanguageDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late String _selectedLanguage;
  List<LanguageOption> _filtered = [];

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    _selectedLanguage = app.defaultAudioLanguage ?? 'English';
    _filtered = InitialLanguageDialog.supportedLanguages;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = InitialLanguageDialog.supportedLanguages;
      } else {
        _filtered = InitialLanguageDialog.supportedLanguages
            .where(
              (l) =>
                  l.name.toLowerCase().contains(q) ||
                  l.nativeName.toLowerCase().contains(q) ||
                  l.code.toLowerCase().contains(q),
            )
            .toList();
      }
    });
  }

  Future<void> _applySelection(String language) async {
    final app = context.read<AppProvider>();
    await app.setDefaultAudioLanguage(language);
    await app.setHasPromptedInitialLanguage(true);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Default audio language set to $language',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _skip() async {
    final app = context.read<AppProvider>();
    if (app.defaultAudioLanguage == null) {
      await app.setDefaultAudioLanguage('English');
    }
    await app.setHasPromptedInitialLanguage(true);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 600;
    final isTv = context.watch<AppProvider>().isTvMode;

    return PopScope(
      canPop: widget.isModalFromSettings,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !widget.isModalFromSettings) {
          _skip();
        }
      },
      child: TvPopupScope(
        child: Dialog(
          backgroundColor: tokens.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: tokens.borderRadiusLg,
            side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : (isTv ? 56 : 40),
            vertical: isCompact ? 24 : 36,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 580,
              maxHeight: size.height * 0.84,
            ),
            child: Padding(
              padding: EdgeInsets.all(isTv ? 24 : 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: tokens.borderRadiusMd,
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Icon(
                          Icons.translate_rounded,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose Audio Language',
                              style: TextStyle(
                                fontSize: isTv ? 19 : 18,
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Set your default language for all movies & series. If available, videos will automatically play in this language.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: tokens.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isModalFromSettings)
                        TvFocusable(
                          borderRadius: tokens.borderRadiusPill,
                          onTap: () => Navigator.of(context).pop(),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.close_rounded,
                              color: tokens.textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard,
                      borderRadius: tokens.borderRadiusMd,
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearch,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'Search language (e.g. Hindi, English, Tamil)...',
                        hintStyle: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: tokens.textSecondary,
                          size: 20,
                        ),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: tokens.textSecondary,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onSearch('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Language Grid / List
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No matching languages found.',
                              style: TextStyle(color: tokens.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            clipBehavior: Clip.none,
                            cacheExtent: 350.0,
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final lang = _filtered[index];
                              final isSelected = lang.name == _selectedLanguage;

                              return TvFocusable(
                                autofocus:
                                    index == 0 && !widget.isModalFromSettings,
                                scaleFactor: 1.02,
                                borderRadius: tokens.borderRadiusSm,
                                onTap: () {
                                  setState(() => _selectedLanguage = lang.name);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.15,
                                          )
                                        : tokens.surfaceCard,
                                    borderRadius: tokens.borderRadiusSm,
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : tokens.borderSubtle.withValues(
                                              alpha: 0.6,
                                            ),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : tokens.surfaceElevated,
                                        ),
                                        child: Center(
                                          child: Text(
                                            lang.code.toUpperCase().substring(
                                              0,
                                              lang.code.length.clamp(1, 2),
                                            ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? theme.colorScheme.onPrimary
                                                  : tokens.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lang.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                    : tokens.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              lang.nativeName,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: tokens.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: theme.colorScheme.primary,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Bottom Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!widget.isModalFromSettings)
                        TvFocusable(
                          borderRadius: tokens.borderRadiusPill,
                          onTap: _skip,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Text(
                              'Skip (English)',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      TvFocusable(
                        scaleFactor: 1.05,
                        borderRadius: tokens.borderRadiusPill,
                        onTap: () => _applySelection(_selectedLanguage),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                tokens.secondaryAccent,
                              ],
                            ),
                            borderRadius: tokens.borderRadiusPill,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                color: theme.colorScheme.onPrimary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Save & Continue',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ],
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
    );
  }
}
