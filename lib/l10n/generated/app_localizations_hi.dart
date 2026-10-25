// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get language => 'भाषा';

  @override
  String get english => 'English';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get punjabi => 'ਪੰਜਾਬੀ';

  @override
  String get home => 'होम';

  @override
  String get tailor => 'सिलाई';

  @override
  String get rental => 'किराया';

  @override
  String get reports => 'रिपोर्ट';

  @override
  String get ava => 'अवा';

  @override
  String get heyAvaListening => '“हे अवा” सुन रही है';

  @override
  String get openAva => 'अवा वॉइस असिस्टेंट खोलें';

  @override
  String get assistantName => 'अवा';

  @override
  String get businessOverview => 'व्यवसाय का सारांश';

  @override
  String get tailoringActivity => 'आपकी सिलाई गतिविधि एक नज़र में';

  @override
  String get ordersByType => 'ऑर्डर के प्रकार';

  @override
  String get tailoringWorkflow => 'सिलाई कार्य';

  @override
  String get rentalWorkflow => 'किराये का कार्य';

  @override
  String get needsAttention => 'ध्यान देने योग्य';

  @override
  String get recentPayments => 'हाल के भुगतान';

  @override
  String get viewAll => 'सभी देखें';

  @override
  String get masters => 'मास्टर';

  @override
  String get administration => 'प्रशासन';

  @override
  String get signOut => 'साइन आउट';

  @override
  String get customers => 'ग्राहक';

  @override
  String get usersAndRoles => 'उपयोगकर्ता और भूमिकाएँ';

  @override
  String get permissions => 'अनुमतियाँ';

  @override
  String get companySettings => 'कंपनी सेटिंग';

  @override
  String get teamSignIn => 'टीम साइन इन';

  @override
  String get signInDescription =>
      'अपनी सिलाई और किराये का प्रबंधन करने के लिए साइन इन करें।';

  @override
  String get signInRequired => 'आवश्यक';

  @override
  String get showPassword => 'पासवर्ड दिखाएँ';

  @override
  String get hidePassword => 'पासवर्ड छिपाएँ';

  @override
  String get current => 'वर्तमान';

  @override
  String get madeToFit => 'सही नाप में।\nपहनने के लिए तैयार।';

  @override
  String get tailoringAndRentals => 'सिलाई और अवसरों के कपड़ों का किराया';

  @override
  String get simplerRental => 'बेहतरीन फिट। आसान किराया।';

  @override
  String get appId => 'ऐप आईडी';

  @override
  String get financialYear => 'वित्तीय वर्ष';

  @override
  String get userName => 'उपयोगकर्ता नाम';

  @override
  String get password => 'पासवर्ड';

  @override
  String get loadFinancialYears => 'वित्तीय वर्ष लोड करें';

  @override
  String get signIn => 'साइन इन';

  @override
  String get assistant => 'सहायक';

  @override
  String get askByTypingOrSpeak => 'लिखकर पूछें या माइक्रोफ़ोन दबाकर बोलें।';

  @override
  String get typeRequest => 'अनुरोध लिखें या खोजें';

  @override
  String get speakRequest => 'बोलकर अनुरोध करें';

  @override
  String get stopListening => 'सुनना बंद करें';

  @override
  String get sendRequest => 'अनुरोध भेजें';

  @override
  String get openItemMaster => 'आइटम मास्टर खोलें';

  @override
  String get openNewOrder => 'नया ऑर्डर फ़ॉर्म खोलें';

  @override
  String get openRentalBooking => 'किराये की बुकिंग खोलें';

  @override
  String get howCanIHelp => 'मैं आपकी क्या मदद करूँ?';

  @override
  String get assistantWelcome =>
      'ग्राहक, ऑर्डर, बुकिंग और आइटम खोजें या नया फ़ॉर्म खोलें।';

  @override
  String get suggestCreateItem => 'नया आइटम बनाओ';

  @override
  String get suggestCreateTailoring => 'सिलाई का ऑर्डर बनाओ';

  @override
  String get suggestRental => 'किराये की बुकिंग शुरू करो';

  @override
  String get suggestHelp => 'आप क्या कर सकते हैं?';

  @override
  String get speechUnavailable =>
      'वॉइस पहचान उपलब्ध नहीं है। आप अनुरोध लिख सकते हैं।';

  @override
  String couldNotStartSpeech(Object error) {
    return 'वॉइस इनपुट शुरू नहीं हो सका: $error';
  }

  @override
  String voiceSearchLanguageUnavailable(Object language) {
    return 'इस डिवाइस पर $language में वॉइस पहचान उपलब्ध नहीं है। फ़ोन के भाषा पैक देखें या दूसरी भाषा चुनें।';
  }

  @override
  String get helpText =>
      'कहें “नया आइटम बनाओ”, “सिलाई ऑर्डर बनाओ”, “किराये की बुकिंग शुरू करो”, “मेरी बुकिंग दिखाओ”, या ग्राहक, मोबाइल, आइटम अथवा ऑर्डर नंबर खोजें।';

  @override
  String get createItemAction => 'मैं आपके लिए नया आइटम फ़ॉर्म खोल सकता हूँ।';

  @override
  String get createTailoringAction =>
      'मैं आपके लिए नया सिलाई ऑर्डर खोल सकता हूँ।';

  @override
  String get createRentalAction =>
      'मैं आपके लिए किराये की बुकिंग खोल सकता हूँ।';

  @override
  String get createItemResponse =>
      'मैं नया आइटम बनाने में मदद कर सकता हूँ। विवरण भरने और जाँचने के लिए आइटम मास्टर खोलें।';

  @override
  String get createTailoringResponse =>
      'मैं सिलाई ऑर्डर शुरू करने में मदद कर सकता हूँ। मौजूदा फ़ॉर्म सेव करने से पहले जानकारी जाँचेगा।';

  @override
  String get createRentalResponse =>
      'मैं किराये की बुकिंग शुरू करने में मदद कर सकता हूँ। मौजूदा प्रक्रिया सेव करने से पहले उपलब्धता जाँचेगी।';

  @override
  String get rentalAccessDenied =>
      'आपके खाते को किराये की बुकिंग की अनुमति नहीं है।';

  @override
  String get tailoringAccessDenied =>
      'आपके खाते को सिलाई ऑर्डर की अनुमति नहीं है।';

  @override
  String noSearchMatch(Object query) {
    return '“$query” के लिए कोई रिकॉर्ड नहीं मिला। ग्राहक का नाम, मोबाइल, ऑर्डर नंबर, बुकिंग या आइटम खोजें।';
  }

  @override
  String searchMatchCount(int count, Object query) {
    return '“$query” के लिए $count परिणाम मिले। संबंधित भाग खोलने के लिए परिणाम दबाएँ।';
  }

  @override
  String searchError(Object areas, Object error) {
    return '$areas खोज नहीं सका: $error';
  }

  @override
  String get noRecordsFound =>
      'मिलता-जुलता रिकॉर्ड नहीं मिला। ग्राहक का नाम, मोबाइल नंबर, आइटम, ऑर्डर या बुकिंग नंबर खोजें।';
}
