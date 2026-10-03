import 'package:flutter/material.dart';
import 'package:asli_app/app/theme/app_radius.dart';
import 'package:asli_app/features/leaderboard/data/leaderboard_repository.dart';

const _gold = Color(0xffe8c77e);
const _silver = Color(0xffb9cbd6);
const _bronze = Color(0xffd3a38c);

Color rankColor(int rank) => switch (rank) {
  1 => _gold,
  2 => _silver,
  3 => _bronze,
  _ => const Color(0xffbfc8ff),
};

class LeaderboardAvatar extends StatelessWidget {
  const LeaderboardAvatar({required this.entry, this.size = 28, super.key});
  final LeaderboardEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: entry.isCurrentUser
          ? scheme.primaryContainer
          : rankColor(entry.rank).withValues(alpha: .22),
      foregroundColor: scheme.onSurface,
      child: Text(
        entry.initials,
        style: TextStyle(fontSize: size * .37, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CurrentUserBadge extends StatelessWidget {
  const _CurrentUserBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Sen',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IdentityAndScore extends StatelessWidget {
  const _IdentityAndScore({required this.entry, required this.isLesson});
  final LeaderboardEntry entry;
  final bool isLesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.displayName,
                maxLines: MediaQuery.textScalerOf(context).scale(1) > 1.4
                    ? null
                    : 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (entry.isCurrentUser) ...[
              const SizedBox(width: 6),
              const _CurrentUserBadge(),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          isLesson
              ? '${entry.totalCorrectAnswers} / ${entry.totalQuestionCount} doğru'
              : '${entry.totalCorrectAnswers} doğru',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '${entry.completedQuizCount} quiz • %${entry.accuracyPercentage} başarı',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class LeaderboardListItem extends StatelessWidget {
  const LeaderboardListItem({
    required this.entry,
    required this.isLesson,
    super.key,
  });
  final LeaderboardEntry entry;
  final bool isLesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? scheme.primaryContainer.withValues(alpha: .36)
            : scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: entry.isCurrentUser ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${entry.rank}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: entry.isCurrentUser ? scheme.primary : scheme.onSurface,
              ),
            ),
          ),
          LeaderboardAvatar(entry: entry),
          const SizedBox(width: 10),
          Expanded(
            child: _IdentityAndScore(entry: entry, isLesson: isLesson),
          ),
        ],
      ),
    );
  }
}

class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({
    required this.entries,
    required this.isLesson,
    super.key,
  });
  final List<LeaderboardEntry> entries;
  final bool isLesson;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final entry in entries)
        _PodiumCard(entry: entry, isLesson: isLesson),
    ],
  );
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.entry, required this.isLesson});
  final LeaderboardEntry entry;
  final bool isLesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medalColor = rankColor(entry.rank);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? scheme.primaryContainer.withValues(alpha: .4)
            : Color.alphaBlend(
                medalColor.withValues(alpha: .09),
                scheme.surface,
              ),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: entry.isCurrentUser
              ? scheme.primary
              : medalColor.withValues(alpha: .65),
          width: entry.isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  color: medalColor,
                  size: 27,
                ),
                Text(
                  '${entry.rank}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: medalColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          LeaderboardAvatar(entry: entry, size: 30),
          const SizedBox(width: 11),
          Expanded(
            child: _IdentityAndScore(entry: entry, isLesson: isLesson),
          ),
        ],
      ),
    );
  }
}
