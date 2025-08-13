import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../user_handle.dart';
import '../utils/user_handle.dart'; // 추가

class StylePage extends StatefulWidget {
  const StylePage({super.key});

  @override
  State<StylePage> createState() => _StylePageState();
}

class _StylePageState extends State<StylePage> {
  String? selectedStyle;

  // route args
  String _season = '';
  String _situation = '';
  String _name = '사용자';

  bool _didInit = false;
  bool _loadingPrefill = false;
  bool _saving = false;

  final List<String> styles = [
    '캐주얼 / 미니멀',
    '러블리',
    '스트릿',
    '댄디',
    '스포티',
    '빈티지 / 레트로',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _name = (args['name'] as String?) ?? '사용자';
      _season = (args['season'] as String?) ?? '';
      _situation = (args['situation'] as String?) ?? '';
    }

    if (_situation == '면접' || _situation == '시험기간') {
      Future.microtask(() {
        Navigator.pushReplacementNamed(
          context,
          '/choice',
          arguments: {
            'name': _name,
            'season': _season,
            'situation': _situation,
            'style': '',
          },
        );
      });
    } else {
      _prefillStyleFromFirestore();
    }

    _didInit = true;
  }

  Future<void> _prefillStyleFromFirestore() async {
    setState(() => _loadingPrefill = true);
    try {
      final doc = await userDocByHandle();
      final snap = await doc.get();
      final data = snap.data();
      if (data == null) return;

      final s = data['style'] as String?;
      if (s != null && mounted) {
        setState(() => selectedStyle = s);
      }
    } catch (_) {
      // 필요 시 오류 처리
    } finally {
      if (mounted) setState(() => _loadingPrefill = false);
    }
  }

  Future<void> _saveAndGoNext() async {
    if (selectedStyle == null) return;

    setState(() => _saving = true);
    try {
      final doc = await userDocByHandle();
      // style 병합 저장 (users/{handle})
      await doc.set({
        'style': selectedStyle,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/choice',
        arguments: {
          'name': _name,
          'season': _season,
          'situation': _situation,
          'style': selectedStyle!,
        },
      );
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 15),
                    Image.asset('assets/logo_3.png', width: 250),
                    const SizedBox(height: 30),
                    buildTagBox('계절', _season),
                    const SizedBox(height: 16),
                    buildTagBox('상황', _situation),
                    const SizedBox(height: 32),
                    Opacity(
                      opacity: _loadingPrefill ? 0.5 : 1,
                      child: IgnorePointer(
                        ignoring: _loadingPrefill,
                        child: buildStyleBox(),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                    onPressed: (!_saving && selectedStyle != null)
                        ? _saveAndGoNext
                        : null,
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: Color(0xFFB3B3B3)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text(
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
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
            final isSelected = selectedStyle == style;

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
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: isSelected
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
