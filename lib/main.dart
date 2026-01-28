import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'admin_panel_screen.dart';
import 'customer_management_screen.dart';
import 'expense_screen.dart';
import 'firebase_options.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4A148C);
    const Color accentColor = Color(0xFFFFD700);
    const Color backgroundColor = Color(0xFF121212);

    final TextTheme saturnoTextTheme = Theme.of(context).textTheme.apply(
          fontFamily: 'LemonMilk',
          bodyColor: Colors.white,
          displayColor: Colors.white,
        );

    return MaterialApp(
      title: 'Saturno TPV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'LemonMilk',
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
          primary: primaryColor,
          secondary: accentColor,
          background: backgroundColor,
          surface: const Color(0xFF1E1E1E),
        ),
        textTheme: saturnoTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          titleTextStyle: saturnoTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF2C2C2C),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accentColor,
          foregroundColor: Colors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF2C2C2C),
          titleTextStyle: saturnoTextTheme.titleLarge,
          contentTextStyle: saturnoTextTheme.bodyMedium,
        ),
      ),
      home: const AuthGate(),
      routes: {
        '/expenses': (context) => const ExpenseScreen(),
        '/customers': (context) => const CustomerManagementScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // Si el usuario está autenticado, lo llevamos al Panel de Administración.
          return const AdminPanelScreen();
        }

        // Si no, a la pantalla de Login.
        return const LoginScreen();
      },
    );
  }
}
