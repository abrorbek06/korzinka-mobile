// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get helloWorld => 'Привет мир!';

  @override
  String get profile => 'Профиль';

  @override
  String get language => 'Язык';

  @override
  String get uzbek => 'Узбекский';

  @override
  String get russian => 'Русский';

  @override
  String get kanban => 'Канбан';

  @override
  String get orders => 'Заказы';

  @override
  String get notifications => 'Уведомления';

  @override
  String get signIn => 'Войти';

  @override
  String get loginSubtitle => 'Доступ к панели управления заказами';

  @override
  String get username => 'Имя пользователя';

  @override
  String get password => 'Пароль';

  @override
  String get required => 'Обязательно';

  @override
  String get statusDraft => 'Черновик';

  @override
  String get statusConfirmed => 'Подтвержден';

  @override
  String get statusInCollection => 'В сборке';

  @override
  String get statusPartial => 'Частично';

  @override
  String get statusReady => 'Готов';

  @override
  String get statusCompleted => 'Завершен';

  @override
  String get statusCancelled => 'Отменен';

  @override
  String get statusChangeMethod => 'Способ изменения статуса';

  @override
  String get viaDropdown => 'Через выпадающий список';

  @override
  String get viaSwipe => 'Через свайп/драг';

  @override
  String get save => 'Сохранить';

  @override
  String get assignedToMe => 'Назначено мне';

  @override
  String get all => 'Все';

  @override
  String get visibleStatuses => 'Видимые статусы';

  @override
  String get searchNotAvailable => 'Функция поиска пока недоступна.';

  @override
  String get ordersNotLoaded => 'Заказы не загружены';

  @override
  String get refresh => 'Обновить';

  @override
  String get logout => 'Выход';

  @override
  String get filters => 'Фильтры';

  @override
  String get clear => 'Очистить';

  @override
  String get orderStatus => 'Статус заказа';

  @override
  String get paymentStatus => 'Статус оплаты';

  @override
  String get paymentType => 'Тип оплаты';

  @override
  String get applyFilter => 'Применить фильтр';

  @override
  String get searchHint => 'Поиск кода или клиента...';

  @override
  String get noOrdersFound => 'Заказы не найдены.';

  @override
  String get paymentPaid => 'Оплачено';

  @override
  String get paymentUnpaid => 'Не оплачено';

  @override
  String get paymentBank => 'Банк';

  @override
  String get paymentCash => 'Наличные';

  @override
  String get paymentCard => 'Карта';

  @override
  String productCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товаров',
      one: '1 товар',
    );
    return '$_temp0';
  }

  @override
  String productsNeeded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'нужно $count товаров',
      one: 'нужен 1 товар',
    );
    return '$_temp0';
  }

  @override
  String get customer => 'Клиент';

  @override
  String get date => 'Дата';

  @override
  String get trolley => 'Тележка';

  @override
  String get change => 'Изменить';

  @override
  String get products => 'Товары';

  @override
  String get audit => 'Аудит';

  @override
  String get changeStatus => 'Изменить статус';

  @override
  String get attachTrolley => 'Прикрепить тележку';

  @override
  String get selectTrolley => 'Выберите тележку для этого заказа:';

  @override
  String get noTrolleysFound => 'Доступные тележки не найдены';

  @override
  String get cancel => 'Отмена';

  @override
  String get needed => 'Нужно';

  @override
  String get units => 'шт.';

  @override
  String get noHistory => 'История действий отсутствует';

  @override
  String get orderActions => 'Действия с заказом';

  @override
  String get draftOrder => 'Черновик заказа';

  @override
  String get noTransitions =>
      'Для вашей роли на этом этапе действия недоступны.';

  @override
  String get selectStatus => 'Выберите статус';

  @override
  String get selectPicker => 'Выберите сборщика *';

  @override
  String get trolleyId => 'ID тележки *';

  @override
  String get enterTrolleyId => 'Введите ID тележки';

  @override
  String get allBackorderedAvailable =>
      'Все товары в дозаказе должны быть в наличии.';

  @override
  String quantityCount(Object count, Object unit) {
    return 'Количество: $count $unit';
  }

  @override
  String get availableProducts => 'ТОВАРЫ В НАЛИЧИИ';

  @override
  String moveToStatus(Object status) {
    return 'Перейти в статус $status';
  }

  @override
  String get allProductsAvailable => 'Все товары в наличии';

  @override
  String get someProductsMissing => 'Некоторые товары отсутствуют';

  @override
  String get orderWillBeCancelled => 'Заказ будет отменен';

  @override
  String get inCollectionProcess => 'В процессе сборки';

  @override
  String get orderConfirmed => 'Заказ подтвержден';

  @override
  String get needToSelectPicker => 'Нужно выбрать сборщика';

  @override
  String get trolleyIdRequired => 'Требуется ID тележки';

  @override
  String get missingQuantityRequired => 'Требуется количество отсутствующих';

  @override
  String get orderMustBePaid => 'Заказ должен быть ОПЛАЧЕН';

  @override
  String get allBackorderedMustArrive =>
      'Все товары в дозаказе должны поступить';

  @override
  String get markAsPaid => 'Отметить как оплачено';

  @override
  String get unmarkPaid => 'Снять отметку об оплате';
}
