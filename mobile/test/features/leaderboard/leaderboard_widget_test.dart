import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/leaderboard/data/leaderboard_repository.dart';
import 'package:asli_app/features/leaderboard/presentation/compact_leaderboard_section.dart';
import 'package:asli_app/features/leaderboard/presentation/leaderboard_page.dart';
import 'package:asli_app/features/leaderboard/presentation/leaderboard_providers.dart';
import 'package:asli_app/features/leaderboard/presentation/leaderboard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _entries = [
  LeaderboardEntry(
    rank: 1,
    displayName: 'Elif Aksoy',
    totalCorrectAnswers: 51,
    totalQuestionCount: 54,
    completedQuizCount: 3,
    accuracyPercentage: 94,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    rank: 2,
    displayName: 'Yusuf Çetinkaya',
    totalCorrectAnswers: 49,
    totalQuestionCount: 54,
    completedQuizCount: 3,
    accuracyPercentage: 91,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    rank: 3,
    displayName: 'Zeynep Kaya',
    totalCorrectAnswers: 46,
    totalQuestionCount: 54,
    completedQuizCount: 3,
    accuracyPercentage: 85,
    isCurrentUser: false,
  ),
];
const _me = LeaderboardEntry(
  rank: 6,
  displayName: 'Deniz Yılmaz',
  totalCorrectAnswers: 39,
  totalQuestionCount: 54,
  completedQuizCount: 3,
  accuracyPercentage: 72,
  isCurrentUser: true,
);

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'profile ranking supports filters and pagination at 200% scale dark=$dark',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final selections = <LeaderboardSelection>[];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              leaderboardCoursesProvider.overrideWith(
                (ref) async => const [
                  LeaderboardCourse('course-a', 'Temel Hemşirelik', 4),
                ],
              ),
              leaderboardProvider.overrideWith((ref, selection) async {
                selections.add(selection);
                return LeaderboardData(
                  entries: selection.offset == 0 ? _entries : [_me],
                  currentUser: _me,
                  totalUsers: 21,
                  offset: selection.offset,
                  limit: 20,
                  courseQuizCount: 4,
                  courseName: 'Temel Hemşirelik',
                );
              }),
            ],
            child: MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: LeaderboardSection(embedded: true),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Öğrenci sıralaması'), findsOneWidget);
        expect(find.text('Küçük başarıların'), findsNothing);
        expect(find.text('Deniz Yılmaz'), findsOneWidget);
        expect(find.text('DY'), findsOneWidget);
        expect(find.text('Sen'), findsOneWidget);
        expect(find.textContaining('@'), findsNothing);
        expect(find.text('39 doğru'), findsOneWidget);
        expect(find.text('3 quiz • %72 başarı'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Sonraki'));
        await tester.tap(find.text('Sonraki'));
        await tester.pumpAndSettle();
        expect(selections.last.offset, 20);
        expect(find.text('Deniz Yılmaz'), findsOneWidget);
        await tester.ensureVisible(find.text('Bu Ay'));
        await tester.tap(find.text('Bu Ay'));
        await tester.pumpAndSettle();
        expect(selections.last.period, 'monthly');
        expect(selections.last.offset, 0);
        await tester.ensureVisible(find.text('Tüm Zamanlar'));
        await tester.tap(find.text('Tüm Zamanlar'));
        await tester.pumpAndSettle();
        expect(selections.last.period, 'allTime');
        await tester.ensureVisible(find.text('Modüle Göre'));
        await tester.tap(find.text('Modüle Göre'));
        await tester.pumpAndSettle();
        expect(selections.last.courseId, 'course-a');
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('initials use the first name and surname initial', () {
    expect(_entries[0].initials, 'EA');
    expect(_entries[1].initials, 'YC');
    expect(_me.initials, 'DY');
  });

  testWidgets('premium cards keep names readable on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const current = LeaderboardEntry(
      rank: 1,
      displayName: 'Yusuf Çok Uzun Ad Ç.',
      totalCorrectAnswers: 8,
      totalQuestionCount: 20,
      completedQuizCount: 3,
      accuracyPercentage: 40,
      isCurrentUser: true,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LeaderboardPodium(entries: [current], isLesson: false),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('YC'), findsOneWidget);
    expect(find.text('Sen'), findsOneWidget);
    expect(find.text('8 doğru'), findsOneWidget);
    final name = tester.widget<Text>(find.text('Yusuf Çok Uzun Ad Ç.'));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.radius, lessThanOrEqualTo(15));
  });

  testWidgets('Home shows top three and current rank; link opens leaderboard', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          name: AppRoutes.home,
          path: AppRoutes.homePath,
          builder: (_, _) => const Scaffold(body: CompactLeaderboardSection()),
        ),
        GoRoute(
          name: AppRoutes.leaderboard,
          path: AppRoutes.leaderboardPath,
          builder: (_, _) => const LeaderboardPage(),
        ),
      ],
      initialLocation: AppRoutes.homePath,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeLeaderboardProvider.overrideWith(
            (ref) async => const LeaderboardData(
              entries: _entries,
              currentUser: _me,
              totalUsers: 6,
              offset: 0,
              limit: 3,
            ),
          ),
          leaderboardCoursesProvider.overrideWith((ref) async => const []),
          leaderboardProvider.overrideWith(
            (ref, selection) async => const LeaderboardData(
              entries: _entries,
              currentUser: _me,
              totalUsers: 6,
              offset: 0,
              limit: 20,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bu Haftanın Liderleri'), findsOneWidget);
    expect(find.text('Elif Aksoy'), findsOneWidget);
    expect(find.text('Deniz Yılmaz'), findsOneWidget);
    expect(find.text('Sen'), findsOneWidget);
    await tester.tap(find.text('Tümünü Gör →'));
    await tester.pumpAndSettle();
    expect(find.text('Sıralama'), findsWidgets);
  });

  testWidgets('Period and course controls request selected data', (
    tester,
  ) async {
    final selections = <LeaderboardSelection>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaderboardCoursesProvider.overrideWith(
            (ref) async => const [
              LeaderboardCourse('course-a', 'Ağrı ve Ağrı Yönetimi', 3),
              LeaderboardCourse('course-b', 'Enfeksiyon Kontrolü', 2),
            ],
          ),
          leaderboardProvider.overrideWith((ref, selection) async {
            selections.add(selection);
            return const LeaderboardData(
              entries: _entries,
              currentUser: _me,
              totalUsers: 6,
              offset: 0,
              limit: 20,
              courseName: 'Ağrı ve Ağrı Yönetimi',
              courseQuizCount: 3,
            );
          }),
        ],
        child: const MaterialApp(home: LeaderboardPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(selections.last.period, 'weekly');
    await tester.tap(find.text('Bu Ay'));
    await tester.pumpAndSettle();
    expect(selections.last.period, 'monthly');
    await tester.tap(find.text('Modüle Göre'));
    await tester.pumpAndSettle();
    expect(selections.last.courseId, 'course-a');
    expect(find.text('Ağrı ve Ağrı Yönetimi'), findsWidgets);
  });

  testWidgets('Empty leaderboard explains how to participate', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaderboardCoursesProvider.overrideWith((ref) async => const []),
          leaderboardProvider.overrideWith(
            (ref, selection) async => const LeaderboardData(
              entries: [],
              totalUsers: 0,
              offset: 0,
              limit: 20,
            ),
          ),
        ],
        child: const MaterialApp(home: LeaderboardPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sıralama henüz oluşmadı.'), findsOneWidget);
  });
}
