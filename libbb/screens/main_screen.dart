import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/picker_provider.dart';
import '../theme/app_theme.dart';
import 'orders_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const OrdersScreen(),
    const _OrdersListPlaceholder(),
    const _ItemsScreen(),
    // const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [AppTheme.bottomBarShadow],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.view_kanban_outlined),
              activeIcon: Icon(Icons.view_kanban_rounded),
              label: AppStrings.navKanban,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: AppStrings.navOrders,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              activeIcon: Icon(Icons.list_rounded),
              label: AppStrings.navItems,
            ),
            // BottomNavigationBarItem(
            //   icon: Icon(Icons.person_outline_rounded),
            //   activeIcon: Icon(Icons.person_rounded),
            //   label: AppStrings.navProfile,
            // ),
          ],
        ),
      ),
    );
  }
}

// ─── Placeholder screens ──────────────────────────────────────────────────────

class _OrdersListPlaceholder extends StatelessWidget {
  const _OrdersListPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(AppStrings.navOrders),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            const Text(
              'Buyurtmalar ro\'yxati',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemsScreen extends StatelessWidget {
  const _ItemsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(AppStrings.navItems),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.list,
                  size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            const Text(
              AppStrings.noItems,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Profile Screen ───────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(AppStrings.navProfile),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),

          // Avatar + name
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 3),
                  ),
                  child: Center(
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    AppStrings.picker,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Info card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _ProfileRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Username',
                    value: user.username),
                const Divider(height: 20),
                _ProfileRow(
                    icon: Icons.badge_outlined,
                    label: AppStrings.role,
                    value: AppStrings.picker),
                const Divider(height: 20),
                _ProfileRow(
                    icon: Icons.circle,
                    iconColor: AppColors.yangiColor,
                    label: 'Holat',
                    value: 'Faol'),
              ],
            ),
          ),

          const Spacer(),

          // Logout
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, auth),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(AppStrings.logout),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.bekorColor,
                  side: BorderSide(color: AppColors.bekorColor.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(AppStrings.logoutConfirm,
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              auth.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.bekorColor),
            child: const Text(AppStrings.logoutYes),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;

  const _ProfileRow({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 16, color: iconColor ?? AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
          ),
        ),
      ],
    );
  }
}
