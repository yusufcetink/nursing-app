import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/profile/presentation/providers/profile_overview_provider.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_answer.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_submission_result.dart';
import 'package:asli_app/features/analytics/application/activity_tracker.dart';

typedef QuizSelection = ({String moduleId, String lessonId});

// Only the quiz route starts an attempt; lesson cards read status without mutation.
final quizForLessonProvider = FutureProvider.autoDispose.family<Quiz, String>(
  (ref, lessonId) =>
      ref.watch(quizRepositoryProvider).startLessonQuiz(lessonId),
);
final lessonQuizStatusProvider = FutureProvider.autoDispose
    .family<Quiz, String>(
      (ref, lessonId) =>
          ref.watch(quizRepositoryProvider).getLessonAttempt(lessonId),
    );
final quizControllerProvider = NotifierProvider.autoDispose
    .family<QuizController, QuizSessionState, QuizSelection>(
      QuizController.new,
    );

final class QuizController extends Notifier<QuizSessionState> {
  QuizController(this.selection);
  final QuizSelection selection;
  late Quiz _quiz;
  Duration _startedAt = Duration.zero;
  ActivityContext get _activityContext => ActivityContext(
    moduleId: selection.moduleId,
    lessonId: selection.lessonId,
  );
  @override
  QuizSessionState build() {
    _quiz = ref.read(quizForLessonProvider(selection.lessonId)).requireValue;
    _startedAt = ref
        .read(activityTrackerProvider)
        .activeScreenDuration('quiz', _activityContext);
    if (_quiz.status != 'Completed') {
      ref
          .read(activityTrackerProvider)
          .track(
            'quiz_start',
            moduleId: selection.moduleId,
            lessonId: selection.lessonId,
            quizId: _quiz.id,
          );
    }
    return QuizSessionState.fromQuiz(_quiz);
  }

  void selectOption(String optionId) {
    if (state.isCompleted || state.isSubmitting) return;
    final question = _quiz.questions[state.currentQuestionIndex];
    if (!question.options.any((o) => o.id == optionId)) return;
    state = state.copyWith(selectedOptionId: optionId, clearError: true);
  }

  Future<void> submitAndContinue() async {
    if (state.isCompleted ||
        state.isSubmitting ||
        state.selectedOptionId == null) {
      return;
    }
    final question = _quiz.questions[state.currentQuestionIndex];
    final answer = QuizAnswer(
      questionId: question.id,
      selectedOptionId: state.selectedOptionId!,
    );
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final updated = await ref
          .read(quizRepositoryProvider)
          .saveAnswer(_quiz.attemptId!, answer);
      if (!ref.mounted) return;
      _quiz = updated;
      state = QuizSessionState.fromQuiz(updated);
      ref.invalidate(lessonQuizStatusProvider(selection.lessonId));
      ref
          .read(activityTrackerProvider)
          .track(
            'quiz_answer',
            moduleId: selection.moduleId,
            lessonId: selection.lessonId,
            quizId: updated.id,
            questionId: question.id,
          );
      if (state.isCompleted) {
        ref.invalidate(quizHistoryProvider);
        ref.invalidate(profileOverviewProvider);
        ref
            .read(activityTrackerProvider)
            .track(
              'quiz_complete',
              moduleId: selection.moduleId,
              lessonId: selection.lessonId,
              quizId: updated.id,
              durationSeconds:
                  (ref
                              .read(activityTrackerProvider)
                              .activeScreenDuration('quiz', _activityContext) -
                          _startedAt)
                      .inSeconds,
              metadata: {
                'scorePercentage': updated.result!.successPercentage.toString(),
              },
            );
      }
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: networkErrorMessage(error),
      );
    }
  }
}

final class QuizSessionState {
  QuizSessionState({
    required this.currentQuestionIndex,
    required this.selectedOptionId,
    required List<QuizAnswer> answers,
    required this.isCompleted,
    required this.isSubmitting,
    this.result,
    this.errorMessage,
  }) : answers = List.unmodifiable(answers);
  factory QuizSessionState.initial() => QuizSessionState(
    currentQuestionIndex: 0,
    selectedOptionId: null,
    answers: const [],
    isCompleted: false,
    isSubmitting: false,
  );
  factory QuizSessionState.fromQuiz(Quiz quiz) {
    final next = quiz.questions.indexWhere(
      (q) => !quiz.savedAnswers.any((a) => a.questionId == q.id),
    );
    return QuizSessionState(
      currentQuestionIndex: next < 0 ? 0 : next,
      selectedOptionId: null,
      answers: quiz.savedAnswers,
      isCompleted: quiz.status == 'Completed',
      isSubmitting: false,
      result: quiz.result,
    );
  }
  final int currentQuestionIndex;
  final String? selectedOptionId;
  final List<QuizAnswer> answers;
  final bool isCompleted;
  final bool isSubmitting;
  final QuizSubmissionResult? result;
  final String? errorMessage;
  int get correctCount => result?.correctCount ?? 0;
  int get incorrectCount => result?.incorrectCount ?? 0;
  int get successPercentage => result?.successPercentage ?? 0;
  QuizSessionState copyWith({
    String? selectedOptionId,
    bool? isSubmitting,
    bool clearError = false,
    String? errorMessage,
  }) => QuizSessionState(
    currentQuestionIndex: currentQuestionIndex,
    selectedOptionId: selectedOptionId ?? this.selectedOptionId,
    answers: answers,
    isCompleted: isCompleted,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    result: result,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}
