import 'package:flutter/material.dart';
import 'package:korzinkab_mobile/l10n/app_localizations.dart';
import '../models/order_model.dart';

extension OrderStatusL10n on OrderStatus {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case OrderStatus.DRAFT:
        return l10n.statusDraft;
      case OrderStatus.CONFIRMED:
        return l10n.statusConfirmed;
      case OrderStatus.IN_COLLECTION:
        return l10n.statusInCollection;
      case OrderStatus.PARTIAL:
        return l10n.statusPartial;
      case OrderStatus.READY:
        return l10n.statusReady;
      case OrderStatus.OUT_FOR_DELIVERY:
        return l10n.statusOutForDelivery;
      case OrderStatus.COMPLETED:
        return l10n.statusCompleted;
      case OrderStatus.CANCELLED:
        return l10n.statusCancelled;
    }
  }
}

extension PaymentStatusL10n on PaymentStatus {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case PaymentStatus.PAID:
        return l10n.paymentPaid;
      case PaymentStatus.UNPAID:
        return l10n.paymentUnpaid;
    }
  }
}

extension PaymentTypeL10n on PaymentType {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case PaymentType.BANK:
        return l10n.paymentBank;
      case PaymentType.CASH:
        return l10n.paymentCash;
      case PaymentType.CARD:
        return l10n.paymentCard;
    }
  }
}
