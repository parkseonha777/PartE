import 'package:flutter/material.dart';
import '../../main.dart' show supabase;
import '../scan_guide/scan_guide_screen.dart';

class AllergyProfileScreen extends StatefulWidget {
  // true면 "설정에서 다시 편집" 모드 (저장 후 뒤로가기)
  // false(기본)면 최초 가입 흐름 (저장 후 스캔 가이드로 이동)
  final bool isEditMode;

  const AllergyProfileScreen({super.key, this.isEditMode = false});

  @override
  State<AllergyProfileScreen> createState() => _AllergyProfileScreenState();
}

class _AllergyProfileScreenState extends State<AllergyProfileScreen> {
  // DB(allergens 테이블)의 명칭과 정확히 일치시킴 — 매칭 로직이 이 이름으로 대조하기 때문에 중요
  final Map<String, bool> _allergies = {
    '난류': false,
    '우유': false,
    '메밀': false,
    '땅콩': false,
    '대두': false,
    '밀': false,
    '고등어': false,
    '게': false,
    '새우': false,
    '돼지고기': false,
    '복숭아': false,
    '토마토': false,
    '아황산류': false,
    '호두': false,
    '닭고기': false,
    '쇠고기': false,
    '오징어': false,
    '조개류': false,
    '잣': false,
  };

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await supabase
          .from('profiles')
          .select('allergens')
          .eq('id', userId)
          .maybeSingle();

      if (data != null && data['allergens'] != null) {
        final saved = List<String>.from(data['allergens']);
        setState(() {
          for (final key in _allergies.keys) {
            _allergies[key] = saved.contains(key);
          }
        });
      }
    } catch (_) {
      // 최초 가입 등 프로필이 아직 없는 경우 → 전부 미선택 상태로 그냥 진행
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAndContinue() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final selected =
        _allergies.entries.where((e) => e.value).map((e) => e.key).toList();

    setState(() => _isSaving = true);

    try {
      await supabase.from('profiles').upsert({
        'id': userId,
        'allergens': selected,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      if (widget.isEditMode) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ScanGuideScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _allergies.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('알레르기 프로필',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        // 최초 가입 흐름에서는 뒤로가기 버튼 숨김, 설정에서 들어온 경우엔 보여줌
        automaticallyImplyLeading: widget.isEditMode,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : Column(
              children: [
                // 안내 문구
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.red[50],
                  child: Column(
                    children: [
                      const Text('알레르기 유발 성분을 선택해주세요',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('선택된 성분: $selectedCount개',
                          style: const TextStyle(
                              color: Color(0xFFE53935),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                // 알레르기 목록
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _allergies.length,
                    itemBuilder: (context, index) {
                      final key = _allergies.keys.elementAt(index);
                      final isSelected = _allergies[key]!;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _allergies[key] = !isSelected),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE53935)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFE53935)
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              key,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 저장 버튼
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _saveAndContinue,
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              widget.isEditMode ? '저장하기' : '저장하고 시작하기',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}