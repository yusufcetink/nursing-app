import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/features/content_management/data/content_management_repository.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';

void main() {
  test('yönetim read ve write endpoint sözleşmelerini kullanır', () async {
    final adapter = _SequenceAdapter([
      _JsonResponse(200, [
        {
          'id': 'module-id',
          'title': 'Taslak Modül',
          'description': 'Açıklama',
          'order': 2,
          'isPublished': false,
          'lessonCount': 1,
          'updatedAtUtc': '2026-09-06T10:00:00Z',
        },
      ]),
      _JsonResponse(200, {
        'id': 'module-id',
        'title': 'Taslak Modül',
        'description': 'Açıklama',
        'order': 2,
        'isPublished': false,
        'lessons': [
          {
            'id': 'lesson-id',
            'title': 'Taslak Ders',
            'description': 'Ders açıklaması',
            'estimatedDurationMinutes': 5,
            'order': 1,
            'isPublished': false,
          },
        ],
        'updatedAtUtc': '2026-09-06T10:00:00Z',
      }),
      _JsonResponse(200, {
        'id': 'lesson-id',
        'educationModuleId': 'module-id',
        'title': 'Taslak Ders',
        'description': 'Ders açıklaması',
        'content': 'Ders içeriği',
        'estimatedDurationMinutes': 5,
        'order': 1,
        'isPublished': false,
        'updatedAtUtc': '2026-09-06T10:00:00Z',
      }),
      _JsonResponse(201, {'id': 'created-module-id'}),
      const _JsonResponse(204, ''),
      _JsonResponse(201, {'id': 'created-lesson-id'}),
      const _JsonResponse(204, ''),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
      ..httpClientAdapter = adapter;
    final repository = DioContentManagementRepository(ApiClient(dio: dio));
    const moduleInput = ModuleWriteInput(
      title: 'Modül',
      description: 'Açıklama',
      order: 3,
      isPublished: true,
    );
    const lessonInput = LessonWriteInput(
      title: 'Ders',
      description: 'Açıklama',
      content: 'İçerik',
      estimatedDurationMinutes: 8,
      order: 4,
      isPublished: true,
    );

    final modules = await repository.getModules();
    final module = await repository.getModule('module-id');
    final lesson = await repository.getLesson('lesson-id');
    final createdModuleId = await repository.createModule(moduleInput);
    await repository.updateModule('module-id', moduleInput);
    final createdLessonId = await repository.createLesson(
      'module-id',
      lessonInput,
    );
    await repository.updateLesson('lesson-id', lessonInput);

    expect(modules.single.isPublished, isFalse);
    expect(module.lessons.single.title, 'Taslak Ders');
    expect(lesson.content, 'Ders içeriği');
    expect(createdModuleId, 'created-module-id');
    expect(createdLessonId, 'created-lesson-id');
    expect(adapter.requests.map((request) => request.path), [
      '/api/education/content/modules',
      '/api/education/content/modules/module-id',
      '/api/education/content/lessons/lesson-id',
      '/api/education/modules',
      '/api/education/modules/module-id',
      '/api/education/modules/module-id/lessons',
      '/api/education/lessons/lesson-id',
    ]);
    expect(adapter.requests[3].data['isPublished'], isTrue);
    expect(adapter.requests[5].data['estimatedDurationMinutes'], 8);
  });
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
      response.body is String
          ? response.body as String
          : jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
