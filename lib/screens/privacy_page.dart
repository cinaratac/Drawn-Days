import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/app_settings.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key, required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(language);
    return Scaffold(
      appBar: AppBar(title: Text(s.privacyTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            s.t('Çizimlerin sana ait.', 'Your drawings belong to you.'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            s.t(
              'dairry hesap açmaz ve çizimlerini bir sunucuya göndermez. Çizimler ve tercihler cihazında, uygulamanın yerel dosyalarında saklanır.',
              'dairry does not create an account or send your drawings to a server. Drawings and preferences are stored locally on your device.',
            ),
          ),
          const SizedBox(height: 24),
          _PrivacyItem(
            icon: Icons.notifications_none_rounded,
            title: s.t('Bildirimler', 'Notifications'),
            body: s.t(
              'Günlük hatırlatma yalnızca seçtiğin saatte cihaz tarafından oluşturulur. İzni sistem ayarlarından kapatabilirsin.',
              'The daily reminder is created on-device at the time you choose. You can revoke permission in system settings.',
            ),
          ),
          _PrivacyItem(
            icon: Icons.ios_share_rounded,
            title: s.t('Dışa aktarılan dosyalar', 'Exported files'),
            body: s.t(
              'Görsel ve yedek dosyaları ancak sen paylaş düğmesine bastığında seçtiğin uygulamaya gönderilir.',
              'Images and backups are sent to another app only after you choose to share them.',
            ),
          ),
          _PrivacyItem(
            icon: Icons.delete_outline_rounded,
            title: s.t('Silme', 'Deletion'),
            body: s.t(
              'Tüm çizimleri Ayarlar’dan kalıcı olarak silebilirsin. Uygulamayı kaldırmak da yerel verileri kaldırır.',
              'You can permanently delete all drawings from Settings. Removing the app also removes local data.',
            ),
          ),
          _PrivacyItem(
            icon: Icons.analytics_outlined,
            title: s.t('Takip yok', 'No tracking'),
            body: s.t(
              'Bu sürümde reklam, analiz SDK’sı veya kullanıcı profilleme bulunmaz.',
              'This version contains no ads, analytics SDK, or user profiling.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  const _PrivacyItem({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(
                body,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
