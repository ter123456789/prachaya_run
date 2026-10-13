/// Device settings for notifications and voice (kept per device, like the
/// distance unit). Every reminder is local: no server is involved.
class ReminderSettings {
  const ReminderSettings({
    this.workoutLeadMinutes = 30,
    this.weeklyGoal = true,
    this.morningWeather = false,
    this.audioCues = true,
  });

  /// Minutes before a planned session; null turns those reminders off.
  final int? workoutLeadMinutes;

  /// Tell when this week's distance reaches the weekly goal.
  final bool weeklyGoal;

  /// A forecast for the next morning at 06:00.
  final bool morningWeather;

  /// Spoken pace and distance at every unit while recording.
  final bool audioCues;

  static const leadChoices = [15, 30, 60];

  ReminderSettings copyWith({
    int? Function()? workoutLeadMinutes,
    bool? weeklyGoal,
    bool? morningWeather,
    bool? audioCues,
  }) => ReminderSettings(
    workoutLeadMinutes: workoutLeadMinutes == null
        ? this.workoutLeadMinutes
        : workoutLeadMinutes(),
    weeklyGoal: weeklyGoal ?? this.weeklyGoal,
    morningWeather: morningWeather ?? this.morningWeather,
    audioCues: audioCues ?? this.audioCues,
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.workoutLeadMinutes == workoutLeadMinutes &&
      other.weeklyGoal == weeklyGoal &&
      other.morningWeather == morningWeather &&
      other.audioCues == audioCues;

  @override
  int get hashCode =>
      Object.hash(workoutLeadMinutes, weeklyGoal, morningWeather, audioCues);
}
