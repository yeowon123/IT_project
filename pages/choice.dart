import 'package:flutter/material.dart';

class ChoicePage extends StatefulWidget {
  const ChoicePage({super.key});

  @override
  State<ChoicePage> createState() => _ChoicePageState();
}

class _ChoicePageState extends State<ChoicePage> {
  // ★ 선택된 한글 카테고리 ('상의' | '하의' | '원피스')
  String? selectedCategory;

  // ★ 전달받은 값들을 state에 보관
  late String name;
  late String season;
  late String situation;
  String? style;

  // ★ 카테고리 매핑표 (API / Firestore)
  static const Map<String, String> _apiCategoryMap = {
    '상의': 'top',
    '하의': 'bottom',
    '원피스': 'onepiece',
  };
  static const Map<String, String> _fsCategoryMap = {
    '상의': 'tops',
    '하의': 'bottoms',
    '원피스': 'setup',
  };

  bool get _isLovely {
    final s = (style ?? '').trim().toLowerCase();
    return s == 'lovely' || style == '러블리';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, String?>?) ??
        {};
    name = args['name'] ?? '';
    season = args['season'] ?? '';
    situation = args['situation'] ?? '';
    style = args['style'];
  }

  void _showCategoryDialog(BuildContext context) {
    // ★ 러블리일 때만 '원피스' 포함
    final options = _isLovely ? ['상의', '하의', '원피스'] : ['상의', '하의'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFF2F2F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '추천받을 의류 카테고리 선택',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                children: options.map((category) {
                  final isSelected = selectedCategory == category;
                  return ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedCategory = category;
                      });
                      Navigator.pop(context);
                      _navigateToRecommendation();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected
                          ? const Color(0xFF63C6D1)
                          : Colors.white,
                      foregroundColor: isSelected ? Colors.white : Colors.black,
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF63C6D1)
                            : const Color(0xFFB3B3B3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(category),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToRecommendation() {
    if (selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('카테고리를 선택하세요')));
      return;
    }

    // ★ 러블리 외 스타일에서 ‘원피스’가 선택되지 않도록 2중 방어
    if (!_isLovely && selectedCategory == '원피스') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이 스타일에서는 원피스를 선택할 수 없어요.')));
      return;
    }

    // ★ API/FS 모두 코드값으로 변환해 함께 전달
    final categoryKr = selectedCategory!;
    final categoryApi = _apiCategoryMap[categoryKr] ?? 'top';
    final categoryFs = _fsCategoryMap[categoryKr] ?? 'tops';

    Navigator.pushNamed(
      context,
      '/recommendation',
      arguments: {
        'season': season,
        'situation': situation,
        'style': style ?? '',
        // ★ 서버 호출용
        'categoryApi': categoryApi, // top | bottom | onepiece
        // ★ Firestore 조회용
        'categoryFs': categoryFs, // tops | bottoms | setup
        // (표시용)
        'categoryKr': categoryKr, // 상의 | 하의 | 원피스
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        centerTitle: true,
        title: Image.asset('assets/logo_3.png', width: 100),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text(
                '메뉴',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('내 정보'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('즐겨찾기'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/stylist');
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('검색'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
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
              buildInfoBox('계절', season),
              const SizedBox(height: 12),
              buildInfoBox('상황', situation),
              if (situation != '면접' && situation != '시험기간') ...[
                const SizedBox(height: 12),
                buildInfoBox('스타일', style ?? ''),
              ],
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => _showCategoryDialog(context),
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
