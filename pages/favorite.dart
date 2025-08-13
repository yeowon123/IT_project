import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../user_handle.dart';
import '../utils/user_handle.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key}) ;

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  static const bool kAltForSmartstoreInEmulator = true;

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

  String _normalizeUrl(String url) {
    var s = url.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '').trim();
    if (s.isEmpty) return s;

    if (s.startsWith('//')) s = 'https:$s';
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';

    Uri uri;
    try {
      uri = Uri.parse(s);
    } catch (_) {
      return s;
    }

    if (uri.host.contains('shopping.naver.com')) {
      final door = uri.queryParameters['url'] ?? uri.queryParameters['u'];
      if (door != null && door.isNotEmpty) {
        try {
          return _normalizeUrl(Uri.decodeFull(door));
        } catch (_) {
          return door;
        }
      }
    }

    if (uri.scheme == 'http') {
      uri = uri.replace(scheme: 'https');
    }

    if (uri.host.endsWith('smartstore.naver.com')) {
      final m = RegExp(r'/products/(\d+)').firstMatch(uri.path);
      String? pid = m?.group(1);

      if (pid == null) {
        for (final key in ['productNo', 'itemId', 'pdpNo', 'prdNo']) {
          final v = uri.queryParameters[key];
          if (v != null && RegExp(r'^\d+$').hasMatch(v)) {
            pid = v;
            break;
          }
        }
      }

      if (pid != null && pid.isNotEmpty) {
        return 'https://m.smartstore.naver.com/products/$pid';
      }

      return Uri(
        scheme: 'https',
        host: 'm.smartstore.naver.com',
        path: uri.path,
      ).toString();
    }

    final cleaned = uri.replace(queryParameters: {});
    final cleanedStr = cleaned.toString();
    if (cleanedStr.endsWith('?')) {
      return cleanedStr.substring(0, cleanedStr.length - 1);
    }
    return cleanedStr;
  }

  bool _isSmartstore(String u) =>
      Uri.tryParse(u)?.host.endsWith('smartstore.naver.com') ?? false;

  String? _extractSmartstorePid(String u) {
    final m1 = RegExp(r'/products/(\d+)').firstMatch(u);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r'[?&](productNo|itemId|pdpNo|prdNo)=(\d+)').firstMatch(u);
    return m2?.group(2);
  }

  Future<bool> _openExternal(Uri u) async {
    try {
      return await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _blockedByNaver(Uri u) async {
    try {
      final r = await http.get(u).timeout(const Duration(seconds: 3));
      final t = r.body;
      return t.contains('접속이 일시적으로 제한') || t.contains('현재 서비스 접속이 불가합니다');
    } catch (_) {
      return false;
    }
  }

  Future<void> _launchURL(String raw) async {
    final normalized = _normalizeUrl(raw);

    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크가 없어요.')));
      return;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('잘못된 링크 형식이에요.')));
      return;
    }

    if (_isSmartstore(normalized)) {
      final pid = _extractSmartstorePid(normalized);
      if (pid != null) {
        if (kAltForSmartstoreInEmulator) {
          final alt = Uri.parse('https://msearch.shopping.naver.com/product/$pid');
          if (await _openExternal(alt)) return;
        }
        if (await _blockedByNaver(uri)) {
          final alt = Uri.parse('https://msearch.shopping.naver.com/product/$pid');
          if (await _openExternal(alt)) return;
        }
      }
    }

    final ok = await _openExternal(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없습니다. 다른 네트워크에서 다시 시도해 주세요.')),
      );
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _favStream(String categoryKr) {
    final col = favoritesColOrNull();
    if (col == null) {
      // 빈 스트림 반환 (null 안전)
      return const Stream.empty();
    }
    return col.where('category', isEqualTo: categoryKr).snapshots();
  }

  Map<String, dynamic> _toItemMap(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return {
      'docId': doc.id,
      'title': (data['title'] ?? data['name'] ?? '').toString(),
      'image': (data['image'] ?? '').toString(),
      'link': (data['link'] ?? '').toString(),
      'category': (data['category'] ?? '').toString(),
      'id': (data['id'] ?? '').toString(),
      'savedAt': data['savedAt'],
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
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
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

        final docs = (snap.data?.docs ?? []).toList();
        docs.sort((a, b) {
          final ta = (a.data()['savedAt'] as Timestamp?);
          final tb = (b.data()['savedAt'] as Timestamp?);
          final va = ta?.toDate().millisecondsSinceEpoch ?? 0;
          final vb = tb?.toDate().millisecondsSinceEpoch ?? 0;
          return vb.compareTo(va);
        });

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 10, top: 9),
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                SizedBox(
                  height: 60,
                  child: Center(
                    child: Text('저장된 항목이 없어요', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
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
                    final link = (item['link'] as String?) ?? '';

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
                                  const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                )
                                    : const Icon(Icons.image, size: 40, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => _launchURL(link),
                              child: Text(
                                item["title"] as String? ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
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
