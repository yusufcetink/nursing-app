namespace AsliApp.Domain.Analytics;

public enum ActivityEventType
{
    SessionStart,
    SessionEnd,
    ScreenView,
    ScreenLeave,
    ButtonClick,
    ModuleOpen,
    LessonOpen,
    LessonComplete,
    QuizStart,
    QuizAnswer,
    QuizComplete,
    VideoPlay,
    VideoPause,
    VideoComplete,
    NotificationSent,
    NotificationOpened,
}
