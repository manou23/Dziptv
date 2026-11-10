import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'app_info.dart';
import 'i18n.dart';
import 'theme.dart';

/// صفحات: من نحن / شروط الاستخدام / سياسة الخصوصية / اتصل بنا
class LegalScreen extends StatelessWidget {
  final String kind; // about | terms | privacy | contact
  const LegalScreen({super.key, required this.kind});

  static const _titles = {
    'about': 'من نحن',
    'terms': 'شروط الاستخدام',
    'privacy': 'سياسة الخصوصية',
    'contact': 'اتصل بنا',
  };

  static const Map<String, Map<String, String>> _texts = {
    'about': {
      'ar': 'Mesut IPTV مشغّل حديث لاشتراكات IPTV عبر Xtream Codes، من تطوير Mesut23.\n\nيدعم البث المباشر والأفلام والمسلسلات ودليل البرامج والمفضلة وعدة حسابات، ويعمل على الهاتف والتلفزيون.\n\nالتطبيق مشغّل فقط ولا يوفّر أي قنوات أو محتوى. يجب أن تستخدم اشتراكك الخاص من مزوّد مرخّص.',
      'fr': "Mesut IPTV est un lecteur moderne pour les abonnements IPTV via Xtream Codes, développé par Mesut23.\n\nIl prend en charge la TV en direct, les films, les séries, le guide des programmes, les favoris et plusieurs profils, sur téléphone et sur TV.\n\nL'application est uniquement un lecteur et ne fournit aucune chaîne ni contenu. Vous devez utiliser votre propre abonnement auprès d'un fournisseur autorisé.",
      'en': 'Mesut IPTV is a modern player for IPTV subscriptions via Xtream Codes, developed by Mesut23.\n\nIt supports live TV, movies, series, program guide, favorites and multiple profiles, on phones and TVs.\n\nThe app is only a player and provides no channels or content. You must use your own subscription from a licensed provider.',
    },
    'terms': {
      'ar': '1) التطبيق مشغّل وسائط فقط ولا يوفّر أي محتوى.\n2) أنت مسؤول عن الاشتراك الذي تضيفه وعن قانونية المحتوى الذي تشاهده.\n3) يُمنع استخدام التطبيق لانتهاك حقوق الملكية أو القوانين المحلية.\n4) يُقدَّم التطبيق كما هو دون ضمان استمرار الخدمة، وقد تتغير ميزاته.\n5) استمرارك في استخدام التطبيق يعني موافقتك على هذه الشروط.',
      'fr': "1) L'application est uniquement un lecteur multimédia et ne fournit aucun contenu.\n2) Vous êtes responsable de l'abonnement que vous ajoutez et de la légalité du contenu que vous regardez.\n3) Il est interdit d'utiliser l'application pour enfreindre des droits de propriété ou les lois locales.\n4) L'application est fournie telle quelle, sans garantie de continuité, et ses fonctions peuvent évoluer.\n5) En continuant à l'utiliser, vous acceptez ces conditions.",
      'en': '1) The app is only a media player and provides no content.\n2) You are responsible for the subscription you add and for the legality of the content you watch.\n3) You must not use the app to infringe intellectual property or local laws.\n4) The app is provided as is, without any guarantee of continuity, and its features may change.\n5) By continuing to use the app you accept these terms.',
    },
    'privacy': {
      'ar': 'يستخدم التطبيق حساب MESUT لتسجيل الدخول والمزامنة السحابية. عند إنشاء الحساب أو تسجيل الدخول، يُرسل البريد الإلكتروني وكلمة المرور عبر اتصال HTTPS؛ وتُحفظ كلمة المرور على الخادم بصيغة تجزئة آمنة ولا تُخزّن كنص صريح.\n\nقد تتم مزامنة المفضلة وسجل المشاهدة والإعدادات وبيانات البروفايلات بين أجهزتك. تُشفّر بيانات البروفايلات، بما فيها بيانات اتصال Xtream، على جهازك قبل إرسالها إلى الخادم، ولا تُرسل كلمة مرور Xtream كنص صريح إلى خدمة المزامنة. كما يحتفظ الخادم بمعرّف الجهاز واسمه ونوعه لإدارة الأجهزة المرتبطة بحسابك.\n\nتبقى بيانات الحساب والمزامنة السحابية محفوظة بعد حذف التطبيق؛ حذف التطبيق يزيل البيانات المحلية فقط. لا تتوفر حالياً ميزة حذف الحساب من داخل التطبيق. لا نستخدم أدوات تحليلات داخل التطبيق.',
      'fr': "L'application utilise un compte MESUT pour la connexion et la synchronisation cloud. Lors de l'inscription ou de la connexion, l'adresse e-mail et le mot de passe sont transmis via HTTPS ; le serveur conserve uniquement une empreinte sécurisée du mot de passe, jamais le texte en clair.\n\nLes favoris, l'historique de lecture, les paramètres et les profils peuvent être synchronisés entre vos appareils. Les profils, y compris les identifiants Xtream, sont chiffrés sur votre appareil avant leur envoi au serveur ; le mot de passe Xtream n'est pas envoyé en clair au service de synchronisation. Le serveur conserve également l'identifiant, le nom et le type de vos appareils associés au compte.\n\nLes données du compte et de synchronisation restent sur le serveur après la désinstallation ; celle-ci supprime uniquement les données locales. La suppression du compte depuis l'application n'est pas encore disponible. Nous n'utilisons pas d'outils d'analyse intégrés.",
      'en': 'The app uses a MESUT account for sign-in and cloud synchronization. When you register or sign in, your email address and password are sent over HTTPS; the server stores a secure password hash, never the plain-text password.\n\nFavorites, watch history, settings, and profiles may sync across your devices. Profiles, including Xtream connection details, are encrypted on your device before upload; the Xtream password is not sent in plain text to the sync service. The server also stores the ID, name, and type of devices linked to your account.\n\nAccount and cloud-sync data remain on the server after uninstalling; uninstalling removes local data only. In-app account deletion is not currently available. We do not use in-app analytics tools.',
    },
  };

  @override
  Widget build(BuildContext context) {
    final lang = I18n.lang;
    return Scaffold(
      appBar: AppBar(title: Text(_titles[kind] ?? '')),
      body: Container(
        decoration: kBgGradient,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: kind == 'contact'
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mesut23',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SelectableText(kContactUrl,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 16, color: kAccent)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(const ClipboardData(text: kContactUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr('تم النسخ'))));
                        }
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('نسخ رابط الدعم'),
                    ),
                  ],
                )
              : SelectableText(
                  _texts[kind]?[lang] ?? _texts[kind]?['en'] ?? '',
                  style: const TextStyle(fontSize: 15, height: 1.8, color: Colors.white70),
                ),
        ),
      ),
    );
  }
}
