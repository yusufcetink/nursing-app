import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/network/network_exception.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (ref) => LeaderboardRepository(ref.watch(apiClientProvider)),
);

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.totalCorrectAnswers,
    required this.totalQuestionCount,
    required this.completedQuizCount,
    required this.accuracyPercentage,
    required this.isCurrentUser,
    this.avatarUrl,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: json['rank'] as int,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        totalCorrectAnswers: json['totalCorrectAnswers'] as int,
        totalQuestionCount: json['totalQuestionCount'] as int,
        completedQuizCount: json['completedQuizCount'] as int,
        accuracyPercentage: (json['accuracyPercentage'] as num).round(),
        isCurrentUser: json['isCurrentUser'] as bool,
      );

  final int rank;
  final String displayName;
  final String? avatarUrl;
  final int totalCorrectAnswers;
  final int totalQuestionCount;
  final int completedQuizCount;
  final int accuracyPercentage;
  final bool isCurrentUser;

  String get initials {
    final words = displayName.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    final first = words.first.characters.first;
    final last = words.length == 1 ? '' : words.last.characters.first;
    return '$first$last'
        .toUpperCase()
        .replaceAll('Ç', 'C')
        .replaceAll('Ğ', 'G')
        .replaceAll('İ', 'I')
        .replaceAll('Ö', 'O')
        .replaceAll('Ş', 'S')
        .replaceAll('Ü', 'U');
  }
}

class LeaderboardData {
  const LeaderboardData({
    required this.entries,
    required this.totalUsers,
    required this.offset,
    required this.limit,
    this.currentUser,
    this.courseName,
    this.courseQuizCount,
  });

  factory LeaderboardData.fromJson(Map<String, dynamic> json) =>
      LeaderboardData(
        entries: (json['entries'] as List<dynamic>)
            .map(
              (item) => LeaderboardEntry.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        totalUsers: json['totalUsers'] as int,
        offset: json['offset'] as int,
        limit: json['limit'] as int,
        currentUser: json['currentUser'] == null
            ? null
            : LeaderboardEntry.fromJson(
                json['currentUser'] as Map<String, dynamic>,
              ),
        courseName: json['courseName'] as String?,
        courseQuizCount: json['courseQuizCount'] as int?,
      );

  final List<LeaderboardEntry> entries;
  final int totalUsers;
  final int offset;
  final int limit;
  final LeaderboardEntry? currentUser;
  final String? courseName;
  final int? courseQuizCount;
}

class LeaderboardCourse {
  const LeaderboardCourse(this.id, this.title, this.quizCount);

  factory LeaderboardCourse.fromJson(Map<String, dynamic> json) =>
      LeaderboardCourse(
        json['id'] as String,
        json['title'] as String,
        json['quizCount'] as int,
      );

  final String id;
  final String title;
  final int quizCount;
}

class LeaderboardRepository {
  const LeaderboardRepository(this._client);
  final ApiClient _client;

  Future<LeaderboardData> get({
    required String period,
    String? courseId,
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/leaderboard',
        queryParameters: {
          'period': period,
          'courseId': ?courseId,
          'offset': offset,
          'limit': limit,
        },
      );
      return LeaderboardData.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('Sıralama verisi okunamadı.');
    } on TypeError {
      throw const NetworkException('Sıralama verisi okunamadı.');
    }
  }

  Future<List<LeaderboardCourse>> courses() async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        '/api/leaderboard/courses',
      );
      return (response.data ?? const [])
          .map(
            (item) => LeaderboardCourse.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('Dersler okunamadı.');
    } on TypeError {
      throw const NetworkException('Dersler okunamadı.');
    }
  }
}
