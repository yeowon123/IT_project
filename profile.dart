import 'package:flutter/material.dart';
import 'choice.dart'; // ChoicePage (검색 아이콘에서 이동용)

class ProfileScreen extends StatelessWidget {
  final String email;
  final String season;
  final String situation;
  final String style;

  const ProfileScreen({
    super.key,
    required this.email,
    required this.season,
    required this.situation,
    required this.style,
  });

  Widget _profileInfo(String email) {
    return Column(
      children: [
        CircleAvatar(
          radius: 43,
          backgroundColor: Colors.grey[200],
          child: const Icon(Icons.person, size: 54, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        Text(
          email,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 170),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.lightBlue[50],
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          '$label | $value',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          '내 정보',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),

        // 검색 아이콘 → ChoicePage 이동
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChoicePage()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 42),
            _profileInfo(email),
            const SizedBox(height: 32),
            _infoRow('계절', season),
            _infoRow('상황', situation),
            _infoRow('스타일', style),
          ],
        ),
      ),
    );
  }
}
