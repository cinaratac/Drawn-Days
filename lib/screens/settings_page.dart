import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../theme/drawn_days_theme.dart';
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
    final baseTheme = Theme.of(context);
    final colors = baseTheme.colorScheme;
    final drawnTheme = context.drawnTheme;
    final theme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'PatrickHand'),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(
        fontFamily: 'PatrickHand',
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFFFFFEF8)
              : const Color(0xFF7E8983),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFF2E704F)
              : drawnTheme.grid,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFFF2D762)
                : drawnTheme.paper,
          ),
          foregroundColor: WidgetStatePropertyAll(drawnTheme.ink),
          side: WidgetStatePropertyAll(
            BorderSide(color: drawnTheme.ink, width: 1.8),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: 'PatrickHand', fontSize: 18),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          ),
        ),
      ),
    );
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: drawnTheme.page,
        body: CustomPaint(
          painter: _SettingsPaperPainter(
            background: drawnTheme.page,
            texture: drawnTheme.texture,
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(height: MediaQuery.paddingOf(context).top),
              const SizedBox(height: 42, child: _SettingsSpiral()),
              _SettingsHeader(title: _s.settings),
              const SizedBox(height: 7),
              _SectionTitle(_s.appearance, color: const Color(0xFF8F58B0)),
              const SizedBox(height: 5),
              _SettingsCard(
                tapeColor: const Color(0xFFD7B7E8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingLabel(_s.theme),
                    const SizedBox(height: 12),
                    SegmentedButton<AppThemePreference>(
                      expandedInsets: EdgeInsets.zero,
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
              const SizedBox(height: 14),
              _SectionTitle(_s.calendar, color: const Color(0xFF4A83AD)),
              const SizedBox(height: 5),
              _SettingsCard(
                tapeColor: const Color(0xFFB9D6E5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingLabel(_s.startView),
                    const SizedBox(height: 12),
                    SegmentedButton<StartViewPreference>(
                      expandedInsets: EdgeInsets.zero,
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
                    const _DottedDivider(),
                    _SettingLabel(_s.weekStarts),
                    const SizedBox(height: 12),
                    SegmentedButton<WeekStartPreference>(
                      expandedInsets: EdgeInsets.zero,
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
              const SizedBox(height: 14),
              _SectionTitle(_s.reminders, color: const Color(0xFFB15F3C)),
              const SizedBox(height: 5),
              _SettingsCard(
                tapeColor: const Color(0xFFE8B69D),
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
                      const _DottedDivider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule_rounded),
                        title: Text(_s.reminderTime),
                        trailing: Text(
                          _timeLabel,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: colors.primary),
                        ),
                        onTap: _updatingSettings ? null : _pickReminderTime,
                      ),
                    ],
                    const _DottedDivider(),
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
              const SizedBox(height: 14),
              _SectionTitle(_s.data, color: const Color(0xFF2E704F)),
              const SizedBox(height: 5),
              _SettingsCard(
                tapeColor: const Color(0xFFB8D8C4),
                child: Column(
                  children: [
                    _ActionTile(
                      icon: Icons.archive_outlined,
                      title: _s.createBackup,
                      subtitle: _s.createBackupSubtitle,
                      onTap: _busy ? null : () => _run(widget.onCreateBackup),
                    ),
                    const _DottedDivider(),
                    _ActionTile(
                      icon: Icons.restore_rounded,
                      title: _s.restoreBackup,
                      subtitle: _s.restoreBackupSubtitle,
                      onTap: _busy ? null : _restore,
                    ),
                    const _DottedDivider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.brush_outlined),
                      title: Text(
                        _s.t('Takvim çizimleri', 'Calendar drawings'),
                      ),
                      subtitle: Text(_s.drawingsCount(_doodleCount)),
                    ),
                    const _DottedDivider(color: Color(0xFFE3A49B)),
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
              const SizedBox(height: 14),
              _SectionTitle(_s.about, color: const Color(0xFF293A35)),
              const SizedBox(height: 5),
              _SettingsCard(
                tapeColor: const Color(0xFFF2D762),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingLabel(_s.languageLabel),
                    const SizedBox(height: 12),
                    SegmentedButton<AppLanguage>(
                      expandedInsets: EdgeInsets.zero,
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
                    const _DottedDivider(),
                    _ActionTile(
                      icon: Icons.shield_outlined,
                      title: _s.privacy,
                      subtitle: _s.privacySubtitle,
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PrivacyPage(language: _settings.language),
                        ),
                      ),
                    ),
                    if (widget.showRateApp) ...[
                      const _DottedDivider(),
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
              const SizedBox(height: 34),
              const Center(
                child: SizedBox(width: 155, height: 56, child: _SettingsLogo()),
              ),
              const SizedBox(height: 70),
            ],
          ),
        ),
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 2),
    leading: Icon(icon, color: context.drawnTheme.ink),
    title: Text(
      title,
      style: TextStyle(
        color: context.drawnTheme.ink,
        fontFamily: 'PatrickHand',
        fontSize: 20,
        height: 1,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: TextStyle(
        color: context.drawnTheme.mutedInk,
        fontFamily: 'PatrickHand',
        fontSize: 15,
      ),
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: 'PatrickHand',
            fontSize: 22,
            height: 1,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          height: 8,
          child: CustomPaint(painter: _WavySettingsLinePainter(color: color)),
        ),
      ],
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, required this.tapeColor});
  final Widget child;
  final Color tapeColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: Material(
            color: context.drawnTheme.paper,
            elevation: 3,
            shadowColor: context.drawnTheme.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: context.drawnTheme.ink, width: 1.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 12, 17, 10),
              child: child,
            ),
          ),
        ),
        Positioned(
          top: -10,
          right: 29,
          child: Transform.rotate(
            angle: .045,
            child: Container(
              width: 68,
              height: 21,
              color: tapeColor.withValues(alpha: .72),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: TextStyle(
      color: context.drawnTheme.ink,
      fontFamily: 'PatrickHand',
      fontSize: 21,
      height: 1,
    ),
  );
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: Row(
      children: [
        const SizedBox(width: 10),
        Material(
          color: context.drawnTheme.paper,
          elevation: 3,
          shadowColor: const Color(0x3353605A),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: 49,
              child: Icon(
                Icons.arrow_back_rounded,
                color: context.drawnTheme.ink,
                size: 29,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.drawnTheme.ink,
                fontFamily: 'PatrickHand',
                fontSize: 38,
                height: 1,
              ),
            ),
            const Positioned(
              left: 2,
              right: 0,
              bottom: -7,
              height: 8,
              child: CustomPaint(
                painter: _WavySettingsLinePainter(color: Color(0xFFB15F3C)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DottedDivider extends StatelessWidget {
  const _DottedDivider({this.color = const Color(0xFFB8BDB7)});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 14,
    child: CustomPaint(painter: _DottedLinePainter(color: color)),
  );
}

class _DottedLinePainter extends CustomPainter {
  const _DottedLinePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + 1.2, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _WavySettingsLinePainter extends CustomPainter {
  const _WavySettingsLinePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(1, size.height * .55)
        ..cubicTo(
          size.width * .23,
          0,
          size.width * .38,
          size.height,
          size.width * .56,
          size.height * .48,
        )
        ..cubicTo(
          size.width * .72,
          0,
          size.width * .86,
          size.height,
          size.width - 1,
          size.height * .38,
        ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WavySettingsLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SettingsSpiral extends StatelessWidget {
  const _SettingsSpiral();
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _SettingsSpiralPainter(),
    child: const SizedBox.expand(),
  );
}

class _SettingsSpiralPainter extends CustomPainter {
  const _SettingsSpiralPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF53605A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    final count = (size.width / 16).ceil();
    final gap = size.width / count;
    for (var i = 0; i < count; i++) {
      final x = gap * (i + .5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 4.5, 2, 9, size.height - 12),
          const Radius.circular(6),
        ),
        paint,
      );
      canvas.drawCircle(
        Offset(x, size.height - 4),
        1.2,
        Paint()..color = const Color(0xFF53605A).withValues(alpha: .4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SettingsPaperPainter extends CustomPainter {
  const _SettingsPaperPainter({
    required this.background,
    required this.texture,
  });
  final Color background;
  final Color texture;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final random = math.Random(4);
    final paint = Paint()..color = texture;
    for (var i = 0; i < (size.width * size.height / 150).round(); i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        .45,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SettingsPaperPainter oldDelegate) =>
      oldDelegate.background != background || oldDelegate.texture != texture;
}

class _SettingsLogo extends StatelessWidget {
  const _SettingsLogo();
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 4,
        right: 2,
        bottom: 5,
        height: 13,
        child: Transform.rotate(
          angle: -.025,
          child: Container(color: const Color(0xFFE8C94F)),
        ),
      ),
      Positioned.fill(
        child: Image.asset(
          'lib/assets/appname.png',
          fit: BoxFit.fitWidth,
          color: context.drawnTheme.ink,
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    ],
  );
}
