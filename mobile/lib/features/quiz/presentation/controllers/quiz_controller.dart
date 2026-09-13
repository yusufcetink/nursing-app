import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/profile/presentation/providers/profile_overview_provider.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_answer.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_submission_result.dart';
import 'package:asli_app/features/analytics/application/activity_tracker.dart';

typedef QuizSelection = ({String moduleId, String lessonId});

final quizForLessonProvider = FutureProvider.family<Quiz, String>(
  (ref, lessonId) => ref.watch(quizRepositoryProvider).getLessonQuiz(lessonId),
);

final quizControllerProvider = NotifierProvider.autoDispose
    .family<QuizController, QuizSessionState, QuizSelection>(
      QuizController.new,
    );

final class QuizController extends Notifier<QuizSessionState> {
  QuizController(this.selection);

  final QuizSelection selection;
  Duration _startedAt = Duration.zero;
  final Set<String> _reportedAnswers = {};
  ActivityContext get _activityContext => ActivityContext(
    moduleId: selection.moduleId,
    lessonId: selection.lessonId,
  );

  @override
  QuizSessionState build() {
    _startedAt = ref
        .read(activityTrackerProvider)
        .activeScreenDuration('quiz', _activityContext);
    final quiz = ref.read(quizForLessonProvider(selection.lessonId)).value;
    ref.read(activityTrackerProvider)
      ..updateContext(
        ActivityContext(
          moduleId: selection.moduleId,
          lessonId: selection.lessonId,
          quizId: quiz?.id,
        ),
      )
      ..track(
        'quiz_start',
        moduleId: selection.moduleId,
        lessonId: selection.lessonId,
        quizId: quiz?.id,
      );
    return QuizSessionState.initial();
  }

  void selectOption(String optionId) {
    if (state.isCompleted || state.isSubmitting) return;
    state = state.copyWith(selectedOptionId: optionId, clearError: true);
  }

  Future<void> submitAndContinue() async {
    final quiz = ref
        .read(quizForLessonProvider(selection.lessonId))
        .requireValue;
    final selectedOptionId = state.selectedOptionId;
    if (selectedOptionId == null || state.isCompleted || state.isSubmitting) {
      return;
    }

    final question = quiz.questions[state.currentQuestionIndex];
    if (_reportedAnswers.add(question.id)) {
      ref
          .read(activityTrackerProvider)
          .track(
            'quiz_answer',
            moduleId: selection.moduleId,
            lessonId: selection.lessonId,
            quizId: quiz.id,
            questionId: question.id,
          );
    }
    final answers = [
      ...state.answers,
      QuizAnswer(questionId: question.id, selectedOptionId: selectedOptionId),
    ];
    final isLastQuestion =
        state.currentQuestionIndex == quiz.questions.length - 1;
    if (!isLastQuestion) {
      state = QuizSessionState(
        currentQuestionIndex: state.currentQuestionIndex + 1,
        selectedOptionId: null,
        answers: answers,
        isCompleted: false,
        isSubmitting: false,
      );

      return;
    }

    final previousAnswers = state.answers;
    state = state.copyWith(
      answers: answers,
      isSubmitting: true,
      clearError: true,
    );
    try {
      final result = await ref
          .read(quizRepositoryProvider)
          .submitLessonQuiz(selection.lessonId, answers);
      state = QuizSessionState(
        currentQuestionIndex: state.currentQuestionIndex,
        selectedOptionId: null,
        answers: answers,
        isCompleted: true,
        isSubmitting: false,
        result: result,
      );

      ref
        ..invalidate(quizHistoryProvider)
        ..invalidate(profileOverviewProvider);
      ref
          .read(activityTrackerProvider)
          .track(
            'quiz_complete',
            moduleId: selection.moduleId,
            lessonId: selection.lessonId,
            quizId: quiz.id,
            durationSeconds:
                (ref
                            .read(activityTrackerProvider)
                            .activeScreenDuration('quiz', _activityContext) -
                        _startedAt)
                    .inSeconds,
            metadata: {'scorePercentage': result.successPercentage.toString()},
          );
    } catch (error) {
      state = QuizSessionState(
        currentQuestionIndex: state.currentQuestionIndex,
        selectedOptionId: selectedOptionId,
        answers: previousAnswers,
        isCompleted: false,
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
    List<QuizAnswer>? answers,
    bool? isSubmitting,
    bool clearError = false,
  }) {
    return QuizSessionState(
      currentQuestionIndex: currentQuestionIndex,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
      answers: answers ?? this.answers,
      isCompleted: isCompleted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result,
      errorMessage: clearError ? null : errorMessage,
    );
  }
}
