import 'package:flutter/material.dart';

class StylePage extends StatefulWidget {
  final String gender;
  final String season;
  final String situation;
  final String name; // 사용자 이름 추가

  const StylePage({
    super.key,
    required this.gender,
    required this.season,
    required this.situation,
    required this.name,
  });

  @override
  State<StylePage> createState() => _StylePageState();
}

class _StylePageState extends State<StylePage> {
  String? selectedStyle;

  final List<String> styles = [
    '캐주얼 / 미니멀',
    '러블리',
    '스트릿',
    '댄디',
    '스포티',
    '빈티지 / 레트로',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.situation == '면접' || widget.situation == '시험기간') {
      Future.microtask(() {
        Navigator.pushReplacementNamed(
          context,
          '/choice',
          arguments: {
            'name': widget.name,
            'gender': widget.gender,
            'season': widget.season,
            'situation': widget.situation,
            'style': '',
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Image.asset('assets/logo_3.png', width: 100),
                    const SizedBox(height: 30),
                    buildTagBox('성별', widget.gender),
                    const SizedBox(height: 16),
                    buildTagBox('계절', widget.season),
                    const SizedBox(height: 16),
                    buildTagBox('상황', widget.situation),
                    const SizedBox(height: 32),
                    buildStyleBox(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: Color(0xFFB3B3B3)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: selectedStyle != null
                        ? () {
                            Navigator.pushNamed(
                              context,
                              '/choice',
                              arguments: {
                                'name': widget.name,
                                'gender': widget.gender,
                                'season': widget.season,
                                'situation': widget.situation,
                                'style': selectedStyle,
                              },
                            );
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: Color(0xFFB3B3B3)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTagBox(String label, String value) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10),
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

  Widget buildStyleBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              '스타일',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const Divider(color: Color(0xFFE0E0E0), height: 1, thickness: 1),
          ...styles.asMap().entries.map((entry) {
            final index = entry.key;
            final style = entry.value;
            return Column(
              children: [
                GestureDetector(
                  onTap: () => setState(() => selectedStyle = style),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          style,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: selectedStyle == style
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        Icon(
                          selectedStyle == style
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: selectedStyle == style
                              ? const Color(0xFF63C6D1)
                              : const Color(0xFFB3B3B3),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < styles.length - 1)
                  const Divider(
                    color: Color(0xFFE0E0E0),
                    height: 1,
                    thickness: 1,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
