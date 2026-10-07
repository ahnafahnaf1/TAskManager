import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard_screen.dart';
import 'services/db_service.dart';
import 'services/notification_service.dart';

void main() async {
  // Ensure Flutter engine bindings are initialized before async services
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation and status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF171717),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF171717),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Local Notifications & Timezones
  await NotificationService.instance.initialize();

  // Initialize SQLite Database
  await DBService.instance.database;

  runApp(const TaskSchedulerApp());
}

class TaskSchedulerApp extends StatelessWidget {
  const TaskSchedulerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const emeraldGreen = Color(0xFF10B981); // Emerald Green Accent
    const darkBarColor = Color(0xFF171717); // #171717 Top & Footer Bar

    return MaterialApp(
      title: 'Task Scheduler',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white, // White body as requested
        colorScheme: ColorScheme.light(
          primary: emeraldGreen,
          secondary: emeraldGreen,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSurface: const Color(0xFF0F172A),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: darkBarColor, // #171717 Top Bar
          foregroundColor: Colors.white,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 54, // Minimized sleek footer height
          backgroundColor: darkBarColor, // #171717 Footer Bar
          indicatorColor: emeraldGreen.withValues(alpha: 0.22),
          elevation: 8,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: emeraldGreen, // Emerald green for active label
                fontSize: 11,
                fontWeight: FontWeight.bold,
              );
            }
            return const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: emeraldGreen, // Emerald green for active navigation icon
                size: 22,
              );
            }
            return const IconThemeData(
              color: Colors.white70,
              size: 22,
            );
          }),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: emeraldGreen,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
