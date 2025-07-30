import 'package:flutter/material.dart';
import 'pages/style_page.dart';
import 'pages/choice_page.dart';
import 'pages/question_page.dart';

void main() {
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
      onGenerateRoute: (settings) {
        final args = settings.arguments;
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/question':
            return MaterialPageRoute(builder: (_) => const QuestionPage());
          case '/style':
            if (args is Map<String, String>) {
              return MaterialPageRoute(
                builder: (_) => StylePage(
                  name: args['name'] ?? '',
                  gender: args['gender'] ?? '',
                  season: args['season'] ?? '',
                  situation: args['situation'] ?? '',
                ),
              );
            }
            return _errorRoute('StylePage');
          case '/choice':
            if (args is Map<String, String?>) {
              return MaterialPageRoute(
                builder: (_) => const ChoicePage(),
                settings: RouteSettings(arguments: args),
              );
            }
            return _errorRoute('ChoicePage');
          default:
            return _errorRoute('Unknown');
        }
      },
    );
  }

  Route<dynamic> _errorRoute(String routeName) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(child: Text('Invalid arguments for $routeName')),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController idController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    idController.dispose();
    super.dispose();
  }

  void _onSignInPressed() {
    final name = nameController.text.trim();
    final id = idController.text.trim();

    if (name.isEmpty || id.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 항목을 입력해주세요')));
      return;
    }

    Navigator.pushNamed(context, '/question', arguments: {'name': name});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                const SizedBox(height: 60),
                Image.asset('assets/logo.png', width: 200, height: 200),
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFD9D9D9),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF999999),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: _buildInputDecoration('Enter your Name'),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ID',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF999999),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: idController,
                        decoration: _buildInputDecoration('Enter your ID'),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _onSignInPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF63C6D1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFD9D9D9)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
