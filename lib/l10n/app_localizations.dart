import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('ru'),
    Locale('uz'),
  ];

  /// The conventional newborn programmer greeting
  ///
  /// In uz, this message translates to:
  /// **'Salom Dunyo!'**
  String get helloWorld;

  /// No description provided for @profile.
  ///
  /// In uz, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @language.
  ///
  /// In uz, this message translates to:
  /// **'Til'**
  String get language;

  /// No description provided for @uzbek.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbekcha'**
  String get uzbek;

  /// No description provided for @russian.
  ///
  /// In uz, this message translates to:
  /// **'Ruscha'**
  String get russian;

  /// No description provided for @kanban.
  ///
  /// In uz, this message translates to:
  /// **'Kanban'**
  String get kanban;

  /// No description provided for @orders.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalar'**
  String get orders;

  /// No description provided for @notifications.
  ///
  /// In uz, this message translates to:
  /// **'Bildirishnomalar'**
  String get notifications;

  /// No description provided for @signIn.
  ///
  /// In uz, this message translates to:
  /// **'Kirish'**
  String get signIn;

  /// No description provided for @loginSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalarni boshqarish paneliga kiring'**
  String get loginSubtitle;

  /// No description provided for @username.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanuvchi nomi'**
  String get username;

  /// No description provided for @password.
  ///
  /// In uz, this message translates to:
  /// **'Parol'**
  String get password;

  /// No description provided for @required.
  ///
  /// In uz, this message translates to:
  /// **'Majburiy'**
  String get required;

  /// No description provided for @statusDraft.
  ///
  /// In uz, this message translates to:
  /// **'Yangi'**
  String get statusDraft;

  /// No description provided for @statusConfirmed.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlangan'**
  String get statusConfirmed;

  /// No description provided for @statusInCollection.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ilmoqda'**
  String get statusInCollection;

  /// No description provided for @statusPartial.
  ///
  /// In uz, this message translates to:
  /// **'Qisman'**
  String get statusPartial;

  /// No description provided for @statusReady.
  ///
  /// In uz, this message translates to:
  /// **'Tayyor'**
  String get statusReady;

  /// No description provided for @statusCompleted.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlangan'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilingan'**
  String get statusCancelled;

  /// No description provided for @statusChangeMethod.
  ///
  /// In uz, this message translates to:
  /// **'Status o\'zgartirish usuli'**
  String get statusChangeMethod;

  /// No description provided for @viaDropdown.
  ///
  /// In uz, this message translates to:
  /// **'Dropdown orqali'**
  String get viaDropdown;

  /// No description provided for @viaSwipe.
  ///
  /// In uz, this message translates to:
  /// **'Swipe/drag orqali'**
  String get viaSwipe;

  /// No description provided for @save.
  ///
  /// In uz, this message translates to:
  /// **'Saqlash'**
  String get save;

  /// No description provided for @assignedToMe.
  ///
  /// In uz, this message translates to:
  /// **'Menga biriktirilgan'**
  String get assignedToMe;

  /// No description provided for @all.
  ///
  /// In uz, this message translates to:
  /// **'Barchasi'**
  String get all;

  /// No description provided for @visibleStatuses.
  ///
  /// In uz, this message translates to:
  /// **'Ko‘rinadigan statuslar'**
  String get visibleStatuses;

  /// No description provided for @searchNotAvailable.
  ///
  /// In uz, this message translates to:
  /// **'Qidiruv funktsiyasi hozircha mavjud emas.'**
  String get searchNotAvailable;

  /// No description provided for @ordersNotLoaded.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalar yuklanmadi'**
  String get ordersNotLoaded;

  /// No description provided for @refresh.
  ///
  /// In uz, this message translates to:
  /// **'Yangilash'**
  String get refresh;

  /// No description provided for @logout.
  ///
  /// In uz, this message translates to:
  /// **'Chiqish'**
  String get logout;

  /// No description provided for @filters.
  ///
  /// In uz, this message translates to:
  /// **'Filtrlar'**
  String get filters;

  /// No description provided for @clear.
  ///
  /// In uz, this message translates to:
  /// **'Tozalash'**
  String get clear;

  /// No description provided for @orderStatus.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma holati'**
  String get orderStatus;

  /// No description provided for @paymentStatus.
  ///
  /// In uz, this message translates to:
  /// **'Toʻlov holati'**
  String get paymentStatus;

  /// No description provided for @paymentType.
  ///
  /// In uz, this message translates to:
  /// **'Toʻlov turi'**
  String get paymentType;

  /// No description provided for @applyFilter.
  ///
  /// In uz, this message translates to:
  /// **'Filtrni qo\'llash'**
  String get applyFilter;

  /// No description provided for @searchHint.
  ///
  /// In uz, this message translates to:
  /// **'Kod yoki mijozni qidirish...'**
  String get searchHint;

  /// No description provided for @noOrdersFound.
  ///
  /// In uz, this message translates to:
  /// **'Hech qanday buyurtma topilmadi.'**
  String get noOrdersFound;

  /// No description provided for @paymentPaid.
  ///
  /// In uz, this message translates to:
  /// **'To\'langan'**
  String get paymentPaid;

  /// No description provided for @paymentUnpaid.
  ///
  /// In uz, this message translates to:
  /// **'To\'lanmagan'**
  String get paymentUnpaid;

  /// No description provided for @paymentBank.
  ///
  /// In uz, this message translates to:
  /// **'Bank'**
  String get paymentBank;

  /// No description provided for @paymentCash.
  ///
  /// In uz, this message translates to:
  /// **'Naqd'**
  String get paymentCash;

  /// No description provided for @paymentCard.
  ///
  /// In uz, this message translates to:
  /// **'Karta'**
  String get paymentCard;

  /// No description provided for @productCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta mahsulot'**
  String productCount(int count);

  /// No description provided for @productsNeeded.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta mahsulot kerak'**
  String productsNeeded(int count);

  /// No description provided for @customer.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz'**
  String get customer;

  /// No description provided for @date.
  ///
  /// In uz, this message translates to:
  /// **'Sana'**
  String get date;

  /// No description provided for @trolley.
  ///
  /// In uz, this message translates to:
  /// **'Arava'**
  String get trolley;

  /// No description provided for @change.
  ///
  /// In uz, this message translates to:
  /// **'O\'zgartirish'**
  String get change;

  /// No description provided for @products.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar'**
  String get products;

  /// No description provided for @audit.
  ///
  /// In uz, this message translates to:
  /// **'Audit'**
  String get audit;

  /// No description provided for @changeStatus.
  ///
  /// In uz, this message translates to:
  /// **'Statusni o\'zgartirish'**
  String get changeStatus;

  /// No description provided for @attachTrolley.
  ///
  /// In uz, this message translates to:
  /// **'Arava biriktirish'**
  String get attachTrolley;

  /// No description provided for @selectTrolley.
  ///
  /// In uz, this message translates to:
  /// **'Ushbu buyurtma uchun arava tanlang:'**
  String get selectTrolley;

  /// No description provided for @noTrolleysFound.
  ///
  /// In uz, this message translates to:
  /// **'Mavjud aravalar topilmadi'**
  String get noTrolleysFound;

  /// No description provided for @cancel.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get cancel;

  /// No description provided for @needed.
  ///
  /// In uz, this message translates to:
  /// **'Kerak'**
  String get needed;

  /// No description provided for @units.
  ///
  /// In uz, this message translates to:
  /// **'dona'**
  String get units;

  /// No description provided for @noHistory.
  ///
  /// In uz, this message translates to:
  /// **'Harakatlar tarixi yo\'q'**
  String get noHistory;

  /// No description provided for @orderActions.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma amallari'**
  String get orderActions;

  /// No description provided for @draftOrder.
  ///
  /// In uz, this message translates to:
  /// **'Qoralama buyurtma'**
  String get draftOrder;

  /// No description provided for @noTransitions.
  ///
  /// In uz, this message translates to:
  /// **'Sizning rolingiz uchun bu bosqichda amallar mavjud emas.'**
  String get noTransitions;

  /// No description provided for @selectStatus.
  ///
  /// In uz, this message translates to:
  /// **'Statusni tanlang'**
  String get selectStatus;

  /// No description provided for @selectPicker.
  ///
  /// In uz, this message translates to:
  /// **'Picker ni tanlang *'**
  String get selectPicker;

  /// No description provided for @trolleyId.
  ///
  /// In uz, this message translates to:
  /// **'Arava ID *'**
  String get trolleyId;

  /// No description provided for @enterTrolleyId.
  ///
  /// In uz, this message translates to:
  /// **'Arava ID kiriting'**
  String get enterTrolleyId;

  /// No description provided for @allBackorderedAvailable.
  ///
  /// In uz, this message translates to:
  /// **'Barcha backordered mahsulotlar mavjud bo\'lishi kerak.'**
  String get allBackorderedAvailable;

  /// No description provided for @quantityCount.
  ///
  /// In uz, this message translates to:
  /// **'Miqdor: {count} {unit}'**
  String quantityCount(Object count, Object unit);

  /// No description provided for @availableProducts.
  ///
  /// In uz, this message translates to:
  /// **'MAVJUD MAHSULOTLAR'**
  String get availableProducts;

  /// No description provided for @moveToStatus.
  ///
  /// In uz, this message translates to:
  /// **'{status} holatiga o\'tkazish'**
  String moveToStatus(Object status);

  /// No description provided for @allProductsAvailable.
  ///
  /// In uz, this message translates to:
  /// **'Barcha mahsulotlar mavjud'**
  String get allProductsAvailable;

  /// No description provided for @someProductsMissing.
  ///
  /// In uz, this message translates to:
  /// **'Ba\'zi mahsulotlar yetishmayapti'**
  String get someProductsMissing;

  /// No description provided for @orderWillBeCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma bekor qilinadi'**
  String get orderWillBeCancelled;

  /// No description provided for @inCollectionProcess.
  ///
  /// In uz, this message translates to:
  /// **'Yig\'ish jarayonida'**
  String get inCollectionProcess;

  /// No description provided for @orderConfirmed.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma tasdiqlangan'**
  String get orderConfirmed;

  /// No description provided for @needToSelectPicker.
  ///
  /// In uz, this message translates to:
  /// **'Picker tanlash kerak'**
  String get needToSelectPicker;

  /// No description provided for @trolleyIdRequired.
  ///
  /// In uz, this message translates to:
  /// **'Arava ID kerak'**
  String get trolleyIdRequired;

  /// No description provided for @missingQuantityRequired.
  ///
  /// In uz, this message translates to:
  /// **'Yetishmayotgan miqdor kerak'**
  String get missingQuantityRequired;

  /// No description provided for @orderMustBePaid.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma TO\'LANGAN bo\'lishi kerak'**
  String get orderMustBePaid;

  /// No description provided for @allBackorderedMustArrive.
  ///
  /// In uz, this message translates to:
  /// **'Barcha backordered mahsulotlar yetishi kerak'**
  String get allBackorderedMustArrive;

  /// No description provided for @markAsPaid.
  ///
  /// In uz, this message translates to:
  /// **'To\'langan deb belgilash'**
  String get markAsPaid;

  /// No description provided for @unmarkPaid.
  ///
  /// In uz, this message translates to:
  /// **'To\'lovni bekor qilish'**
  String get unmarkPaid;

  /// No description provided for @statusOutForDelivery.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'lda'**
  String get statusOutForDelivery;
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
      <String>['ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
