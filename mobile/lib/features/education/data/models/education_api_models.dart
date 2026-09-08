import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';

final class EducationModuleSummaryResponse {
  const EducationModuleSummaryResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.lessonCount,
  });

  factory EducationModuleSummaryResponse.fromJson(Map<String, dynamic> json) {
    return EducationModuleSummaryResponse(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      order: json['order'] as int,
      lessonCount: json['lessonCount'] as int,
    );
  }

  final String id;
  final String title;
  final String description;
  final int order;
  final int lessonCount;

  EducationModule toDomain() => EducationModule(
    id: id,
    title: title,
    description: description,
    order: order,
    lessonCount: lessonCount,
    lessons: const [],
  );
}

final class EducationModuleResponse {
  const EducationModuleResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.lessons,
  });

  factory EducationModuleResponse.fromJson(Map<String, dynamic> json) {
    return EducationModuleResponse(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      order: json['order'] as int,
      lessons: (json['lessons'] as List<dynamic>)
          .map(
            (item) =>
                LessonSummaryResponse.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String title;
  final String description;
  final int order;
  final List<LessonSummaryResponse> lessons;

  EducationModule toDomain() => EducationModule(
    id: id,
    title: title,
    description: description,
    order: order,
    lessonCount: lessons.length,
    lessons: lessons
        .map((lesson) => lesson.toDomain(id))
        .toList(growable: false),
  );
}

final class LessonSummaryResponse {
  const LessonSummaryResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedDurationMinutes,
    required this.order,
  });

  factory LessonSummaryResponse.fromJson(Map<String, dynamic> json) {
    return LessonSummaryResponse(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      estimatedDurationMinutes: json['estimatedDurationMinutes'] as int,
      order: json['order'] as int,
    );
  }

  final String id;
  final String title;
  final String description;
  final int estimatedDurationMinutes;
  final int order;

  Lesson toDomain(String moduleId) => Lesson(
    id: id,
    educationModuleId: moduleId,
    title: title,
    description: description,
    estimatedDurationMinutes: estimatedDurationMinutes,
    order: order,
    blocks: const [],
  );
}

final class LessonResponse {
  const LessonResponse({
    required this.id,
    required this.educationModuleId,
    required this.title,
    required this.description,
    required this.estimatedDurationMinutes,
    required this.order,
    required this.quizId,
    required this.blocks,
  });

  factory LessonResponse.fromJson(Map<String, dynamic> json) {
    return LessonResponse(
      id: json['id'] as String,
      educationModuleId: json['educationModuleId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      estimatedDurationMinutes: json['estimatedDurationMinutes'] as int,
      order: json['order'] as int,
      quizId: json['quizId'] as String?,
      blocks: (json['blocks'] as List<dynamic>? ?? const [])
          .map(
            (item) => LessonContentBlockResponse.fromJson(
              item as Map<String, dynamic>,
            ).toDomain(),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String educationModuleId;
  final String title;
  final String description;
  final int estimatedDurationMinutes;
  final int order;
  final String? quizId;
  final List<LessonContentBlock> blocks;

  Lesson toDomain() => Lesson(
    id: id,
    educationModuleId: educationModuleId,
    title: title,
    description: description,
    estimatedDurationMinutes: estimatedDurationMinutes,
    order: order,
    blocks: blocks,
    quizId: quizId,
  );
}

final class LessonContentBlockResponse {
  const LessonContentBlockResponse({
    required this.id,
    required this.lessonId,
    required this.blockType,
    required this.sortOrder,
    this.textContent,
    this.media,
  });

  factory LessonContentBlockResponse.fromJson(Map<String, dynamic> json) =>
      LessonContentBlockResponse(
        id: json['id'] as String,
        lessonId: json['lessonId'] as String,
        blockType: LessonContentBlockType.values.firstWhere(
          (type) => type.name == (json['blockType'] as String).toLowerCase(),
        ),
        textContent: json['textContent'] as String?,
        media: json['media'] == null
            ? null
            : LessonMediaResponse.fromJson(
                json['media'] as Map<String, dynamic>,
              ).toDomain(),
        sortOrder: json['sortOrder'] as int,
      );

  final String id;
  final String lessonId;
  final LessonContentBlockType blockType;
  final String? textContent;
  final LessonMedia? media;
  final int sortOrder;

  LessonContentBlock toDomain() => LessonContentBlock(
    id: id,
    lessonId: lessonId,
    blockType: blockType,
    textContent: textContent,
    media: media,
    sortOrder: sortOrder,
  );
}

final class LessonMediaResponse {
  const LessonMediaResponse({
    required this.id,
    required this.lessonId,
    required this.originalFileName,
    required this.contentType,
    required this.mediaType,
    required this.sizeBytes,
    required this.sortOrder,
  });

  factory LessonMediaResponse.fromJson(Map<String, dynamic> json) =>
      LessonMediaResponse(
        id: json['id'] as String,
        lessonId: json['lessonId'] as String,
        originalFileName: json['originalFileName'] as String,
        contentType: json['contentType'] as String,
        mediaType: _mediaTypeFromJson(json['mediaType'] as String),
        sizeBytes: json['sizeBytes'] as int,
        sortOrder: json['sortOrder'] as int,
      );

  final String id;
  final String lessonId;
  final String originalFileName;
  final String contentType;
  final LessonMediaType mediaType;
  final int sizeBytes;
  final int sortOrder;

  LessonMedia toDomain() => LessonMedia(
    id: id,
    lessonId: lessonId,
    originalFileName: originalFileName,
    contentType: contentType,
    mediaType: mediaType,
    sizeBytes: sizeBytes,
    sortOrder: sortOrder,
  );

  static LessonMediaType _mediaTypeFromJson(String value) =>
      switch (value.toLowerCase()) {
        'image' => LessonMediaType.image,
        'video' => LessonMediaType.video,
        _ => throw FormatException('Unsupported lesson media type: $value'),
      };
}
