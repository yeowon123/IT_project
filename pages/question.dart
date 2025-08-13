// lib/pages/question_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/user_handle.dart';

class QuestionPage extends StatefulWidget {
  const QuestionPage({super.key});

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  String? selectedSeason;
  String? selectedSituation;
  String userName = '사용자';
  bool _loadingPrefill = false;
  bool _saving = false;

  final List<String> seasons = ['봄', '여름', '가을', '겨울'];
  final List<String> situations = [
    '시험기간',
    '면접',
    '미팅',
    '데이트',
    '축제',
    'MT',
    'OT',
    '개총',
    '새터',
    '개강',
    '졸업',
    '입학',
  ];

  @override
  void initState() {
    super.initState();
    _prefillFromFirestore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      userName = args['name'] ?? '사용자';
    }
  }

  Future<void> _prefillFromFirestore() async {
    setState(() => _loadingPrefill = true);
    try {
      final docRef = userDocRef(); // ✅ 항상 handle 기반
      final snap = await docRef.get();
      final data = snap.data();
      if (data == null) return;

      setState(() {
        final s1 = data['season'] as String?;
        final s2 = data['situation'] as String?;
        if (s1 != null && seasons.contains(s1)) selectedSeason = s1;
        if (s2 != null && situations.contains(s2)) selectedSituation = s2;
      });
    } catch (_) {
      // 필요 시 스낵바 등 추가
    } finally {
      if (mounted) setState(() => _loadingPrefill = false);
    }
  }

  Future<void> _saveAndGoNext() async {
    if (selectedSeason == null || selectedSituation == null) return;

    setState(() => _saving = true);
    try {
      // ✅ users/{handle}에 병합 저장
      await userDocRef().set({
        'season': selectedSeason,
        'situation': selectedSituation,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final arguments = {
        'name': userName,
        'season': selectedSeason!,
        'situation': selectedSituation!,
      };

      if (selectedSituation == '면접' || selectedSituation == '시험기간') {
        arguments['style'] = '';
        if (!mounted) return;
        Navigator.pushNamed(context, '/choice', arguments: arguments);
      } else {
        if (!mounted) return;
        Navigator.pushNamed(context, '/style', arguments: arguments);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 중 오류가 발생했어요. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextEnabled =
        selectedSeason != null && selectedSituation != null && !_saving;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 100),
                  Center(child: Image.asset('assets/logo_2.png', width: 300)),
                  const SizedBox(height: 100),

                  // 계절
                  Opacity(
                    opacity: _loadingPrefill ? 0.5 : 1,
                    child: IgnorePointer(
                      ignoring: _loadingPrefill,
                      child: buildDropdown(
                        label: '계절',
                        value: selectedSeason,
                        items: seasons,
                        onChanged: (value) =>
                            setState(() => selectedSeason = value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),

                  // 상황
                  Opacity(
                    opacity: _loadingPrefill ? 0.5 : 1,
                    child: IgnorePointer(
                      ignoring: _loadingPrefill,
                      child: buildDropdown(
                        label: '상황',
                        value: selectedSituation,
                        items: situations,
                        onChanged: (value) =>
                            setState(() => selectedSituation = value),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Next 버튼
            Positioned(
              bottom: 24,
              right: 24,
              child: OutlinedButton(
                onPressed: nextEnabled ? _saveAndGoNext : null,
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: Color(0xFFB3B3B3)),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 6,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        alignment: Alignment.centerLeft,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
        value: value,
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 14)),
              ),
            )
            .toList(),
        onChanged: onChanged,
        icon: const Icon(Icons.expand_more),
      ),
    );
  }
}
