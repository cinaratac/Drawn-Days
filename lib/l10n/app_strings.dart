import '../models/app_settings.dart';

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isEnglish => language == AppLanguage.english;
  String t(String tr, String en) => isEnglish ? en : tr;

  String get settings => t('Ayarlar', 'Settings');
  String get today => t('Bugün', 'Today');
  String get share => t('Paylaş', 'Share');
  String get shareDrawing => t('Çizimi paylaş', 'Share drawing');
  String get monthStory => t('Ayın tamamı', 'Full month');
  String get monthStorySubtitle => t(
    'Bu ayın günlerini 4×8 Story ızgarasında paylaş',
    'Share this month in a 4×8 Story grid',
  );
  String get todaySquare => t('Bugünün çizimi', "Today's drawing");
  String get todaySquareSubtitle => t(
    'Bugünün çizimini kare 1:1 görsel olarak paylaş',
    "Share today's drawing as a square 1:1 image",
  );
  String get recentWeekStory => t('Son 7 gün', 'Last 7 days');
  String get recentWeekStorySubtitle => t(
    'Son yedi günü 2×4 Story ızgarasında paylaş',
    'Share the last seven days in a 2×4 Story grid',
  );
  String get preparingShare => t('Görsel hazırlanıyor…', 'Preparing image…');
  String get noDrawingToday =>
      t('Bugün henüz bir çizim yok.', 'There is no drawing for today yet.');
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
    'Bugünün çizimi yapılmadıysa sana bir karalama hatırlatması gönderir',
    'Sends a scribble reminder only when today has not been drawn',
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
  String get createBackup => t('Yedek oluştur', 'Create backup');
  String get createBackupSubtitle => t(
    'Çizimlerini ve ayarlarını tek dosyada sakla',
    'Save drawings and settings in one file',
  );
  String get restoreBackup => t('Yedeği geri yükle', 'Restore backup');
  String get restoreBackupSubtitle =>
      t('Bir Drawn Days yedek dosyası seç', 'Choose a Drawn Days backup file');
  String get languageLabel => t('Dil', 'Language');
  String get turkish => t('Türkçe', 'Turkish');
  String get english => t('İngilizce', 'English');
  String get privacy => t('Gizlilik bilgileri', 'Privacy information');
  String get privacySubtitle =>
      t('Verilerin nasıl saklandığını gör', 'See how your data is stored');
  String get rateApp => t('Uygulamayı değerlendir', 'Rate the app');
  String get rateAppSubtitle =>
      t('Store sayfasında yorum bırak', 'Leave a review on the store page');
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
    'Bu dosya geçerli bir Drawn Days yedeği değil.',
    'This is not a valid Drawn Days backup.',
  );
  String get operationFailed =>
      t('İşlem tamamlanamadı.', 'The operation could not be completed.');
  String get privacyTitle => t('Gizlilik', 'Privacy');
}
