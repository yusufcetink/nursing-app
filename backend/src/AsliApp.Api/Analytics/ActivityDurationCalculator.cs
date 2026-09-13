namespace AsliApp.Api.Analytics;

public static class ActivityDurationCalculator
{
    public static int AddActiveSegment(int currentDurationSeconds, int? segmentSeconds) =>
        (int)Math.Min(
            7 * 24 * 60 * 60,
            (long)Math.Max(0, currentDurationSeconds) + Math.Clamp(segmentSeconds ?? 0, 0, 86400));

    public static int SessionDuration(
        int currentDurationSeconds,
        int? reportedDurationSeconds) =>
        Math.Max(currentDurationSeconds, Math.Clamp(reportedDurationSeconds ?? 0, 0, 86400));
}
