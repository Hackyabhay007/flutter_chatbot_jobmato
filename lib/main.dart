import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/chat_service.dart';
import 'services/auth_service.dart';
import 'screens/chat_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProxyProvider<AuthService, ChatService>(
          create: (context) =>
              ChatService(Provider.of<AuthService>(context, listen: false)),
          update: (context, auth, previous) => previous ?? ChatService(auth),
        ),
      ],
      child: MaterialApp(
        title: 'JobMato Assistant',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
        routes: {
          '/chat': (context) => const ChatScreen(),
        },
      ),
    );
  }
}
