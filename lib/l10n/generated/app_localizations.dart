import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_pa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('pa'),
  ];

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get hindi;

  /// No description provided for @punjabi.
  ///
  /// In en, this message translates to:
  /// **'ਪੰਜਾਬੀ'**
  String get punjabi;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @tailor.
  ///
  /// In en, this message translates to:
  /// **'Tailor'**
  String get tailor;

  /// No description provided for @rental.
  ///
  /// In en, this message translates to:
  /// **'Rental'**
  String get rental;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @ava.
  ///
  /// In en, this message translates to:
  /// **'Ava'**
  String get ava;

  /// No description provided for @heyAvaListening.
  ///
  /// In en, this message translates to:
  /// **'Listening for “Hey Ava”'**
  String get heyAvaListening;

  /// No description provided for @openAva.
  ///
  /// In en, this message translates to:
  /// **'Open Ava voice assistant'**
  String get openAva;

  /// No description provided for @assistantName.
  ///
  /// In en, this message translates to:
  /// **'Ava'**
  String get assistantName;

  /// No description provided for @businessOverview.
  ///
  /// In en, this message translates to:
  /// **'Business overview'**
  String get businessOverview;

  /// No description provided for @tailoringActivity.
  ///
  /// In en, this message translates to:
  /// **'Your tailoring activity at a glance'**
  String get tailoringActivity;

  /// No description provided for @ordersByType.
  ///
  /// In en, this message translates to:
  /// **'Orders by type'**
  String get ordersByType;

  /// No description provided for @tailoringWorkflow.
  ///
  /// In en, this message translates to:
  /// **'Tailoring workflow'**
  String get tailoringWorkflow;

  /// No description provided for @rentalWorkflow.
  ///
  /// In en, this message translates to:
  /// **'Rental workflow'**
  String get rentalWorkflow;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @recentPayments.
  ///
  /// In en, this message translates to:
  /// **'Recent payments'**
  String get recentPayments;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @masters.
  ///
  /// In en, this message translates to:
  /// **'Masters'**
  String get masters;

  /// No description provided for @administration.
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get administration;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @usersAndRoles.
  ///
  /// In en, this message translates to:
  /// **'Users & roles'**
  String get usersAndRoles;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @companySettings.
  ///
  /// In en, this message translates to:
  /// **'Company settings'**
  String get companySettings;

  /// No description provided for @teamSignIn.
  ///
  /// In en, this message translates to:
  /// **'Team sign in'**
  String get teamSignIn;

  /// No description provided for @signInDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your tailoring and rentals.'**
  String get signInDescription;

  /// No description provided for @signInRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get signInRequired;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

  /// No description provided for @madeToFit.
  ///
  /// In en, this message translates to:
  /// **'Made to fit.\nReady to wear.'**
  String get madeToFit;

  /// No description provided for @tailoringAndRentals.
  ///
  /// In en, this message translates to:
  /// **'Tailoring & occasionwear rentals'**
  String get tailoringAndRentals;

  /// No description provided for @simplerRental.
  ///
  /// In en, this message translates to:
  /// **'A considered fit. A simpler rental.'**
  String get simplerRental;

  /// No description provided for @appId.
  ///
  /// In en, this message translates to:
  /// **'App ID'**
  String get appId;

  /// No description provided for @financialYear.
  ///
  /// In en, this message translates to:
  /// **'Financial year'**
  String get financialYear;

  /// No description provided for @userName.
  ///
  /// In en, this message translates to:
  /// **'User name'**
  String get userName;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @loadFinancialYears.
  ///
  /// In en, this message translates to:
  /// **'Load financial years'**
  String get loadFinancialYears;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get signIn;

  /// No description provided for @assistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistant;

  /// No description provided for @askByTypingOrSpeak.
  ///
  /// In en, this message translates to:
  /// **'Ask by typing or tap the microphone.'**
  String get askByTypingOrSpeak;

  /// No description provided for @typeRequest.
  ///
  /// In en, this message translates to:
  /// **'Type a request or search'**
  String get typeRequest;

  /// No description provided for @speakRequest.
  ///
  /// In en, this message translates to:
  /// **'Speak a request'**
  String get speakRequest;

  /// No description provided for @stopListening.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get stopListening;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get sendRequest;

  /// No description provided for @openItemMaster.
  ///
  /// In en, this message translates to:
  /// **'Open Item Master'**
  String get openItemMaster;

  /// No description provided for @openNewOrder.
  ///
  /// In en, this message translates to:
  /// **'Open new order form'**
  String get openNewOrder;

  /// No description provided for @openRentalBooking.
  ///
  /// In en, this message translates to:
  /// **'Open rental booking'**
  String get openRentalBooking;

  /// No description provided for @howCanIHelp.
  ///
  /// In en, this message translates to:
  /// **'How can I help?'**
  String get howCanIHelp;

  /// No description provided for @assistantWelcome.
  ///
  /// In en, this message translates to:
  /// **'Search customers, orders, bookings, and items—or jump into a new form.'**
  String get assistantWelcome;

  /// No description provided for @suggestCreateItem.
  ///
  /// In en, this message translates to:
  /// **'Create a new item'**
  String get suggestCreateItem;

  /// No description provided for @suggestCreateTailoring.
  ///
  /// In en, this message translates to:
  /// **'Create a tailoring order'**
  String get suggestCreateTailoring;

  /// No description provided for @suggestRental.
  ///
  /// In en, this message translates to:
  /// **'Start a rental booking'**
  String get suggestRental;

  /// No description provided for @suggestHelp.
  ///
  /// In en, this message translates to:
  /// **'What can you do?'**
  String get suggestHelp;

  /// No description provided for @speechUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is unavailable. You can still type a request.'**
  String get speechUnavailable;

  /// No description provided for @couldNotStartSpeech.
  ///
  /// In en, this message translates to:
  /// **'Could not start voice input: {error}'**
  String couldNotStartSpeech(Object error);

  /// No description provided for @voiceSearchLanguageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition for {language} is unavailable on this device. Check the phone\'s language packs or choose another language.'**
  String voiceSearchLanguageUnavailable(Object language);

  /// No description provided for @helpText.
  ///
  /// In en, this message translates to:
  /// **'Try “create a new item”, “create a tailoring order”, “start a rental booking”, “show my bookings”, or search by customer, mobile, item, or order number. I will open the relevant form for you.'**
  String get helpText;

  /// No description provided for @createItemAction.
  ///
  /// In en, this message translates to:
  /// **'I can open the new item form for you.'**
  String get createItemAction;

  /// No description provided for @createTailoringAction.
  ///
  /// In en, this message translates to:
  /// **'I can open a new tailoring order for you.'**
  String get createTailoringAction;

  /// No description provided for @createRentalAction.
  ///
  /// In en, this message translates to:
  /// **'I can open a rental booking for you.'**
  String get createRentalAction;

  /// No description provided for @createItemResponse.
  ///
  /// In en, this message translates to:
  /// **'I can help create a new item. Open Item Master to enter and review its details.'**
  String get createItemResponse;

  /// No description provided for @createTailoringResponse.
  ///
  /// In en, this message translates to:
  /// **'I can help start a tailoring order. The existing form will validate the details before saving.'**
  String get createTailoringResponse;

  /// No description provided for @createRentalResponse.
  ///
  /// In en, this message translates to:
  /// **'I can help start a rental booking. The existing booking flow will check availability before saving.'**
  String get createRentalResponse;

  /// No description provided for @rentalAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Your account does not have access to rental bookings.'**
  String get rentalAccessDenied;

  /// No description provided for @tailoringAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Your account does not have access to tailoring orders.'**
  String get tailoringAccessDenied;

  /// No description provided for @noSearchMatch.
  ///
  /// In en, this message translates to:
  /// **'I could not find a match for “{query}”. Try a customer name, mobile number, order number, booking, or item name.'**
  String noSearchMatch(Object query);

  /// No description provided for @searchMatchCount.
  ///
  /// In en, this message translates to:
  /// **'Found {count, plural, one{# match} other{# matches}} for “{query}”. Tap a result to open its section.'**
  String searchMatchCount(int count, Object query);

  /// No description provided for @searchError.
  ///
  /// In en, this message translates to:
  /// **'I could not search {areas}: {error}'**
  String searchError(Object areas, Object error);

  /// No description provided for @noRecordsFound.
  ///
  /// In en, this message translates to:
  /// **'I could not find a matching record. Try a customer name, mobile number, item, order number, or booking number.'**
  String get noRecordsFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'pa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'pa':
      return AppLocalizationsPa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
