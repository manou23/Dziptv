import 'package:flutter/material.dart' hide Text;
import 'package:flutter/widgets.dart' as w show Text;
import 'store.dart';

/// اللغات: ar (العربية) / fr (Français) / en (English)
class I18n {
  static String lang = 'ar';
  static final ValueNotifier<String> notifier = ValueNotifier('ar');

  static bool get rtl => lang == 'ar';

  static void init() {
    lang = Store.lang;
    notifier.value = lang;
  }

  static Future<void> set(String l) async {
    await Store.setLang(l);
    lang = l;
    notifier.value = l;
  }
}

/// المفتاح هو النص العربي. العربية تعيده كما هو، والفرنسية/الإنجليزية من القاموس.
String tr(String s) {
  if (I18n.lang == 'ar') return s;
  final v = _d[s];
  if (v == null) return s;
  return I18n.lang == 'fr' ? v[0] : v[1];
}

/// بديل لـ Text يترجم النص تلقائياً حسب اللغة الحالية
class Text extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  const Text(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context); // إعادة البناء عند تغيير اللغة
    return w.Text(
      tr(data),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      textDirection: textDirection,
    );
  }
}

// [فرنسي, إنجليزي]
const Map<String, List<String>> _d = {
  'هذا التطبيق مشغّل فقط ولا يوفّر أي قنوات أو محتوى. استخدم اشتراكك الخاص.': ["Cette application est un simple lecteur : elle ne fournit aucune chaîne ni contenu. Utilisez votre propre abonnement.", "This app is only a player and provides no channels or content. Use your own subscription."],
  'بحث': ["Recherche", "Search"],
  'الرياضة': ["Sports", "Sports"],
  'شوهد مؤخراً': ["Vus récemment", "Recently watched"],
  'المفضلة': ["Favoris", "Favorites"],
  'ابدأ المشاهدة': ["Commencer à regarder", "Start watching"],
  'المباريات القادمة': ["Matchs à venir", "Upcoming matches"],
  'النتائج': ["Résultats", "Results"],
  'لا توجد مباريات': ["Aucun match", "No matches"],
  'تعذر تحميل البيانات': ["Impossible de charger les données", "Couldn't load data"],
  'المصدر: TheSportsDB - النتائج المباشرة تتطلب مفتاحاً مدفوعاً': ["Source : TheSportsDB - les scores en direct nécessitent une clé payante", "Source: TheSportsDB - live scores require a paid key"],
  'ابحث في القنوات والأفلام والمسلسلات': ["Rechercher chaînes, films et séries", "Search channels, movies and series"],
  'القنوات': ["Chaînes", "Channels"],
  'اكتب للبحث': ["Saisissez pour rechercher", "Type to search"],
  'لا توجد نتائج': ["Aucun résultat", "No results"],
  'من نحن': ["À propos", "About us"],
  'شروط الاستخدام': ["Conditions d'utilisation", "Terms of use"],
  'سياسة الخصوصية': ["Politique de confidentialité", "Privacy policy"],
  'اتصل بنا': ["Contact", "Contact us"],
  'تم النسخ': ["Copié", "Copied"],
  'نسخ البريد': ["Copier l'e-mail", "Copy email"],
  'أقسام الصفحة الرئيسية': ["Sections de l'accueil", "Home sections"],
  'الرئيسية': ["Accueil", "Home"],
  'مفتاح API للرياضة': ["Clé API sport", "Sports API key"],
  'الافتراضي (مجاني)': ["Par défaut (gratuit)", "Default (free)"],
  'النسخ الاحتياطي': ["Sauvegarde", "Backup"],
  'نسخ النسخة الاحتياطية': ["Copier la sauvegarde", "Copy backup"],
  'تحذير: تحتوي على بيانات دخولك': ["Attention : contient vos identifiants", "Warning: contains your login details"],
  'تم نسخ النسخة الاحتياطية إلى الحافظة': ["Sauvegarde copiée dans le presse-papiers", "Backup copied to clipboard"],
  'استعادة من الحافظة': ["Restaurer depuis le presse-papiers", "Restore from clipboard"],
  'النص في الحافظة ليس نسخة صحيحة': ["Le texte copié n'est pas une sauvegarde valide", "Clipboard text is not a valid backup"],
  'الأداء': ["Performance", "Performance"],
  'اختبار السرعة': ["Test de vitesse", "Speed test"],
  'جارٍ الاختبار...': ["Test en cours...", "Testing..."],
  'سرعة التحميل': ["Vitesse de téléchargement", "Download speed"],
  'استجابة السيرفر': ["Réponse du serveur", "Server response"],
  'مسح الذاكرة المؤقتة للصور': ["Vider le cache des images", "Clear image cache"],
  'تم المسح': ["Effacé", "Cleared"],
  'حول التطبيق': ["À propos de l'app", "About the app"],
  'التحقق من التحديثات': ["Rechercher des mises à jour", "Check for updates"],
  'لم يتم ضبط مصدر التحديثات': ["Source des mises à jour non configurée", "Update source is not configured"],
  'أنت تستخدم أحدث إصدار': ["Vous utilisez la dernière version", "You're on the latest version"],
  'يتوفر إصدار جديد': ["Nouvelle version disponible", "New version available"],
  'الصوت والترجمة': ["Audio et sous-titres", "Audio and subtitles"],
  'المسار الصوتي': ["Piste audio", "Audio track"],
  'الترجمة': ["Sous-titres", "Subtitles"],
  'بدون': ["Aucun", "None"],
  'افتراضي': ["Par défaut", "Default"],
  'تسجيل الدخول': ["Connexion", "Sign in"],
  'سجّل الدخول بحساب الاشتراك': ["Connectez-vous avec votre abonnement", "Sign in with your subscription"],
  'اسم الحساب (اختياري)': ["Nom du profil (facultatif)", "Profile name (optional)"],
  'رابط السيرفر أو رابط M3U': ["URL du serveur ou lien M3U", "Server URL or M3U link"],
  'اسم المستخدم': ["Nom d'utilisateur", "Username"],
  'كلمة المرور': ["Mot de passe", "Password"],
  'املأ رابط السيرفر واسم المستخدم وكلمة المرور': ["Renseignez l'URL, l'utilisateur et le mot de passe", "Enter the server URL, username and password"],
  'خطأ من السيرفر': ["Erreur du serveur", "Server error"],
  'بيانات الدخول غير صحيحة': ["Identifiants incorrects", "Invalid credentials"],
  'الاشتراك غير فعّال': ["Abonnement inactif", "Subscription inactive"],
  'غير محدود': ["Illimité", "Unlimited"],
  'متابعة المشاهدة': ["Reprendre la lecture", "Continue watching"],
  'الإعدادات': ["Paramètres", "Settings"],
  'البث المباشر': ["TV en direct", "Live TV"],
  'الأفلام': ["Films", "Movies"],
  'المسلسلات': ["Séries", "Series"],
  'ينتهي': ["Expire", "Expires"],
  'تبديل الحساب': ["Changer de profil", "Switch profile"],
  'بحث...': ["Rechercher...", "Search..."],
  '⭐ المفضلة': ["⭐ Favoris", "⭐ Favorites"],
  'تعذر تحميل المحتوى': ["Impossible de charger le contenu", "Couldn't load content"],
  'لا يوجد محتوى': ["Aucun contenu", "No content"],
  'اضغط مطولاً على أي عنصر لإضافته للمفضلة': ["Appui long sur un élément pour l'ajouter aux favoris", "Long-press any item to add it to favorites"],
  'أُضيف إلى المفضلة': ["Ajouté aux favoris", "Added to favorites"],
  'أُزيل من المفضلة': ["Retiré des favoris", "Removed from favorites"],
  'لا يوجد وصف': ["Aucune description", "No description"],
  'متابعة من': ["Reprendre à", "Resume from"],
  'تشغيل': ["Lecture", "Play"],
  'الممثلون': ["Acteurs", "Cast"],
  'المخرج': ["Réalisateur", "Director"],
  'تعذر تحميل الحلقات': ["Impossible de charger les épisodes", "Couldn't load episodes"],
  'الموسم': ["Saison", "Season"],
  'الحلقة': ["Épisode", "Episode"],
  'متابعة': ["Reprendre", "Resume"],
  'تعذر تشغيل الفيديو': ["Lecture impossible", "Couldn't play video"],
  'إعادة المحاولة': ["Réessayer", "Retry"],
  'ابحث عن قناة...': ["Rechercher une chaîne...", "Search channels..."],
  'يعرض الآن': ["En cours", "Now playing"],
  'اختر قناة للتشغيل': ["Choisissez une chaîne", "Pick a channel to play"],
  'تعذر تشغيل القناة': ["Chaîne indisponible", "Couldn't play channel"],
  'إعادة المحاولة...': ["Nouvelle tentative...", "Retrying..."],
  'لا توجد قنوات': ["Aucune chaîne", "No channels"],
  'التالي': ["Ensuite", "Next"],
  'اللغة': ["Langue", "Language"],
  'الحسابات': ["Profils", "Accounts"],
  'إضافة حساب': ["Ajouter un profil", "Add profile"],
  'التشغيل': ["Lecture", "Playback"],
  'صيغة البث المباشر': ["Format du direct", "Live stream format"],
  'جرّب m3u8 إذا كان ts لا يعمل مع سيرفرك': ["Essayez m3u8 si ts ne marche pas avec votre serveur", "Try m3u8 if ts doesn't work with your server"],
  'الحماية': ["Sécurité", "Security"],
  'تعيين رمز سري': ["Définir un code PIN", "Set PIN"],
  'تغيير الرمز السري': ["Changer le code PIN", "Change PIN"],
  'يحمي التصنيفات المخصصة للكبار': ["Protège les catégories pour adultes", "Protects adult categories"],
  'حذف الرمز السري': ["Supprimer le code PIN", "Remove PIN"],
  'البيانات': ["Données", "Data"],
  'مسح سجل المشاهدة': ["Effacer l'historique", "Clear watch history"],
  'مسح المفضلة': ["Effacer les favoris", "Clear favorites"],
  'تم مسح السجل': ["Historique effacé", "History cleared"],
  'تم مسح المفضلة': ["Favoris effacés", "Favorites cleared"],
  'رمز سري جديد (4 أرقام)': ["Nouveau code PIN (4 chiffres)", "New PIN (4 digits)"],
  'إلغاء': ["Annuler", "Cancel"],
  'حفظ': ["Enregistrer", "Save"],
  'يجب أن يتكون الرمز من 4 أرقام': ["Le code doit contenir 4 chiffres", "PIN must be 4 digits"],
  'تم حفظ الرمز السري': ["Code PIN enregistré", "PIN saved"],
  'تم حذف الرمز السري': ["Code PIN supprimé", "PIN removed"],
  'أدخل الرمز السري': ["Saisissez le code PIN", "Enter PIN"],
  'تأكيد': ["Confirmer", "Confirm"],
  'الرمز غير صحيح': ["Code incorrect", "Incorrect PIN"],
  'من يشاهد؟': ["Qui regarde ?", "Who's watching?"],
  'رمز PIN (4 إلى 6 أرقام)': ["Code PIN (4 à 6 chiffres)", "PIN (4 to 6 digits)"],
  'أدخل PIN لفتح': ["Saisissez le PIN pour ouvrir", "Enter PIN to unlock"],
  'أدخل PIN الحالي': ["Saisissez le PIN actuel", "Enter current PIN"],
  'رمز PIN جديد': ["Nouveau code PIN", "New PIN"],
  'أعد إدخال PIN للتأكيد': ["Confirmez le code PIN", "Re-enter PIN to confirm"],
  'رمز PIN غير صحيح': ["Code PIN incorrect", "Incorrect PIN"],
  'يجب أن يتكون PIN من 4 إلى 6 أرقام': ["Le PIN doit contenir 4 à 6 chiffres", "PIN must contain 4 to 6 digits"],
  'الرمزان غير متطابقين': ["Les codes PIN ne correspondent pas", "PINs do not match"],
  'تم حفظ PIN لهذا البروفايل': ["PIN enregistré pour ce profil", "PIN saved for this profile"],
  'تمت إزالة PIN': ["PIN supprimé", "PIN removed"],
  'تعيين PIN': ["Définir PIN", "Set PIN"],
  'تغيير PIN': ["Modifier PIN", "Change PIN"],
  'أدخل PIN الحالي لإزالته': ["Saisissez le PIN actuel pour le supprimer", "Enter current PIN to remove it"],
  'إدارة الحسابات': ["Gérer les profils", "Manage profiles"],
  'اختر الخدمة': ["Choisissez un service", "Choose a service"],
  'اختر ما تريد استخدامه': ["Choisissez ce que vous voulez utiliser", "Choose what you want to use"],
  'مواعيد المباريات والنتائج': ["Calendrier et résultats des matchs", "Match schedules and results"],
  'قنوات وأفلام ومسلسلات باشتراكك': ["Chaînes, films et séries avec votre abonnement", "Channels, movies and series with your subscription"],
  'الخدمات': ["Services", "Services"],
  'إزالة PIN': ["Supprimer le PIN", "Remove PIN"],
  'إظهار PIN': ["Afficher le PIN", "Show PIN"],
  'إخفاء PIN': ["Masquer le PIN", "Hide PIN"],
  'تم': ["Terminé", "Done"],
  'حذف الحساب': ["Supprimer le profil", "Delete profile"],
  'هل تريد حذف هذا الحساب؟': ["Voulez-vous supprimer ce profil ?", "Delete this profile?"],
  'حذف': ["Supprimer", "Delete"],
};
