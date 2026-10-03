import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/leaderboard/data/leaderboard_repository.dart';
import 'package:asli_app/features/leaderboard/presentation/leaderboard_providers.dart';
import 'package:asli_app/features/leaderboard/presentation/leaderboard_widgets.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sıralama')),
    body: const LeaderboardSection(),
  );
}

// Shared detailed view: the profile supplies its own outer scrolling surface.
class LeaderboardSection extends ConsumerStatefulWidget {
  const LeaderboardSection({this.embedded = false, super.key});
  final bool embedded;

  @override
  ConsumerState<LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends ConsumerState<LeaderboardSection> {
  String _period = 'weekly';
  bool _byLesson = false;
  String? _courseId;
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lessons = ref.watch(leaderboardCoursesProvider);
    final available = lessons.value ?? const <LeaderboardCourse>[];
    final selectedLesson =
        _courseId ?? (available.isEmpty ? null : available.first.id);
    final selection = (
      period: _period,
      courseId: _byLesson ? selectedLesson : null,
      offset: _offset,
    );
    final ranking = !_byLesson || selectedLesson != null
        ? ref.watch(leaderboardProvider(selection))
        : null;
    Future<void> refresh() async {
      ref.invalidate(leaderboardCoursesProvider);
      ref.invalidate(leaderboardProvider(selection));
      if (_byLesson) {
        await ref.read(leaderboardCoursesProvider.future);
      }
      if (ranking != null) {
        await ref.read(leaderboardProvider(selection).future);
      }
    }

    final children = <Widget>[
      if (widget.embedded)
        Row(
          children: [
            Expanded(
              child: Text(
                'Öğrenci sıralaması',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Sıralamayı yenile',
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),

      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'weekly', label: Text('Bu Hafta')),
            ButtonSegment(value: 'monthly', label: Text('Bu Ay')),
            ButtonSegment(value: 'allTime', label: Text('Tüm Zamanlar')),
          ],
          selected: {_period},
          showSelectedIcon: false,
          onSelectionChanged: (value) => setState(() {
            _period = value.first;
            _offset = 0;
          }),
        ),
      ),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Genel')),
          ButtonSegment(value: true, label: Text('Modüle Göre')),
        ],
        selected: {_byLesson},
        showSelectedIcon: false,
        onSelectionChanged: (value) => setState(() {
          _byLesson = value.first;
          _offset = 0;
        }),
      ),
      if (_byLesson) ...[
        const SizedBox(height: 16),
        lessons.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorTile(
            message: networkErrorMessage(error),
            retry: () => ref.invalidate(leaderboardCoursesProvider),
          ),
          data: (items) => items.isEmpty
              ? const ListTile(title: Text('Henüz seçilebilir modül yok.'))
              : DropdownMenu<String>(
                  leadingIcon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Modül'),
                  expandedInsets: EdgeInsets.zero,
                  initialSelection: selectedLesson,
                  dropdownMenuEntries: [
                    for (final lesson in items)
                      DropdownMenuEntry(value: lesson.id, label: lesson.title),
                  ],
                  onSelected: (id) => setState(() {
                    _courseId = id;
                    _offset = 0;
                  }),
                ),
        ),
      ],
      const SizedBox(height: 24),
      if (ranking != null)
        ranking.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => _ErrorTile(
            message: networkErrorMessage(error),
            retry: () => ref.invalidate(leaderboardProvider(selection)),
          ),
          data: (data) => _RankingContent(
            data: data,
            isLesson: _byLesson,
            period: _period,
            onPrevious: _offset == 0
                ? null
                : () => setState(() => _offset -= 20),
            onNext: _offset + data.entries.length >= data.totalUsers
                ? null
                : () => setState(() => _offset += 20),
          ),
        ),
      if (_byLesson && lessons.hasValue && available.isEmpty)
        Text(
          'Bu modülde henüz sıralama oluşmadı.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
    ];
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: children,
      ),
    );
  }
}

class _RankingContent extends StatelessWidget {
  const _RankingContent({
    required this.data,
    required this.isLesson,
    required this.period,
    required this.onPrevious,
    required this.onNext,
  });
  final LeaderboardData data;
  final bool isLesson;
  final String period;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (data.entries.isEmpty && data.offset == 0) {
      return Card(
        child: ListTile(
          title: Text(
            isLesson
                ? 'Bu modülde henüz sıralama oluşmadı.'
                : 'Sıralama henüz oluşmadı.',
          ),
          subtitle: const Text('Quizlerini tamamlayarak sıralamada yerini al.'),
        ),
      );
    }
    final top = data.offset == 0
        ? data.entries.take(3).toList()
        : <LeaderboardEntry>[];
    final rest = data.offset == 0 ? data.entries.skip(3) : data.entries;
    final current = data.currentUser;
    final currentVisible = data.entries.any((entry) => entry.isCurrentUser);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isLesson
              ? (data.courseName ?? 'Modül sıralaması')
              : period == 'weekly'
              ? 'Bu haftanın liderleri'
              : period == 'monthly'
              ? 'Bu ayın liderleri'
              : 'Tüm zamanların liderleri',
          style: theme.textTheme.headlineSmall,
        ),
        Text(
          isLesson
              ? '${data.courseQuizCount ?? 0} quiz • Tamamlanan sonuçlar'
              : 'Tüm modüllerdeki quiz sonuçları',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (top.isNotEmpty) LeaderboardPodium(entries: top, isLesson: isLesson),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            isLesson ? 'Modül sıralaması' : 'Sıralama',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final entry in rest)
            LeaderboardListItem(entry: entry, isLesson: isLesson),
        ],
        if (current != null && !currentVisible) ...[
          const Divider(height: 28),
          Text('Senin sıran', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          LeaderboardListItem(entry: current, isLesson: isLesson),
        ],
        if (onPrevious != null || onNext != null)
          Wrap(
            spacing: 16,
            children: [
              TextButton(onPressed: onPrevious, child: const Text('Önceki')),
              TextButton(onPressed: onNext, child: const Text('Sonraki')),
            ],
          ),
      ],
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(message),
      trailing: IconButton(
        tooltip: 'Yeniden dene',
        onPressed: retry,
        icon: const Icon(Icons.refresh),
      ),
    ),
  );
}
