import 'package:flutter/foundation.dart';

class AppStrings {
  // Auth
  static const appName = 'Kanban';
  static const login = 'Kirish';
  static const username = 'Foydalanuvchi nomi';
  static const password = 'Parol';
  static const loginBtn = 'Kirish';
  static const loginError = 'Login yoki parol noto\'g\'ri';
  static const networkError = 'Internet aloqasi yo\'q';

  // Nav
  static const navKanban = 'Kanban';
  static const navOrders = 'Buyurtmalar';
  static const navItems = 'Mahsulotlar';
  static const navProfile = 'Profil';

  // Filters
  static const filterAll = 'Barchasi';
  static const filterMine = 'Menga biriktirilgan';

  // Statuses
  static const statusDraft = 'Yangi';
  static const statusConfirmed = 'Tasdiqlangan';
  static const statusInCollection = 'Yig\'ilmoqda';
  static const statusPartial = 'Qisman yetishmayapti';
  static const statusReady = 'Tayyor';
  static const statusOutForDelivery = 'Yetkazib berish';
  static const statusCompleted = 'Yakunlangan';
  static const statusCancelled = 'Bekor qilingan';

  // Order detail
  static const customer = 'Mijoz';
  static const date = 'Sana';
  static const trolley = 'Arava';
  static const change = 'O\'zgartirish';
  static const products = 'Mahsulotlar';
  static const comments = 'Izohlar';
  static const required = 'Kerak';
  static const unit = 'dona';
  static const kg = 'kg';
  static const changeStatus = 'Statusni o\'zgartirish';
  static const noProducts = 'Mahsulotlar topilmadi';
  static const noOrders = 'Buyurtmalar yo\'q';
  static const noItems = 'Mahsulotlar yo\'q';
  static const refresh = 'Yangilash';

  // Trolley
  static const selectTrolley = 'Arava tanlash';
  static const trolleyHint = 'Qaysi aravaga yig\'ayapsiz?';
  static const trolleyFree = 'Bo\'sh';
  static const trolleyBusy = 'Band';
  static const trolleyAssigned = 'Tayinlangan';
  static const confirm = 'Tasdiqlash';

  // Status change sheet
  static const moveTo = 'Statusni o\'zgartirish';
  static const readyTitle = 'Tayyor deb belgilash';
  static const readyConfirm = 'Barcha mahsulotlar yig\'ildimi?';
  static const yes = 'Ha, tayyor';
  static const cancel = 'Bekor';
  static const note = 'Izoh (ixtiyoriy)';
  static const notePlaceholder = 'Qo\'shimcha izoh yozing...';

  // Profile
  static const role = 'Rol';
  static const picker = 'Yig\'uvchi';
  static const logout = 'Chiqish';
  static const logoutConfirm = 'Chiqmoqchimisiz?';
  static const logoutYes = 'Ha, chiqish';
}

class AppConfig {
  static const String baseUrl = 'http://localhost:3000';
  static const String socketUrl = 'http://localhost:3000';
  static const String socketNamespace = '/socket';
  static const String tokenKey = 'picker_jwt_token';
  static const String userKey = 'picker_user_data';
  static const String trolleyKey = 'trolley_assignments';
  static const int trolleyCount = 50; // AR-01 ... AR-50


  static VoidCallback? onUnauthorized;

  static void logout() {
    if (onUnauthorized != null) {
      onUnauthorized!();
    }
  }

}
