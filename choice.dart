import 'package:flutter/material.dart';

class ChoicePage extends StatelessWidget {
  const ChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments =
        ModalRoute.of(context)!.settings.arguments as Map<String, String?>;

    final name = arguments['name'] ?? '';
    final gender = arguments['gender'] ?? '';
    final season = arguments['season'] ?? '';
    final situation = arguments['situation'] ?? '';
    final style = arguments['style'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              showMenu(
                context: context,
                position: const RelativeRect.fromLTRB(0, 80, 0, 0),
                items: [
                  const PopupMenuItem(child: Text('내 정보')),
                  const PopupMenuItem(child: Text('즐겨찾기')),
                  const PopupMenuItem(child: Text('검색')),
                ],
              );
            },
          ),
        ),
        centerTitle: true,
        title: Image.asset('assets/logo_3.png', width: 100),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              const Divider(thickness: 1.5, color: Color(0xFFE0E0E0)),
              const SizedBox(height: 20),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              buildInfoBox('성별', gender),
              const SizedBox(height: 12),
              buildInfoBox('계절', season),
              const SizedBox(height: 12),
              buildInfoBox('상황', situation),
              if (situation != '면접' && situation != '시험기간') ...[
                const SizedBox(height: 12),
                buildInfoBox('스타일', style ?? ''),
              ],
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // 나중에 검색 기능 등 추가 가능
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF63C6D1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Search',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildInfoBox(String label, String value) {
    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF2F2F2)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Colors.black),
            children: [
              TextSpan(
                text: '$label  |  ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
