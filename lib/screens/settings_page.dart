import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import 'privacy_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.doodleCount,
    required this.onSettingsChanged,
    required this.onClearDoodles,
    required this.onCreateBackup,
    required this.onRestoreBackup,
    required this.onRateApp,
    required this.showRateApp,
  });

  final AppSettings settings;
  final int doodleCount;
  final Future<bool> Function(AppSettings) onSettingsChanged;
  final Future<void> Function() onClearDoodles;
  final Future<void> Function() onCreateBackup;
  final Future<bool> Function() onRestoreBackup;
  final Future<void> Function() onRateApp;
  final bool showRateApp;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettings _settings;
  late int _doodleCount;
  bool _busy = false;
  bool _updatingSettings = false;

  AppStrings get _s => AppStrings(_settings.language);

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _doodleCount = widget.doodleCount;
  }

  Future<bool> _updateSettings(AppSettings next) async {
    final previous = _settings;
    setState(() {
      _settings = next;
      _updatingSettings = true;
    });
    try {
      final applied = await widget.onSettingsChanged(next);
      if (!mounted) return applied;
      if (!applied) {
        setState(() => _settings = previous);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_s.notificationDenied)));
      }
      return applied;
    } finally {
      if (mounted) setState(() => _updatingSettings = false);
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _settings.reminderHour,
        minute: _settings.reminderMinute,
      ),
      helpText: _s.reminderTime,
    );
    if (picked != null) {
      await _updateSettings(
        _settings.copyWith(
          reminderHour: picked.hour,
          reminderMinute: picked.minute,
        ),
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_s.operationFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    await _run(() async {
      final restored = await widget.onRestoreBackup();
      if (!mounted) return;
      if (restored) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_s.backupInvalid)));
      }
    });
  }

  Future<void> _confirmClearDoodles() async {
    if (_doodleCount == 0 || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.t('Tüm çizimler silinsin mi?', 'Delete all drawings?')),
        content: Text(
          _s.t(
            'Takvimdeki $_doodleCount çizim kalıcı olarak silinecek. Bu işlem geri alınamaz.',
            '$_doodleCount drawings will be permanently deleted. This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(_s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.onClearDoodles();
      if (!mounted) return;
      setState(() => _doodleCount = 0);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_s.drawingsDeleted)));
    });
  }

  String get _timeLabel => TimeOfDay(
    hour: _settings.reminderHour,
    minute: _settings.reminderMinute,
  ).format(context);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_s.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          _SectionTitle(_s.appearance),
          const SizedBox(height: 9),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingLabel(_s.theme),
                const SizedBox(height: 12),
                SegmentedButton<AppThemePreference>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: AppThemePreference.light,
                      icon: const Icon(Icons.light_mode_outlined),
                      label: Text(_s.light),
                    ),
                    ButtonSegment(
                      value: AppThemePreference.dark,
                      icon: const Icon(Icons.dark_mode_outlined),
                      label: Text(_s.dark),
                    ),
                    ButtonSegment(
                      value: AppThemePreference.paper,
                      icon: const Icon(Icons.description_outlined),
                      label: Text(_s.paper),
                    ),
                  ],
                  selected: {_settings.theme},
                  onSelectionChanged: _updatingSettings
                      ? null
                      : (value) => _updateSettings(
                          _settings.copyWith(theme: value.first),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SectionTitle(_s.calendar),
          const SizedBox(height: 9),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingLabel(_s.startView),
                const SizedBox(height: 12),
                SegmentedButton<StartViewPreference>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: StartViewPreference.month,
                      label: Text(_s.month),
                    ),
                    ButtonSegment(
                      value: StartViewPreference.week,
                      label: Text(_s.week),
                    ),
                    ButtonSegment(
                      value: StartViewPreference.flow,
                      label: Text(_s.flow),
                    ),
                  ],
                  selected: {_settings.startView},
                  onSelectionChanged: _updatingSettings
                      ? null
                      : (value) => _updateSettings(
                          _settings.copyWith(startView: value.first),
                        ),
                ),
                const Divider(height: 30),
                _SettingLabel(_s.weekStarts),
                const SizedBox(height: 12),
                SegmentedButton<WeekStartPreference>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: WeekStartPreference.monday,
                      label: Text(_s.monday),
                    ),
                    ButtonSegment(
                      value: WeekStartPreference.sunday,
                      label: Text(_s.sunday),
                    ),
                  ],
                  selected: {_settings.weekStart},
                  onSelectionChanged: _updatingSettings
                      ? null
                      : (value) => _updateSettings(
                          _settings.copyWith(weekStart: value.first),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SectionTitle(_s.reminders),
          const SizedBox(height: 9),
          _SettingsCard(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_s.dailyReminder),
                  subtitle: Text(_s.reminderSubtitle),
                  value: _settings.dailyReminderEnabled,
                  onChanged: _updatingSettings
                      ? null
                      : (value) => _updateSettings(
                          _settings.copyWith(dailyReminderEnabled: value),
                        ),
                ),
                if (_settings.dailyReminderEnabled) ...[
                  const Divider(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(_s.reminderTime),
                    trailing: Text(
                      _timeLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: colors.primary),
                    ),
                    onTap: _updatingSettings ? null : _pickReminderTime,
                  ),
                ],
                const Divider(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_s.sound),
                  subtitle: Text(_s.soundSubtitle),
                  value: _settings.soundEnabled,
                  onChanged: _updatingSettings
                      ? null
                      : (value) => _updateSettings(
                          _settings.copyWith(soundEnabled: value),
                        ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_s.vibration),
                  subtitle: Text(_s.vibrationSubtitle),
                  value: _settings.hapticsEnabled,
                  onChanged: _updatingSettings
                      ? null
                      : (value) => _updateSettings(
                          _settings.copyWith(hapticsEnabled: value),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SectionTitle(_s.data),
          const SizedBox(height: 9),
          _SettingsCard(
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.archive_outlined,
                  title: _s.createBackup,
                  subtitle: _s.createBackupSubtitle,
                  onTap: _busy ? null : () => _run(widget.onCreateBackup),
                ),
                const Divider(height: 12),
                _ActionTile(
                  icon: Icons.restore_rounded,
                  title: _s.restoreBackup,
                  subtitle: _s.restoreBackupSubtitle,
                  onTap: _busy ? null : _restore,
                ),
                const Divider(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.brush_outlined),
                  title: Text(_s.t('Takvim çizimleri', 'Calendar drawings')),
                  subtitle: Text(_s.drawingsCount(_doodleCount)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: _doodleCount > 0 && !_busy,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: colors.error,
                  ),
                  title: Text(
                    _s.deleteAll,
                    style: TextStyle(color: colors.error),
                  ),
                  subtitle: Text(_s.deleteAllSubtitle),
                  onTap: _confirmClearDoodles,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SectionTitle(_s.about),
          const SizedBox(height: 9),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingLabel(_s.languageLabel),
                const SizedBox(height: 12),
                SegmentedButton<AppLanguage>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: AppLanguage.turkish,
                      label: Text(_s.turkish),
                    ),
                    ButtonSegment(
                      value: AppLanguage.english,
                      label: Text(_s.english),
                    ),
                  ],
                  selected: {_settings.language},
                  onSelectionChanged: _updatingSettings
                      ? null
                      : (value) => _updateSettings(
                          _settings.copyWith(language: value.first),
                        ),
                ),
                const Divider(height: 30),
                _ActionTile(
                  icon: Icons.shield_outlined,
                  title: _s.privacy,
                  subtitle: _s.privacySubtitle,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => PrivacyPage(language: _settings.language),
                    ),
                  ),
                ),
                if (widget.showRateApp) ...[
                  const Divider(height: 12),
                  _ActionTile(
                    icon: Icons.star_outline_rounded,
                    title: _s.rateApp,
                    subtitle: _s.rateAppSubtitle,
                    onTap: _busy ? null : () => _run(widget.onRateApp),
                  ),
                ],
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 22),
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.7,
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.hardEdge,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) =>
      Text(title, style: Theme.of(context).textTheme.titleMedium);
}
