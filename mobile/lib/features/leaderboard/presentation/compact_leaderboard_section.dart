import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/leaderboard/presentation/leaderboard_providers.dart';
import 'package:asli_app/features/leaderboard/presentation/leaderboard_widgets.dart';

class CompactLeaderboardSection extends ConsumerWidget {
  const CompactLeaderboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final data = ref.watch(homeLeaderboardProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Bu Haftanın Liderleri',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.pushNamed(AppRoutes.leaderboard),
              child: const Text('Tümünü Gör →'),
            ),
          ],
        ),
        Text(
          'Tüm dersler • Bu hafta',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        data.when(
          loading: () =>
              const Card(child: ListTile(title: Text('Sıralama yükleniyor…'))),
          error: (error, _) => Card(
            child: ListTile(
              title: Text(networkErrorMessage(error)),
              trailing: IconButton(
                tooltip: 'Yeniden dene',
                onPressed: () => ref.invalidate(homeLeaderboardProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          data: (result) {
            if (result.entries.isEmpty) {
              return const Card(
                child: ListTile(
                  title: Text('Sıralama henüz oluşmadı.'),
                  subtitle: Text(
                    'Quizlerini tamamlayarak sıralamada yerini al.',
                  ),
                ),
              );
            }
            final current = result.currentUser;
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (final entry in result.entries)
                      LeaderboardListItem(entry: entry, isLesson: false),
                    if (current != null && current.rank > 3) ...[
                      const SizedBox(height: 8),
                      LeaderboardListItem(entry: current, isLesson: false),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
