import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_answer.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_question.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_submission_result.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/profile/domain/models/profile_overview.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/progress/domain/models/progress_state.dart';

final testLessons = [
  const Lesson(
    id: 'nursing-roles',
    educationModuleId: 'nursing-fundamentals',
    title: 'Hemşirenin Temel Rolleri',
    description: 'Hemşirelik uygulamasındaki temel rol ve sorumluluklar.',
    estimatedDurationMinutes: 8,
    order: 1,
    quizId: 'nursing-roles-quiz',
    sections: [
      LessonSection(
        title: 'Bakım Verme Rolü',
        content: 'Bütüncül ve güvenli bakım.',
      ),
      LessonSection(
        title: 'Eğitim ve Savunuculuk',
        content: 'Bireyin haklarını destekler.',
      ),
    ],
  ),
  const Lesson(
    id: 'ethical-principles',
    educationModuleId: 'nursing-fundamentals',
    title: 'Etik İlkeler',
    description: 'Bakım sürecindeki etik yaklaşımlar.',
    estimatedDurationMinutes: 7,
    order: 2,
    sections: [],
  ),
  const Lesson(
    id: 'care-process',
    educationModuleId: 'nursing-fundamentals',
    title: 'Hemşirelik Bakım Süreci',
    description: 'Bakım süreci adımları.',
    estimatedDurationMinutes: 10,
    order: 3,
    sections: [],
  ),
];

final testModule = EducationModule(
  id: 'nursing-fundamentals',
  title: 'Hemşireliğin Temelleri',
  description: 'Temel hemşirelik rolleri, etik ilkeler ve bakım süreci.',
  order: 1,
  lessonCount: testLessons.length,
  lessons: testLessons,
);

final testQuiz = Quiz(
  id: 'nursing-roles-quiz',
  lessonId: 'nursing-roles',
  title: 'Hemşirenin Temel Rolleri Quizi',
  questions: [
    QuizQuestion(
      id: 'nursing-roles-care',
      prompt: 'Hemşirenin bakım verme rolünün temel amacı hangisidir?',
      options: const [
        QuizOption(
          id: 'care-0',
          text: 'Bakım kararlarını yalnızca ekip adına vermek',
        ),
        QuizOption(
          id: 'care-1',
          text: 'Bütüncül ve güvenli bakımı desteklemek',
        ),
        QuizOption(id: 'care-2', text: 'Yalnızca klinik kayıtları tamamlamak'),
        QuizOption(
          id: 'care-3',
          text: 'Hasta eğitimini diğer mesleklere bırakmak',
        ),
      ],
    ),
    QuizQuestion(
      id: 'nursing-roles-advocacy',
      prompt: 'Hasta savunuculuğu öncelikle neyi destekler?',
      options: const [
        QuizOption(id: 'advocacy-0', text: 'Bakım süresinin kısaltılmasını'),
        QuizOption(id: 'advocacy-1', text: 'Kurum gereksinimlerini'),
        QuizOption(
          id: 'advocacy-2',
          text: 'Bireyin haklarını ve kararlara katılımını',
        ),
        QuizOption(id: 'advocacy-3', text: 'Kararların yakına devredilmesini'),
      ],
    ),
  ],
);

final testCompletedLesson = CompletedLesson(
  lessonId: 'nursing-roles',
  educationModuleId: 'nursing-fundamentals',
  completedAtUtc: DateTime.utc(2026, 9, 5),
);

final testProfileQuizResult = ProfileQuizResult(
  attemptId: 'attempt-id',
  quizId: 'nursing-roles-quiz',
  lessonId: 'nursing-roles',
  quizTitle: 'Hemşirenin Temel Rolleri Quizi',
  lessonTitle: 'Hemşirenin Temel Rolleri',
  totalQuestionCount: 2,
  correctCount: 2,
  incorrectCount: 0,
  successPercentage: 100,
  completedAtUtc: DateTime.utc(2026, 9, 5),
);

final class FakeEducationRepository implements EducationRepository {
  @override
  Future<EducationModule> getModule(String id) async => testModule;

  @override
  Future<List<EducationModule>> getModules() async => [
    EducationModule(
      id: testModule.id,
      title: testModule.title,
      description: testModule.description,
      order: testModule.order,
      lessonCount: testModule.lessonCount,
      lessons: const [],
    ),
  ];

  @override
  Future<Lesson> getLesson(String id) async =>
      testLessons.firstWhere((lesson) => lesson.id == id);
}

final class FakeQuizRepository implements QuizRepository {
  @override
  Future<Quiz> getLessonQuiz(String lessonId) async => testQuiz;

  @override
  Future<QuizSubmissionResult> submitLessonQuiz(
    String lessonId,
    List<QuizAnswer> answers,
  ) async {
    final correct = answers.where((answer) {
      return answer.selectedOptionId == 'care-1' ||
          answer.selectedOptionId == 'advocacy-2';
    }).length;
    return QuizSubmissionResult(
      attemptId: 'new-attempt-id',
      quizId: testQuiz.id,
      totalQuestionCount: answers.length,
      correctCount: correct,
      incorrectCount: answers.length - correct,
      successPercentage: ((correct / answers.length) * 100).round(),
      completedAtUtc: DateTime.utc(2026, 9, 5),
    );
  }
}

final class FakeProgressRepository implements ProgressRepository {
  FakeProgressRepository({List<CompletedLesson> completedLessons = const []})
    : _completedLessons = [...completedLessons];

  final List<CompletedLesson> _completedLessons;

  @override
  Future<CompletedLesson> completeLesson(String lessonId) async {
    final existing = _completedLessons.where(
      (lesson) => lesson.lessonId == lessonId,
    );
    if (existing.isNotEmpty) return existing.first;
    final completed = CompletedLesson(
      lessonId: lessonId,
      educationModuleId: 'nursing-fundamentals',
      completedAtUtc: DateTime.utc(2026, 9, 5),
    );
    _completedLessons.add(completed);
    return completed;
  }

  @override
  Future<ProgressState> getProgress() async {
    return ProgressState(completedLessons: _completedLessons);
  }
}

final class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({List<ProfileQuizResult> results = const []})
    : _results = [...results];

  final List<ProfileQuizResult> _results;

  @override
  Future<List<ProfileQuizResult>> getQuizHistory() async => _results;

  @override
  Future<ProfileQuizResult> getQuizHistoryDetail(String attemptId) async {
    return _results.firstWhere((result) => result.attemptId == attemptId);
  }
}
