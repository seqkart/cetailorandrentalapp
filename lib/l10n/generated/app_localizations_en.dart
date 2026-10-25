// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get punjabi => 'ਪੰਜਾਬੀ';

  @override
  String get home => 'Home';

  @override
  String get tailor => 'Tailor';

  @override
  String get rental => 'Rental';

  @override
  String get reports => 'Reports';

  @override
  String get ava => 'Ava';

  @override
  String get heyAvaListening => 'Listening for “Hey Ava”';

  @override
  String get openAva => 'Open Ava voice assistant';

  @override
  String get assistantName => 'Ava';

  @override
  String get businessOverview => 'Business overview';

  @override
  String get tailoringActivity => 'Your tailoring activity at a glance';

  @override
  String get ordersByType => 'Orders by type';

  @override
  String get tailoringWorkflow => 'Tailoring workflow';

  @override
  String get rentalWorkflow => 'Rental workflow';

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get recentPayments => 'Recent payments';

  @override
  String get viewAll => 'View all';

  @override
  String get masters => 'Masters';

  @override
  String get administration => 'Administration';

  @override
  String get signOut => 'Sign out';

  @override
  String get customers => 'Customers';

  @override
  String get usersAndRoles => 'Users & roles';

  @override
  String get permissions => 'Permissions';

  @override
  String get companySettings => 'Company settings';

  @override
  String get teamSignIn => 'Team sign in';

  @override
  String get signInDescription =>
      'Sign in to manage your tailoring and rentals.';

  @override
  String get signInRequired => 'Required';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get current => 'Current';

  @override
  String get madeToFit => 'Made to fit.\nReady to wear.';

  @override
  String get tailoringAndRentals => 'Tailoring & occasionwear rentals';

  @override
  String get simplerRental => 'A considered fit. A simpler rental.';

  @override
  String get appId => 'App ID';

  @override
  String get financialYear => 'Financial year';

  @override
  String get userName => 'User name';

  @override
  String get password => 'Password';

  @override
  String get loadFinancialYears => 'Load financial years';

  @override
  String get signIn => 'SIGN IN';

  @override
  String get assistant => 'Assistant';

  @override
  String get askByTypingOrSpeak => 'Ask by typing or tap the microphone.';

  @override
  String get typeRequest => 'Type a request or search';

  @override
  String get speakRequest => 'Speak a request';

  @override
  String get stopListening => 'Stop listening';

  @override
  String get sendRequest => 'Send request';

  @override
  String get openItemMaster => 'Open Item Master';

  @override
  String get openNewOrder => 'Open new order form';

  @override
  String get openRentalBooking => 'Open rental booking';

  @override
  String get howCanIHelp => 'How can I help?';

  @override
  String get assistantWelcome =>
      'Search customers, orders, bookings, and items—or jump into a new form.';

  @override
  String get suggestCreateItem => 'Create a new item';

  @override
  String get suggestCreateTailoring => 'Create a tailoring order';

  @override
  String get suggestRental => 'Start a rental booking';

  @override
  String get suggestHelp => 'What can you do?';

  @override
  String get speechUnavailable =>
      'Speech recognition is unavailable. You can still type a request.';

  @override
  String couldNotStartSpeech(Object error) {
    return 'Could not start voice input: $error';
  }

  @override
  String voiceSearchLanguageUnavailable(Object language) {
    return 'Speech recognition for $language is unavailable on this device. Check the phone\'s language packs or choose another language.';
  }

  @override
  String get helpText =>
      'Try “create a new item”, “create a tailoring order”, “start a rental booking”, “show my bookings”, or search by customer, mobile, item, or order number. I will open the relevant form for you.';

  @override
  String get createItemAction => 'I can open the new item form for you.';

  @override
  String get createTailoringAction =>
      'I can open a new tailoring order for you.';

  @override
  String get createRentalAction => 'I can open a rental booking for you.';

  @override
  String get createItemResponse =>
      'I can help create a new item. Open Item Master to enter and review its details.';

  @override
  String get createTailoringResponse =>
      'I can help start a tailoring order. The existing form will validate the details before saving.';

  @override
  String get createRentalResponse =>
      'I can help start a rental booking. The existing booking flow will check availability before saving.';

  @override
  String get rentalAccessDenied =>
      'Your account does not have access to rental bookings.';

  @override
  String get tailoringAccessDenied =>
      'Your account does not have access to tailoring orders.';

  @override
  String noSearchMatch(Object query) {
    return 'I could not find a match for “$query”. Try a customer name, mobile number, order number, booking, or item name.';
  }

  @override
  String searchMatchCount(int count, Object query) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# matches',
      one: '# match',
    );
    return 'Found $_temp0 for “$query”. Tap a result to open its section.';
  }

  @override
  String searchError(Object areas, Object error) {
    return 'I could not search $areas: $error';
  }

  @override
  String get noRecordsFound =>
      'I could not find a matching record. Try a customer name, mobile number, item, order number, or booking number.';
}
