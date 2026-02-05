import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Nueva función para manejar el toque de una notificación
  void _handleMessage(RemoteMessage? message, BuildContext context) {
    if (message == null || message.data['orderId'] == null) return;

    final orderId = message.data['orderId'];
    context.go('/order-status/$orderId');
  }

  Future<void> initNotifications(GlobalKey<NavigatorState> navigatorKey) async {
    // Solicitar permiso al usuario
    await _firebaseMessaging.requestPermission();

    // Inicializar notificaciones locales
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@drawable/ic_stat_name');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings);

    // Manejar mensajes en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            icon: '@drawable/ic_stat_name',
          ),
        ),
      );
    });
    
    // Manejar el toque de la notificación cuando la app está en segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (navigatorKey.currentContext != null) {
        _handleMessage(message, navigatorKey.currentContext!);
      }
    });

    // Manejar el toque de la notificación cuando la app está cerrada
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null && navigatorKey.currentContext != null) {
      _handleMessage(initialMessage, navigatorKey.currentContext!);
    }
  }

  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }
}
