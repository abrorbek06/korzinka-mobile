import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:korzinkab_mobile/l10n/app_localizations.dart';
import 'package:korzinkab_mobile/screens/profile_screen.dart';
import 'package:korzinkab_mobile/utils/app_keys.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/kanban_screen.dart';
import 'screens/orders_list_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service (Firebase Messaging + local notifications)
  try {
    await NotificationService.initialize();
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const OrdersKanbanApp());
}

class OrdersKanbanApp extends StatelessWidget {
  const OrdersKanbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..tryRestoreSession(),
        ),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          return MaterialApp(
            title: 'Orders Kanban',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            scaffoldMessengerKey: AppKeys.scaffoldMessengerKey,
            locale: localeProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('uz'),
              Locale('ru'),
            ],
            home: const _AppRoot(),
          );
        },
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _ordersInitialized = false;
  bool _notificationsInitialized = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.state) {
      case AuthState.initial:
      case AuthState.loading:
        return const _SplashScreen();

      case AuthState.unauthenticated:
        _ordersInitialized = false;
        _notificationsInitialized = false;
        return const LoginScreen();

      case AuthState.authenticated:
        final orders = context.read<OrdersProvider>();
        final notifications = context.read<NotificationsProvider>();
        // Provide the server auth token to the notification service so it can register the device
        try {
          NotificationService.instance.setAuthToken(auth.token);
        } catch (_) {}

        if (!_ordersInitialized || !_notificationsInitialized) {
          _ordersInitialized = true;
          _notificationsInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            orders.init(auth.token!);
            notifications.init(auth.token!);
          });
        }
        return const HomeScreen();
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    KanbanScreen(),
    OrdersListScreen(),
    // ItemsScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationsProvider>().unreadCount;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.onSurfaceMuted,
        selectedIconTheme: const IconThemeData(size: 26),
        unselectedIconTheme: const IconThemeData(size: 26),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(
              Icons.view_kanban_outlined,
              size: 26,
            ),
            label: AppLocalizations.of(context)!.kanban,
          ),
          BottomNavigationBarItem(
            icon: const Icon(
              Icons.list,
              size: 26,
            ),
            label: AppLocalizations.of(context)!.orders,
          ),
          BottomNavigationBarItem(
            icon: const Icon(
              Icons.notifications_none,
              size: 26,
            ),
            label: AppLocalizations.of(context)!.notifications,
          ),
          BottomNavigationBarItem(
            icon: const Icon(
              Icons.person_outline,
              size: 26,
            ),
            label: AppLocalizations.of(context)!.products,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon({
    required Color color,
    required int badgeCount,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: SvgPicture.asset(
              'assets/icons/bell.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.surface, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SvgPicture.asset(
                'assets/icons/splash.svg',
                width: 34,
                height: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'KANBAN',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
