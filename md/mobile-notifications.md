# Mobile ilovalar uchun push-notification qo'llanma

Bu hujjat serverdagi push va socket orqali yetkazib beriladigan mobil bildirishnomalar (push notifications)ni qanday ishlatish haqida qisqacha ko'rsatma beradi.

**Muhim:** Push yuborish uchun Firebase Cloud Messaging (FCM) xizmatidan foydalanish tavsiya etiladi — buning uchun `FIREBASE_SERVICE_ACCOUNT_JSON` (base64) yoki `FIREBASE_SERVICE_ACCOUNT_PATH` (mahalliy fayl) muhit o'zgaruvchilari bilan serverni sozlang. Agar sozlanmagan bo'lsa, server push yubormaydi, ammo logda nima yuborilardi deb yozadi.

**Server fayllari:**
- `src/notifications/notification-devices.controller.ts` — qurilmalarni ro'yxatga olish va o'chirish endpointlari
- `src/notifications/notification-devices.service.ts` — qurilmalar CRUD
- `src/notifications/push.service.ts` — FCM bilan yuborish (majburiy emas)
- `src/notifications/notifications.service.ts` — socket emit va DB yozuvlaridan keyin push chaqiradi

**Mühit o'zgaruvchilari (env):**
- `FIREBASE_SERVICE_ACCOUNT_JSON` — service account JSON faylini base64 formatida (afzal) yoki
- `FIREBASE_SERVICE_ACCOUNT_PATH` — service account JSON fayliga to'liq yo'l

Serverni ishga tushirish:

```bash
npm install
npm run build
npm run start:dev
```

Endpointlar (HTTP, JWT auth talab qiladi):

- POST `/notifications/devices` — qurilma tokenini ro'yxatga olish
  - Body: `{ "token": "<fcm-token>", "platform": "android" | "ios" }`
  - Javob: yaratilgan `NotificationDevice` obyekti

- GET `/notifications/devices` — hozirgi foydalanuvchining qurilmalari

- DELETE `/notifications/devices/:id` — qurilmani deaktivatsiya qilish (soft-delete)

Foydalanish (mobil tomondan):

1. Firebase SDK (Android / iOS) orqali FCM token oling.
   - Android (Firebase Messaging) yoki iOS (APNs bilan sozlangan) orqali tokenni oling.
2. Serverga JWT bilan autentifikatsiyalangan so'rov yuboring:

```bash
curl -X POST https://api.example.com/notifications/devices \
  -H "Authorization: Bearer <JWT>" \
  -H "Content-Type: application/json" \
  -d '{ "token": "<FCM_TOKEN>", "platform": "android" }'
```

3. Token yangilang yoki o'chirilganda (app uninstall / reinstall) tokenni yangilashni amalga oshiring — SDK `onNewToken`/`didRegisterForRemoteNotifications` hodisalarida POST qayta yuboring.

Serverdan keladigan socket xabarlari (websocket namespace `/socket`):

Server barcha xabarlarni umumiy envelope bilan yuboradi: `{ type, payload, sentAt }`.
`type = 'notification.created'` bo'lsa, payload quyidagi shaklda bo'ladi (NotificationSocketPayload):

```json
{
  "id": "<recipientId>",
  "notificationId": "<notificationId>",
  "type": "order.created",
  "entityType": "order",
  "entityId": "<orderId>",
  "title": "Order #...",
  "body": "Yangi buyurtma keldi",
  "data": { ... },
  "createdAt": "2026-05-25T...Z",
  "unreadCount": 3
}
```

Server logikasining muhim jihatlari:

- Bildirishnoma yuborilganda, server birinchi `Notification` va `NotificationRecipient` satrlarini yozadi (transaction ichida). Keyin tranzaksiya muvaffaqiyatli commit bo'lgandan so'ng:
  1) Socket orqali `notification.created` va `notifications.unread_count_changed` emit qilinadi,
  2) PushService (agar FCM sozlangan bo'lsa) orqali FCMga multicast yuboriladi.

Sinov uchun tez usullar:

1) Foydalanuvchi JWT bilan qurilmangizni ro'yxatga oling (yuqoridagi curl misoli).
2) Backendda test trigger: masalan, `POST /orders` yoki admin panel orqali `order.created` triggerini yaratish — bu normal API yo'llari orqali notification yozadi va push yuboradi. Agar sizda test util yoki script bo'lsa, uni ishlating.
3) Socketni kuzatib, yangi notification kelishini tekshiring (va FCM loglari: agar `FIREBASE_SERVICE_ACCOUNT_JSON` mavjud bo'lsa, FCM xat va natijalarini server logida ko'rasiz).

Curl misollari (JWT o'rniga haqiqiy token qo'ying):

```bash
# Register device
curl -X POST http://localhost:3000/notifications/devices \
  -H "Authorization: Bearer <JWT>" \
  -H "Content-Type: application/json" \
  -d '{"token":"abc123","platform":"android"}'

# Get unread count
curl -H "Authorization: Bearer <JWT>" http://localhost:3000/notifications/unread-count

# List notifications
curl -H "Authorization: Bearer <JWT>" http://localhost:3000/notifications
```

Qanday qilib noto'g'ri tokenlarni tozalash (tavsiyalar):

- FCM yuborish natijasida `response.responses` ichida `error` va `registration-token-not-registered` yoki `invalid-registration-token` kabi xatolar chiqsa, server bu tokenni `NotificationDevice.isActive = false` qilib belgilashi kerak. Hozirgi `PushService` loglash qiladi; kerak bo'lsa men avtomatik tozalashni qo'shishim mumkin.

Xavfsizlik va amaliyotlar:

- Har doim HTTPS orqali yuboring.
- Tokenlarni serverda shifrlangan holda emas, lekin imzo bilan tekshirib saqlash (DBda plain text tokenlar normale), ammo tokendan boshqa hech qanday maxfiy ma'lumot yubormang.
- Token rotation: har token yangilanganda `POST /notifications/devices` qayta chaqiring.

Qo'shimcha yordam kerakmi?
- Men server tomonda invalid-token cleanup (FCM javobiga qarab `isActive=false`) ni avtomatlashtirib qo'yishim mumkin.
- Yoki mobil tomonda SDK namunaviy kodlarini (Android / iOS) yozib beraymi?
