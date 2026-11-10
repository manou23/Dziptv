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
      'ar': 'يحفظ التطبيق على جهازك فقط: عنوان الخادم واسم المستخدم وكلمة المرور والمفضلة وسجل المشاهدة والإعدادات. لا نرسل هذه البيانات إلينا ولا إلى أي طرف آخر.\n\nيعرض التطبيق إعلانات Google AdMob التي قد تجمع معرّف الإعلانات ومعلومات الجهاز. لا نستخدم أدوات تحليلات ولا ننشئ حساباً لدى خوادمنا.\n\nتُحذف البيانات بحذف التطبيق أو مسح بياناته.',
      'fr': "L'application enregistre uniquement sur votre appareil : l'adresse du serveur, le nom d'utilisateur, le mot de passe, les favoris, l'historique de lecture et les paramètres. Ces données ne nous sont pas envoyées ni à des tiers.\n\nL'application affiche des publicités Google AdMob, qui peuvent collecter l'identifiant publicitaire et des informations sur l'appareil. Nous n'utilisons aucun outil d'analyse et ne créons aucun compte sur nos serveurs.\n\nLes données sont supprimées en désinstallant l'application ou en effaçant ses données.",
      'en': 'The app stores only on your device: the server address, username, password, favorites, watch history and settings. This data is not sent to us or to anyone else.\n\nThe app shows Google AdMob ads, which may collect the advertising ID and device information. We use no analytics tools and create no account on our servers.\n\nData is removed when you uninstall the app or clear its data.',
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
                    SelectableText(kContactEmail,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 16, color: kAccent)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(const ClipboardData(text: kContactEmail));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr('تم النسخ'))));
                        }
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('نسخ البريد'),
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
