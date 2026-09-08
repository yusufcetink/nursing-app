import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/storage/token_storage.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_answer.dart';

void main() {
  test('modülleri typed modele dönüştürür ve JWT otomatik gönderir', () async {
    final adapter = _SequenceAdapter([
      _JsonResponse(200, [
        {
          'id': 'module-id',
          'title': 'Temel Bakım',
          'description': 'Açıklama',
          'order': 1,
          'lessonCount': 3,
          'updatedAtUtc': '2026-09-05T10:00:00Z',
        },
      ]),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
      ..httpClientAdapter = adapter;
    final repository = DioEducationRepository(
      ApiClient(dio: dio, tokenStorage: _MemoryTokenStorage('jwt-token')),
    );

    final modules = await repository.getModules();

    expect(modules.single.title, 'Temel Bakım');
    expect(modules.single.lessonCount, 3);
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer jwt-token',
    );
  });

  test(
    'published ders medya metadata bilgisini typed modele dönüştürür',
    () async {
      final adapter = _SequenceAdapter([
        _JsonResponse(200, {
          'id': 'lesson-id',
          'educationModuleId': 'module-id',
          'title': 'Video Ders',
          'description': 'Açıklama',
          'estimatedDurationMinutes': 5,
          'order': 1,
          'quizId': null,
          'blocks': [
            {
              'id': 'image-block',
              'lessonId': 'lesson-id',
              'blockType': 'Image',
              'textContent': null,
              'media': {
                'id': 'image-id',
                'lessonId': 'lesson-id',
                'originalFileName': 'lesson.png',
                'contentType': 'image/png',
                'mediaType': 'Image',
                'sizeBytes': 1024,
                'sortOrder': 0,
              },
              'sortOrder': 0,
            },
            {
              'id': 'video-block',
              'lessonId': 'lesson-id',
              'blockType': 'Video',
              'textContent': null,
              'media': {
                'id': 'video-id',
                'lessonId': 'lesson-id',
                'originalFileName': 'lesson.mp4',
                'contentType': 'video/mp4',
                'mediaType': 'Video',
                'sizeBytes': 2048,
                'sortOrder': 1,
              },
              'sortOrder': 1,
            },
          ],
          'updatedAtUtc': '2026-09-07T10:00:00Z',
        }),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
        ..httpClientAdapter = adapter;
      final repository = DioEducationRepository(ApiClient(dio: dio));

      final lesson = await repository.getLesson('lesson-id');

      expect(lesson.blocks.first.media?.id, 'image-id');
      expect(lesson.blocks.first.blockType, LessonContentBlockType.image);
      expect(lesson.blocks.last.media?.originalFileName, 'lesson.mp4');
      expect(lesson.blocks.last.blockType, LessonContentBlockType.video);
    },
  );

  test(
    'quiz doğru cevabı taşımadan yüklenir ve sunucuda değerlendirilir',
    () async {
      final adapter = _SequenceAdapter([
        _JsonResponse(200, {
          'id': 'quiz-id',
          'lessonId': 'lesson-id',
          'title': 'Ders Quizi',
          'questions': [
            {
              'id': 'question-id',
              'prompt': 'Soru?',
              'order': 1,
              'options': [
                {'id': 'option-id', 'text': 'Seçenek', 'order': 1},
              ],
            },
          ],
          'updatedAtUtc': '2026-09-05T10:00:00Z',
        }),
        _JsonResponse(200, {
          'attemptId': 'attempt-id',
          'quizId': 'quiz-id',
          'totalQuestionCount': 1,
          'correctCount': 1,
          'incorrectCount': 0,
          'successPercentage': 100.0,
          'completedAtUtc': '2026-09-05T10:00:00Z',
        }),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
        ..httpClientAdapter = adapter;
      final repository = DioQuizRepository(ApiClient(dio: dio));

      final quiz = await repository.getLessonQuiz('lesson-id');
      final result = await repository.submitLessonQuiz('lesson-id', const [
        QuizAnswer(questionId: 'question-id', selectedOptionId: 'option-id'),
      ]);

      expect(quiz.questions.single.options.single.text, 'Seçenek');
      expect(result.correctCount, 1);
      expect(
        jsonEncode(adapter.requests.last.data),
        isNot(contains('isCorrect')),
      );
      expect(
        adapter.requests.last.path,
        '/api/education/lessons/lesson-id/quiz/submit',
      );
    },
  );

  test(
    'ders progress ve quiz geçmişini kalıcı API sözleşmesinden okur',
    () async {
      final adapter = _SequenceAdapter([
        _JsonResponse(200, {
          'completedLessons': [
            {
              'lessonId': 'lesson-id',
              'educationModuleId': 'module-id',
              'completedAtUtc': '2026-09-05T10:00:00Z',
            },
          ],
        }),
        _JsonResponse(200, [
          {
            'attemptId': 'attempt-id',
            'quizId': 'quiz-id',
            'lessonId': 'lesson-id',
            'quizTitle': 'Quiz',
            'lessonTitle': 'Ders',
            'totalQuestionCount': 1,
            'correctCount': 1,
            'incorrectCount': 0,
            'successPercentage': 100,
            'completedAtUtc': '2026-09-05T10:00:00Z',
          },
        ]),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
        ..httpClientAdapter = adapter;
      final apiClient = ApiClient(dio: dio);

      final progress = await DioProgressRepository(apiClient).getProgress();
      final history = await DioProfileRepository(apiClient).getQuizHistory();

      expect(progress.completedLessonIds, contains('lesson-id'));
      expect(history.single.attemptId, 'attempt-id');
      expect(adapter.requests.first.path, '/api/profile/progress');
      expect(adapter.requests.last.path, '/api/profile/quiz-history');
    },
  );
}

final class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage(this.token);

  String? token;

  @override
  Future<void> delete() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}

final class _JsonResponse {
  const _JsonResponse(this.statusCode, this.body);

  final int statusCode;
  final Object body;
}

final class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this._responses);

  final List<_JsonResponse> _responses;
  final List<RequestOptions> requests = [];
  var _responseIndex = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = _responses[_responseIndex++];
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
