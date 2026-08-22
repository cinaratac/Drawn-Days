enum StartViewPreference { month, week, flow }

enum AppThemePreference { light, dark, paper }

enum WeekStartPreference { monday, sunday }

enum AppLanguage { turkish, english }

class AppSettings {
  const AppSettings({
    this.startView = StartViewPreference.month,
    this.theme = AppThemePreference.paper,
    this.weekStart = WeekStartPreference.monday,
    this.language = AppLanguage.turkish,
    this.dailyReminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  final StartViewPreference startView;
  final AppThemePreference theme;
  final WeekStartPreference weekStart;
  final AppLanguage language;
  final bool dailyReminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool soundEnabled;
  final bool hapticsEnabled;

  AppSettings copyWith({
    StartViewPreference? startView,
    AppThemePreference? theme,
    WeekStartPreference? weekStart,
    AppLanguage? language,
    bool? dailyReminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? soundEnabled,
    bool? hapticsEnabled,
  }) {
    return AppSettings(
      startView: startView ?? this.startView,
      theme: theme ?? this.theme,
      weekStart: weekStart ?? this.weekStart,
      language: language ?? this.language,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'startView': startView.name,
    'theme': theme.name,
    'weekStart': weekStart.name,
    'language': language.name,
    'dailyReminderEnabled': dailyReminderEnabled,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'soundEnabled': soundEnabled,
    'hapticsEnabled': hapticsEnabled,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      startView: StartViewPreference.values.firstWhere(
        (value) => value.name == json['startView'],
        orElse: () => StartViewPreference.month,
      ),
      theme: AppThemePreference.values.firstWhere(
        (value) => value.name == json['theme'],
        orElse: () => AppThemePreference.paper,
      ),
      weekStart: WeekStartPreference.values.firstWhere(
        (value) => value.name == json['weekStart'],
        orElse: () => WeekStartPreference.monday,
      ),
      language: AppLanguage.values.firstWhere(
        (value) => value.name == json['language'],
        orElse: () => AppLanguage.turkish,
      ),
      dailyReminderEnabled: json['dailyReminderEnabled'] as bool? ?? false,
      reminderHour: ((json['reminderHour'] as num?)?.toInt() ?? 20)
          .clamp(0, 23)
          .toInt(),
      reminderMinute: ((json['reminderMinute'] as num?)?.toInt() ?? 0)
          .clamp(0, 59)
          .toInt(),
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
    );
  }
}
