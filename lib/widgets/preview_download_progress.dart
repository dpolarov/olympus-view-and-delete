import 'package:flutter/material.dart';

import '../constants.dart';
import '../theme/olympus_theme.dart';
import '../services/preview_download_queue.dart';

/// Compact file-count progress indicator shared by preview and the home screen.
class PreviewDownloadProgress extends StatelessWidget {
  const PreviewDownloadProgress({super.key, this.queue});

  final PreviewDownloadQueue? queue;

  @override
  Widget build(BuildContext context) {
    final downloads = queue ?? PreviewDownloadQueue.instance;
    return ListenableBuilder(
      listenable: downloads,
      builder: (context, _) {
        if (!downloads.isBusy) return const SizedBox.shrink();

        final language = Localizations.localeOf(context).languageCode;
        final done = downloads.finishedCount;
        final total = downloads.totalCount;
        final remaining = downloads.queuedCount;
        final failed = downloads.failedCount;
        final title = switch (language) {
          'ru' => 'Загрузка: $done из $total · осталось $remaining',
          'uk' => 'Завантаження: $done із $total · залишилось $remaining',
          _ => 'Downloads: $done of $total · $remaining remaining',
        };
        final errorText = switch (language) {
          'ru' => 'Ошибок: $failed',
          'uk' => 'Помилок: $failed',
          _ => 'Failed: $failed',
        };
        final filename = downloads.activeFilename;
        final current = switch (language) {
          'ru' => 'Сейчас: $filename',
          'uk' => 'Зараз: $filename',
          _ => 'Now: $filename',
        };

        return Container(
          decoration: const BoxDecoration(
            color: OlympusPalette.card,
            border: Border(
              top: BorderSide(color: OlympusPalette.border, width: 0.7),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OlympusPalette.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (failed > 0)
                    Text(
                      errorText,
                      style: const TextStyle(color: kErrorColor, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: downloads.progress,
                minHeight: 4,
                backgroundColor: kBorderColor,
                valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryColor),
              ),
              if (filename != null) ...[
                const SizedBox(height: 4),
                Text(
                  current,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: OlympusPalette.secondaryText, fontSize: 11),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
