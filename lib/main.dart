import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'views/splash_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة الهايف قبل تشغيل التطبيق
  await Hive.initFlutter();

  // فتح صندوق المفضلة قبل تشغيل التطبيق لمنع ظهور خطأ Box not found
  await Hive.openBox('favorites');

  runApp(const BookiiApp());
}

class BookiiApp extends StatelessWidget {
  const BookiiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bookii',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF7F7FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const SplashView(),
    );
  }
}