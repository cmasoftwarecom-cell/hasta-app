// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Burmese (`my`).
class AppLocalizationsMy extends AppLocalizations {
  AppLocalizationsMy([String locale = 'my']) : super(locale);

  @override
  String get appTitle => 'Hasta';

  @override
  String get genericError => 'မအောင်မြင်ပါ။ ခဏနေမှ ပြန်ကြိုးစားပါ။ (E-500)';

  @override
  String get welcomeContinue => 'စတင်အသုံးပြုရန်';

  @override
  String get welcomeGuest =>
      'အီးမေးလ်၊ ဖုန်းနံပါတ် မလိုပါ။ ဤဖုန်းတွင် ချက်ချင်း စတင်နိုင်သည်။';

  @override
  String get guestRisk =>
      'ဤဖုန်းပျောက်ပါက ဧည့်သည်အကောင့်ကို ပြန်သုံးနိုင်မည် မဟုတ်ပါ။';

  @override
  String get privacyTerms => 'ကိုယ်ရေးအချက်အလက်နှင့် စည်းကမ်းချက်များ';

  @override
  String get privacySummary =>
      'ဧည့်သည်အကောင့်ကို ဤဖုန်းနှင့် ချိတ်ထားရန် Hasta က ဖုန်း၏ သတ်မှတ်အမှတ်ကို သုံးပြီး အကောင့်ဝင်ရန် အချက်အလက်များကို လုံခြုံစွာ သိမ်းထားပါသည်။ ဤအစမ်းဗားရှင်းတွင် အပြီးသတ် ကိုယ်ရေးမူဝါဒနှင့် စည်းကမ်းချက်များ မပါသေးပါ။';

  @override
  String get close => 'ပိတ်ရန်';

  @override
  String get offline => 'အင်တာနက် မရှိပါ။ ချိတ်ဆက်ပြီး ပြန်ကြိုးစားပါ။';

  @override
  String get retry => 'ပြန်ကြိုးစားရန်';

  @override
  String get profile => 'ကိုယ်ရေးအချက်အလက်';

  @override
  String get guestProfile => 'ဧည့်သည်ပရိုဖိုင်';

  @override
  String get emptyProfile => 'ကိုယ်ရေးအချက်အလက် မထည့်ရသေးပါ။';

  @override
  String get settings => 'ဆက်တင်များ';

  @override
  String get account => 'အကောင့်';

  @override
  String get signOut => 'အကောင့်ထွက်ရန်';

  @override
  String get loading => 'ဖွင့်နေပါသည်…';

  @override
  String get rateLimited =>
      'အကြိမ်များလွန်းပါသည်။ ခဏစောင့်ပြီး ပြန်ကြိုးစားပါ။';
}
