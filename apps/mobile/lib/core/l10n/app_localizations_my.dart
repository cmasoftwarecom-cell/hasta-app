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
      'ဖုန်းပျောက်ပါက ဤအကောင့်ကို ပြန်ရနိုင်မည် မဟုတ်ပါ။ Gmail ချိတ်ဆက်ထားရန် အကြံပြုသည်။';

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

  @override
  String get transferSend => 'စက်ပြောင်းရန်';

  @override
  String get transferReceive => 'Hasta အကောင့် လက်ခံရန်';

  @override
  String get transferSendHelp =>
      'စက်နှစ်လုံးစလုံး အင်တာနက် ချိတ်ထားပါ။ စက်အသစ်တွင် Hasta အိုင်ကွန်ကို ဖိထားပြီး အကောင့် လက်ခံရန်ကို ရွေးပါ။';

  @override
  String get transferReceiveHelp =>
      'စက်ဟောင်း၏ ဆက်တင်များတွင် ပြထားသော QR ကုဒ်ကို စကင်ဖတ်ပါ။ ဤစက်တွင် ဧည့်သည်အကောင့် ကြိုမဖွင့်ပါနှင့်။';

  @override
  String get transferShow => 'စက်ပြောင်းရန် QR ပြပါ';

  @override
  String get transferScan => 'ကင်မရာဖွင့်ပြီး စကင်ဖတ်ရန်';

  @override
  String get transferApprove => 'ကုဒ်တူပါသည်။ အတည်ပြုရန်';

  @override
  String get transferCompare =>
      'စက်နှစ်လုံးပေါ်ရှိ ကုဒ်ကို တိုက်ကြည့်ပါ။ ကုဒ်တူမှသာ စက်ဟောင်းတွင် အတည်ပြုပါ။';

  @override
  String get transferQrLabel =>
      'စက်ပြောင်းရန် QR ကုဒ်။ စက်အသစ်ဖြင့် စကင်ဖတ်ပါ။';

  @override
  String get transferEnded =>
      'ဤလွှဲပြောင်းမှု ပြီးဆုံးပါပြီ။ စက်ဟောင်းတွင် အသစ်ပြန်စပါ။';

  @override
  String transferReceiverEnded(String continueLabel) {
    return 'စက်ဟောင်းတွင် လွှဲပြောင်းမှုကို အတည်ပြုပြီးပါက ဤစက်တွင် မျက်နှာပြင်ကို ပိတ်ပြီး “$continueLabel” ကို နှိပ်၍ အကောင့်ကို ဆက်လက်အသုံးပြုပါ။ အတည်မပြုရသေးပါက စက်ဟောင်းတွင် လွှဲပြောင်းမှု အသစ်ပြန်စပါ။';
  }

  @override
  String get transferGuestExists =>
      'ဤဖုန်းရှိ guest အကောင့်ကို ဖျက်ပြီးမှ ပြောင်းနိုင်သည်။';

  @override
  String get transferAccountExists =>
      'ဤစက်တွင် Hasta အကောင့် ရှိပြီးဖြစ်၍ အကောင့် လွှဲပြောင်းလက်ခံ၍ မရပါ။';

  @override
  String get transferCameraDenied =>
      'QR ကုဒ် စကင်ဖတ်ရန် စက်၏ ဆက်တင်များတွင် ကင်မရာ အသုံးပြုခွင့် ပေးပါ။';

  @override
  String get transferCameraUnavailable => 'ဤစက်တွင် ကင်မရာ အသုံးပြု၍ မရပါ။';

  @override
  String get transferInvalid =>
      'Hasta စက်ပြောင်း QR ကုဒ် မဟုတ်ပါ။ စက်ဟောင်းပေါ်ရှိ ကုဒ်ကို စကင်ဖတ်ပါ။';

  @override
  String get transferApprovalCancelled =>
      'အတည်ပြုမှု ပယ်ဖျက်လိုက်ပါသည်။ အကောင့် မပြောင်းရသေးပါ။';

  @override
  String get transferUnavailable =>
      'ဤစက်တွင် လုံခြုံစွာ လွှဲပြောင်း၍ မရပါ။ မျက်နှာပြင် လော့ခ် ဖွင့်ထားကြောင်း စစ်ပါ။';

  @override
  String transferTime(int seconds) {
    return '$seconds စက္ကန့် ကျန်ပါသည်';
  }
}
