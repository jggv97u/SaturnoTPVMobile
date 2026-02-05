import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'active_orders_screen.dart';
import 'admin_panel_screen.dart';
import 'customer_create_profile_screen.dart';
import 'customer_login_screen.dart';
import 'customer_management_screen.dart';
import 'customer_profile_screen.dart';
import 'expense_screen.dart';
import 'firebase_options.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GoRouter _router = GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) async {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isPublicCustomerRoute = [
        '/customer-portal',
        '/customer-profile',
        '/create-profile'
      ].contains(state.matchedLocation);

      // Si el usuario no ha iniciado sesión, redirigir a /login a menos que ya esté allí
      // o en una ruta pública de cliente.
      if (!loggedIn) {
        return isLoggingIn || isPublicCustomerRoute ? null : '/login';
      }

      // El usuario ha iniciado sesión. Comprobar su rol.
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();
          
      final isAdmin = userDoc.exists && (userDoc.data()?['isAdmin'] ?? false);

      final isGoingToRoot = state.matchedLocation == '/';
      final isGoingToAdmin = state.matchedLocation == '/admin';

      // Si el usuario está autenticado y va a /login o a /, redirigir según su rol.
      if (isLoggingIn || isGoingToRoot) {
        return isAdmin ? '/admin' : '/pos';
      }

      // Si un no-admin intenta acceder a /admin, redirigirlo a /pos.
      if (!isAdmin && isGoingToAdmin) {
        return '/pos';
      }

      // En cualquier otro caso, no se necesita redirección.
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminPanelScreen(),
      ),
       GoRoute(
        path: '/pos',
        builder: (context, state) => const ActiveOrdersScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const ExpenseScreen(),
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const CustomerManagementScreen(),
      ),
      GoRoute(
        path: '/customer-portal',
        builder: (context, state) => const CustomerLoginScreen(),
      ),
      GoRoute(
          path: '/customer-profile',
          builder: (context, state) {
            final Map<String, dynamic>? extra =
                state.extra as Map<String, dynamic>?;
            return CustomerProfileScreen(initialData: extra);
          }),
      GoRoute(
        path: '/create-profile',
        builder: (context, state) => const CustomerCreateProfileScreen(),
      ),
    ],
  );

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

    return MaterialApp.router(
      routerConfig: _router,
      title: 'Saturno TPV',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'MX'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'MX'),
      ],
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
          titleTextStyle:
              saturnoTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
    );
  }
}
