// lib/pages/stylist_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/user_handle.dart'; // ✅ favoritesCol() 사용

class StylistPage extends StatefulWidget {
  const StylistPage({Key? key}) : super(key: key);

  @override
  State<StylistPage> createState() => _StylistPageState();
}

class _StylistPageState extends State<StylistPage> {
  // 선택 상태는 문서 ID 기준으로 보관(스트림 리빌드에도 안전)
  String? selectedTopDocId;
  String? selectedBottomDocId;

  Map<String, dynamic>? selectedTop;
  Map<String, dynamic>? selectedBottom;

  void resetSelection() {
    setState(() {
      selectedTopDocId = null;
      selectedBottomDocId = null;
      selectedTop = null;
      selectedBottom = null;
    });
  }

  // 카테고리별 즐겨찾기 실시간 스트림
  Stream<QuerySnapshot<Map<String, dynamic>>> _favStream(String categoryKr) {
    // 저장 시 'category' 필드에 한글(상의/하의/원피스)을 넣었으므로 그대로 필터
    return favoritesCol().where('category', isEqualTo: categoryKr).snapshots();
    // 필요시 정렬: .orderBy('savedAt', descending: true) (모든 문서가 필드를 갖는지 확인 후 사용)
  }

  // 도큐먼트를 안전한 Map으로 변환
  Map<String, dynamic> _toItemMap(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return {
      'docId': doc.id, // 문서 ID (선택 상태 비교용)
      'title': (data['title'] ?? data['name'] ?? '').toString(),
      'image': (data['image'] ?? '').toString(),
      'link': (data['link'] ?? '').toString(),
      'category': (data['category'] ?? '').toString(), // 상의/하의/원피스
      'id': (data['id'] ?? '').toString(), // 원본 아이템 ID
    };
  }

  Widget sectionStream(String title, String categoryKr) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _favStream(categoryKr),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('불러오는 중...'),
                ],
              ),
            ),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('오류: ${snap.error}')),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 10, top: 9),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(
                      '저장된 항목이 없어요',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final items = docs.map(_toItemMap).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 10, top: 9),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, idx) {
                    final item = items[idx];
                    final docId = item['docId'] as String;

                    final isSelected = (categoryKr == '상의'
                        ? selectedTopDocId == docId
                        : categoryKr == '하의'
                        ? selectedBottomDocId == docId
                        : false);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (categoryKr == '상의') {
                            selectedTopDocId = docId;
                            selectedTop = item;
                          } else if (categoryKr == '하의') {
                            selectedBottomDocId = docId;
                            selectedBottom = item;
                          }
                          // 원피스는 프리뷰에 합성하지 않으므로 선택 상태만 별도 관리하지 않음
                        });
                      },
                      child: Container(
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: (item["image"] as String).isNotEmpty
                                    ? Image.network(
                                        item["image"] as String,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stack) =>
                                            const Icon(
                                              Icons.broken_image,
                                              size: 40,
                                              color: Colors.grey,
                                            ),
                                      )
                                    : const Icon(
                                        Icons.image,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item["title"] as String? ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              item["link"] as String? ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreviewBox() {
    return Container(
      width: double.infinity,
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (selectedBottom != null)
            Image.network(
              selectedBottom!["image"] as String? ?? '',
              width: 150,
              height: 150,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image, size: 80, color: Colors.grey),
            ),
          if (selectedTop != null)
            Image.network(
              selectedTop!["image"] as String? ?? '',
              width: 150,
              height: 150,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image, size: 80, color: Colors.grey),
            ),
          if (selectedTop == null && selectedBottom == null)
            const Text('상의와 하의를 선택해 주세요', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('즐겨찾기', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.8,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 16),
          // ✅ Firestore에서 실시간으로 가져오는 섹션 3개
          sectionStream('상의', '상의'),
          sectionStream('하의', '하의'),
          sectionStream('원피스', '원피스'),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '코디 미리보기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          _buildPreviewBox(),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: resetSelection,
              icon: const Icon(Icons.refresh, color: Colors.black),
              label: const Text('초기화', style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.black),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
