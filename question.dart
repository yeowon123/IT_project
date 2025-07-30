import 'package:flutter/material.dart';

class QuestionPage extends StatefulWidget {
  const QuestionPage({super.key});

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  String? selectedGender;
  String? selectedSeason;
  String? selectedSituation;
  String userName = '사용자'; // 기본 fallback

  final List<String> genders = ['여자', '남자'];
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      userName = args['name'] ?? '사용자';
    }
  }

  @override
  Widget build(BuildContext context) {
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

                  buildDropdown(
                    label: '성별',
                    value: selectedGender,
                    items: genders,
                    onChanged: (value) =>
                        setState(() => selectedGender = value),
                  ),
                  const SizedBox(height: 100),

                  buildDropdown(
                    label: '계절',
                    value: selectedSeason,
                    items: seasons,
                    onChanged: (value) =>
                        setState(() => selectedSeason = value),
                  ),
                  const SizedBox(height: 100),

                  buildDropdown(
                    label: '상황',
                    value: selectedSituation,
                    items: situations,
                    onChanged: (value) =>
                        setState(() => selectedSituation = value),
                  ),
                ],
              ),
            ),

            Positioned(
              bottom: 24,
              right: 24,
              child: OutlinedButton(
                onPressed:
                    (selectedGender != null &&
                        selectedSeason != null &&
                        selectedSituation != null)
                    ? () {
                        final arguments = {
                          'name': userName,
                          'gender': selectedGender!,
                          'season': selectedSeason!,
                          'situation': selectedSituation!,
                        };

                        if (selectedSituation == '면접' ||
                            selectedSituation == '시험기간') {
                          arguments['style'] = ''; // 스타일 없음
                          Navigator.pushNamed(
                            context,
                            '/choice',
                            arguments: arguments,
                          );
                        } else {
                          Navigator.pushNamed(
                            context,
                            '/style',
                            arguments: arguments,
                          );
                        }
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: Color(0xFFB3B3B3)),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 6,
                  ),
                ),
                child: const Text(
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
