import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/style_page.dart';
import 'pages/choice_page.dart';
import 'pages/question_page.dart';
import 'pages/recommendation_page.dart';
import 'pages/stylist_page.dart';
import 'pages/login_page.dart'; //  Firebase 로그인 페이지 import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fashion Recommender',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(), // 로그인 페이지 연결
        '/question': (context) => const QuestionPage(),
        '/choice': (context) => const ChoicePage(),
        '/recommendation': (context) => const RecommendationPage(),
        '/style': (context) =>
            const StylePage(name: '', season: '', situation: ''),
        '/stylist': (context) => const StylistPage(),
      },
    );
  }
}
