import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:korzinkab_mobile/l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../models/order_model.dart';
import '../utils/l10n_extensions.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          l10n.profile,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          children: [
            _buildMinimalProfile(user),
            const SizedBox(height: 24),
            _buildSettingsGroup([
              _buildLanguageTile(l10n),
              _buildStatusMethodTile(l10n, settings),
              _buildVisibleStatusesTile(context, l10n, settings),
            ]),
            const SizedBox(height: 40),
            _buildLogoutButton(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalProfile(user) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            child: Text(
              user.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            user.role.displayName,
            style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
      ),
      child: Column(
        children: children
            .asMap()
            .entries
            .map((entry) {
              final isLast = entry.key == children.length - 1;
              return Column(
                children: [
                  entry.value,
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppTheme.border.withOpacity(0.5),
                    ),
                ],
              );
            })
            .toList(),
      ),
    );
  }

  Widget _buildLanguageTile(l10n) {
    final localeProvider = context.watch<LocaleProvider>();
    final currentLocale = localeProvider.locale ?? Localizations.localeOf(context);

    return ListTile(
      leading: const Icon(CupertinoIcons.globe, color: Colors.blueAccent),
      title: Text(
        l10n.language,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentLocale.languageCode == 'uz' ? l10n.uzbek : l10n.russian,
            style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 14),
          ),
          const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
        ],
      ),
      onTap: () => _showLanguagePicker(context, l10n),
    );
  }

  void _showLanguagePicker(BuildContext context, l10n) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(l10n.language),
        actions: [
          CupertinoActionSheetAction(
            child: Text(l10n.uzbek),
            onPressed: () {
              context.read<LocaleProvider>().setLocale(const Locale('uz'));
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(l10n.russian),
            onPressed: () {
              context.read<LocaleProvider>().setLocale(const Locale('ru'));
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  Widget _buildStatusMethodTile(l10n, SettingsProvider settings) {
    return ListTile(
      leading: const Icon(
        CupertinoIcons.arrow_2_squarepath,
        color: Colors.orangeAccent,
      ),
      title: Text(
        l10n.statusChangeMethod,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: CupertinoSwitch(
        value: settings.statusChangeViaDropdown,
        activeColor: AppTheme.primary,
        onChanged: settings.setStatusChangeViaDropdown,
      ),
      subtitle: Text(
        settings.statusChangeViaDropdown ? l10n.viaDropdown : l10n.viaSwipe,
        style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceMuted),
      ),
    );
  }

  Widget _buildVisibleStatusesTile(BuildContext context, l10n,
      SettingsProvider settings) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: const Icon(CupertinoIcons.eye, color: Colors.green),
        title: Text(
          l10n.visibleStatuses,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: OrderStatus.values.map((status) {
                final isVisible = settings.isStatusVisible(status);
                return FilterChip(
                  label: Text(
                    status.localizedName(context),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: isVisible,
                  onSelected: (val) {
                    settings.toggleStatusVisibility(status, val);
                  },
                  selectedColor: status.color.withOpacity(0.2),
                  checkmarkColor: status.color,
                  labelStyle: TextStyle(
                    color: isVisible ? status.color : AppTheme.onSurfaceMuted,
                  ),
                  backgroundColor: AppTheme.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(
                    color: isVisible ? status.color : AppTheme.border,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, l10n) {
    return TextButton(
      onPressed: () {
        context.read<AuthProvider>().logout();
        Navigator.pushReplacementNamed(context, '/login');
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.redAccent,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.logout),
          const SizedBox(width: 8),
          Text(
            l10n.logout,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
