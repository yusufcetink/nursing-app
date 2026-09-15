import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/user_management/data/user_activity_repository.dart';
import 'package:asli_app/features/user_management/domain/models/user_activity_analytics.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userActivityProvider =
    FutureProvider.family<UserActivityAnalytics, AnalyticsRange>(
      (ref, range) =>
          ref.watch(userActivityRepositoryProvider).getAnalytics(range),
    );

class UserActivityPage extends ConsumerStatefulWidget {
  const UserActivityPage({required this.userId, super.key});
  final String userId;

  @override
  ConsumerState<UserActivityPage> createState() => _UserActivityPageState();
}

class _UserActivityPageState extends ConsumerState<UserActivityPage> {
  late DateTime _from = DateTime.now().toUtc().subtract(
    const Duration(days: 30),
  );
  late DateTime _to = DateTime.now().toUtc();

  AnalyticsRange get _range =>
      (userId: widget.userId, fromUtc: _from, toUtc: _to);

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(userActivityProvider(_range));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanım Analizi'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _to = DateTime.now().toUtc());
              ref.invalidate(userActivityProvider(_range));
            },
          ),
        ],
      ),
      body: analytics.when(
        loading: () => const ContentLoadingView(),
        error: (error, _) => ContentErrorView(
          message: networkErrorMessage(error),
          onRetry: () => ref.invalidate(userActivityProvider(_range)),
        ),
        data: (data) => LearningBody(
          children: [
            Text(
              data.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                '${_date(_from.toLocal())} – ${_date(_to.toLocal())}',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Stat(
                  'Son aktif',
                  data.lastActiveAtUtc == null
                      ? '—'
                      : _dateTime(data.lastActiveAtUtc!.toLocal()),
                ),
                _Stat(
                  'Toplam aktif süre',
                  _duration(data.activeDurationSeconds),
                ),
                _Stat('Session', '${data.sessionCount}'),
                _Stat('Event', '${data.eventCount}'),
              ],
            ),
            _DurationSection(title: 'Ekran bazlı süre', items: data.screens),
            _DurationSection(title: 'Modül bazlı süre', items: data.modules),
            _DurationSection(title: 'Ders bazlı süre', items: data.lessons),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Quiz süreleri ve sonuçları',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (data.quizzes.isEmpty)
              const EmptyContentView(message: 'Bu aralıkta quiz verisi yok.'),
            for (final quiz in data.quizzes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(quiz.title),
                subtitle: Text(
                  '${quiz.attemptCount} deneme · ${_duration(quiz.durationSeconds)}\n'
                  '${quiz.averageScore == null ? "Ortalama başarı: —" : "Ort. %${quiz.averageScore!.round()}"}',
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Önemli event timeline',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (data.timeline.isEmpty)
              const EmptyContentView(
                message: 'Bu aralıkta aktivite kaydı yok.',
              ),
            for (final event in data.timeline)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle, size: 10),
                title: Text(_eventName(event.eventType)),
                subtitle: Text(
                  [
                    event.screenName,
                    event.target,
                    _dateTime(event.occurredAtUtc.toLocal()),
                  ].whereType<String>().join(' · '),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _from.toLocal(),
        end: _to.toLocal(),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _from = DateTime(
        result.start.year,
        result.start.month,
        result.start.day,
      ).toUtc();
      _to = DateTime(
        result.end.year,
        result.end.month,
        result.end.day,
        23,
        59,
        59,
        999,
        999,
      ).toUtc();
    });
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}

class _DurationSection extends StatelessWidget {
  const _DurationSection({required this.title, required this.items});
  final String title;
  final List<ActivityDuration> items;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Bu aralıkta veri yok.'),
          ),
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.name ?? item.key),
            subtitle: Text(_duration(item.durationSeconds)),
          ),
      ],
    ),
  );
}

String _duration(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final remainder = duration.inSeconds.remainder(60);
  return hours > 0
      ? '$hours sa $minutes dk'
      : minutes > 0
      ? '$minutes dk $remainder sn'
      : '$remainder sn';
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
String _dateTime(DateTime value) =>
    '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _eventName(String value) => value
    .split('_')
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
