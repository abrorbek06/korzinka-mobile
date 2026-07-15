// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get helloWorld => 'Salom Dunyo!';

  @override
  String get profile => 'Profile';

  @override
  String get language => 'Til';

  @override
  String get uzbek => 'O\'zbekcha';

  @override
  String get russian => 'Ruscha';

  @override
  String get kanban => 'Kanban';

  @override
  String get orders => 'Buyurtmalar';

  @override
  String get notifications => 'Bildirishnomalar';

  @override
  String get signIn => 'Kirish';

  @override
  String get loginSubtitle => 'Buyurtmalarni boshqarish paneliga kiring';

  @override
  String get username => 'Foydalanuvchi nomi';

  @override
  String get password => 'Parol';

  @override
  String get required => 'Majburiy';

  @override
  String get statusDraft => 'Yangi';

  @override
  String get statusConfirmed => 'Tasdiqlangan';

  @override
  String get statusInCollection => 'Yig\'ilmoqda';

  @override
  String get statusPartial => 'Qisman';

  @override
  String get statusReady => 'Tayyor';

  @override
  String get statusCompleted => 'Yakunlangan';

  @override
  String get statusCancelled => 'Bekor qilingan';

  @override
  String get statusChangeMethod => 'Status o\'zgartirish usuli';

  @override
  String get viaDropdown => 'Dropdown orqali';

  @override
  String get viaSwipe => 'Swipe/drag orqali';

  @override
  String get save => 'Saqlash';

  @override
  String get assignedToMe => 'Menga biriktirilgan';

  @override
  String get all => 'Barchasi';

  @override
  String get visibleStatuses => 'Ko‘rinadigan statuslar';

  @override
  String get searchNotAvailable => 'Qidiruv funktsiyasi hozircha mavjud emas.';

  @override
  String get ordersNotLoaded => 'Buyurtmalar yuklanmadi';

  @override
  String get refresh => 'Yangilash';

  @override
  String get logout => 'Chiqish';

  @override
  String get filters => 'Filtrlar';

  @override
  String get clear => 'Tozalash';

  @override
  String get orderStatus => 'Buyurtma holati';

  @override
  String get paymentStatus => 'Toʻlov holati';

  @override
  String get paymentType => 'Toʻlov turi';

  @override
  String get applyFilter => 'Filtrni qo\'llash';

  @override
  String get searchHint => 'Kod yoki mijozni qidirish...';

  @override
  String get noOrdersFound => 'Hech qanday buyurtma topilmadi.';

  @override
  String get paymentPaid => 'To\'langan';

  @override
  String get paymentUnpaid => 'To\'lanmagan';

  @override
  String get paymentBank => 'Bank';

  @override
  String get paymentCash => 'Naqd';

  @override
  String get paymentCard => 'Karta';

  @override
  String productCount(int count) {
    return '$count ta mahsulot';
  }

  @override
  String productsNeeded(int count) {
    return '$count ta mahsulot kerak';
  }

  @override
  String get customer => 'Mijoz';

  @override
  String get date => 'Sana';

  @override
  String get trolley => 'Arava';

  @override
  String get change => 'O\'zgartirish';

  @override
  String get products => 'Mahsulotlar';

  @override
  String get audit => 'Audit';

  @override
  String get changeStatus => 'Statusni o\'zgartirish';

  @override
  String get attachTrolley => 'Arava biriktirish';

  @override
  String get selectTrolley => 'Ushbu buyurtma uchun arava tanlang:';

  @override
  String get noTrolleysFound => 'Mavjud aravalar topilmadi';

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get needed => 'Kerak';

  @override
  String get units => 'dona';

  @override
  String get noHistory => 'Harakatlar tarixi yo\'q';

  @override
  String get orderActions => 'Buyurtma amallari';

  @override
  String get draftOrder => 'Qoralama buyurtma';

  @override
  String get noTransitions =>
      'Sizning rolingiz uchun bu bosqichda amallar mavjud emas.';

  @override
  String get selectStatus => 'Statusni tanlang';

  @override
  String get selectPicker => 'Picker ni tanlang *';

  @override
  String get trolleyId => 'Arava ID *';

  @override
  String get enterTrolleyId => 'Arava ID kiriting';

  @override
  String get allBackorderedAvailable =>
      'Barcha backordered mahsulotlar mavjud bo\'lishi kerak.';

  @override
  String quantityCount(Object count, Object unit) {
    return 'Miqdor: $count $unit';
  }

  @override
  String get availableProducts => 'MAVJUD MAHSULOTLAR';

  @override
  String moveToStatus(Object status) {
    return '$status holatiga o\'tkazish';
  }

  @override
  String get allProductsAvailable => 'Barcha mahsulotlar mavjud';

  @override
  String get someProductsMissing => 'Ba\'zi mahsulotlar yetishmayapti';

  @override
  String get orderWillBeCancelled => 'Buyurtma bekor qilinadi';

  @override
  String get inCollectionProcess => 'Yig\'ish jarayonida';

  @override
  String get orderConfirmed => 'Buyurtma tasdiqlangan';

  @override
  String get needToSelectPicker => 'Picker tanlash kerak';

  @override
  String get trolleyIdRequired => 'Arava ID kerak';

  @override
  String get missingQuantityRequired => 'Yetishmayotgan miqdor kerak';

  @override
  String get orderMustBePaid => 'Buyurtma TO\'LANGAN bo\'lishi kerak';

  @override
  String get sessionExpired =>
      'Sessiyangiz tugadi. Iltimos, qayta kirib keting.';

  @override
  String get internetUnavailable =>
      'Internet aloqasi mavjud emas. Iltimos, tarmoqni tekshirib qayta urinib ko\'ring.';

  @override
  String get requestTimeout =>
      'Serverga ulanish vaqti tugadi. Iltimos, birozdan keyin qayta urinib ko\'ring.';

  @override
  String get notFound => 'Ma\'lumot topilmadi.';

  @override
  String get quantityLockedWhilePaid =>
      'Buyurtma to\'langanligi sababli mahsulot sonini o\'zgartirib bo\'lmaydi. Avval to\'lovni bekor qiling.';

  @override
  String get cashCardCreatePaidRejected =>
      'Naqd yoki kartali buyurtma yaratishda oldindan to\'lov belgilanmaydi. Buyurtma tayyor holatga kelgach, to\'lovni belgilang.';

  @override
  String get markPaidRequired =>
      'Buyurtma yakunlanishidan oldin to\'lov tasdiqlanishi kerak.';

  @override
  String get readyReverseBlockedPaid =>
      'Bu buyurtma allaqachon to\'langanligi sababli qaytib kelish ishlovi bekor qilindi. Avval to\'lovni bekor qiling.';

  @override
  String get transitionNotAllowed =>
      'Bu holat o\'zgartirish mumkin emas. Iltimos, boshqa bosqichga o\'ting.';

  @override
  String get pickerRequired => 'Tanlov uchun picker tanlang.';

  @override
  String get backorderRequired =>
      'Qoldiq mahsulotlarni oldin to\'g\'ri belgilang.';

  @override
  String get contractRequired =>
      'Buyurtma uchun kamida bitta faol shartnoma bo\'lishi kerak.';

  @override
  String get alreadyExists => 'Bu ma\'lumot allaqachon mavjud.';

  @override
  String get forbidden => 'Ushbu amal uchun sizga ruxsat yo\'q.';

  @override
  String get invalidData => 'Ma\'lumot formati noto\'g\'ri.';

  @override
  String get unknownError =>
      'Xatolik yuz berdi. Iltimos, qayta urinib ko\'ring.';

  @override
  String get allBackorderedMustArrive =>
      'Barcha backordered mahsulotlar yetishi kerak';

  @override
  String get markAsPaid => 'To\'langan deb belgilash';

  @override
  String get unmarkPaid => 'To\'lovni bekor qilish';

  @override
  String get statusOutForDelivery => 'Yo\'lda';

  @override
  String get picker => 'Yig\'uvchi';

  @override
  String get assigedNewOrder => 'Sizga biriktirilgan yangi buyurtma mavjud';

  @override
  String performPartialError(Object role, Object status) {
    return 'Rol $role qisman → $status ni bajara olmaydi';
  }
}
