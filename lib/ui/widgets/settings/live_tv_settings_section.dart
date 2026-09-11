import 'package:flutter/material.dart';

import '../../../services/storage_service.dart';
import '../../theme/app_tokens.dart';
import '../app_surface.dart';
import '../tv_focusable.dart';

class LiveTvSettingsSection extends StatelessWidget {
  final TextEditingController iptvController;
  final StorageService storageService;

  const LiveTvSettingsSection({
    super.key,
    required this.iptvController,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            'LIVE TV PLAYLIST (M3U)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tokens.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Custom IPTV Playlist URL',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: iptvController,
                style: TextStyle(color: tokens.textPrimary),
                decoration: InputDecoration(
                  hintText: 'https://example.com/playlist.m3u',
                  hintStyle: TextStyle(color: tokens.textMuted),
                  filled: true,
                  fillColor: tokens.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: tokens.borderRadiusSm,
                    borderSide: BorderSide(color: tokens.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: tokens.borderRadiusSm,
                    borderSide: BorderSide(color: tokens.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: tokens.borderRadiusSm,
                    borderSide: BorderSide(
                      color: tokens.primaryAccent,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TvFocusable(
                onTap: () async {
                  await storageService.setCustomIptvUrl(
                    iptvController.text.trim(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'IPTV Playlist URL saved successfully!',
                        ),
                        backgroundColor: tokens.liveColor,
                      ),
                    );
                  }
                },
                borderRadius: tokens.borderRadiusSm,
                scaleFactor: 1.04,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.primaryAccent,
                    borderRadius: tokens.borderRadiusSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.save_rounded,
                        color: theme.colorScheme.onPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Save Playlist',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
