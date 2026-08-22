import '../models/app_settings.dart';

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isEnglish => language == AppLanguage.english;
  String t(String tr, String en) => isEnglish ? en : tr;

  String get settings => t('Ayarlar', 'Settings');
  String get today => t('Bugün', 'Today');
  String get month => t('Ay', 'Month');
  String get week => t('Hafta', 'Week');
  String get flow => t('Akış', 'Flow');
  String get dayByDay => t('Gün gün', 'Day by day');
  String get appearance => t('Görünüm', 'Appearance');
  String get calendar => t('Takvim', 'Calendar');
  String get reminders => t('Hatırlatma', 'Reminder');
  String get data => t('Veriler', 'Data');
  String get about => t('Dil ve gizlilik', 'Language & privacy');
  String get paper => t('Kâğıt', 'Paper');
  String get light => t('Açık', 'Light');
  String get dark => t('Koyu', 'Dark');
  String get theme => t('Tema', 'Theme');
  String get startView => t('Açılış görünümü', 'Start view');
  String get weekStarts => t('Haftanın ilk günü', 'First day of week');
  String get monday => t('Pazartesi', 'Monday');
  String get sunday => t('Pazar', 'Sunday');
  String get dailyReminder => t('Günlük hatırlatma', 'Daily reminder');
  String get reminderSubtitle => t(
    'Bugünün karesini çizmen için nazik bir bildirim',
    'A gentle nudge to draw today’s square',
  );
  String get reminderTime => t('Hatırlatma saati', 'Reminder time');
  String get sound => t('Ses', 'Sound');
  String get soundSubtitle =>
      t('Hatırlatmalarda ses çal', 'Play a sound for reminders');
  String get vibration => t('Titreşim', 'Vibration');
  String get vibrationSubtitle => t(
    'Dokunuşlarda ve hatırlatmalarda hafif titreşim',
    'Light feedback for touches and reminders',
  );
  String get exportImage =>
      t('Takvimi görsel olarak dışa aktar', 'Export calendar as image');
  String get exportImageSubtitle => t(
    'Ekrandaki takvim görünümünü PNG olarak paylaş',
    'Share the visible calendar view as a PNG',
  );
  String get createBackup => t('Yedek oluştur', 'Create backup');
  String get createBackupSubtitle => t(
    'Çizimlerini ve ayarlarını tek dosyada sakla',
    'Save drawings and settings in one file',
  );
  String get restoreBackup => t('Yedeği geri yükle', 'Restore backup');
  String get restoreBackupSubtitle =>
      t('Bir dairry yedek dosyası seç', 'Choose a dairry backup file');
  String get languageLabel => t('Dil', 'Language');
  String get turkish => t('Türkçe', 'Turkish');
  String get english => t('İngilizce', 'English');
  String get privacy => t('Gizlilik bilgileri', 'Privacy information');
  String get privacySubtitle =>
      t('Verilerin nasıl saklandığını gör', 'See how your data is stored');
  String drawingsCount(int count) =>
      t('$count güne çizim eklenmiş', 'Drawings added to $count days');
  String get deleteAll => t('Tüm çizimleri sil', 'Delete all drawings');
  String get deleteAllSubtitle => t(
    'Ayarlar ve görünüm tercihleri korunur',
    'Settings and view preferences are kept',
  );
  String get cancel => t('Vazgeç', 'Cancel');
  String get delete => t('Hepsini sil', 'Delete all');
  String get drawingsDeleted =>
      t('Tüm çizimler silindi.', 'All drawings were deleted.');
  String get notificationDenied => t(
    'Bildirim izni verilmedi. Hatırlatma açılamadı.',
    'Notification permission was denied.',
  );
  String get backupRestored => t('Yedek geri yüklendi.', 'Backup restored.');
  String get backupInvalid => t(
    'Bu dosya geçerli bir dairry yedeği değil.',
    'This is not a valid dairry backup.',
  );
  String get operationFailed =>
      t('İşlem tamamlanamadı.', 'The operation could not be completed.');
  String get privacyTitle => t('Gizlilik', 'Privacy');
}
