import 'package:flutter/material.dart';
import '../../services/allergy_store.dart';
import '../home/home_shell.dart';

class AllergyProfileScreen extends StatefulWidget {
  const AllergyProfileScreen({super.key});

  @override
  State<AllergyProfileScreen> createState() => _AllergyProfileScreenState();
}

class _AllergyProfileScreenState extends State<AllergyProfileScreen> {
  final Map<String, bool> _allergies = {
    '계란': false,
    '우유': false,
    '메밀': false,
    '땅콩': false,
    '대두(콩)': false,
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
  };

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  // 저장해 둔 선택을 불러와서 화면에 표시
  Future<void> _loadSaved() async {
    await AllergyStore.instance.load();
    if (!mounted) return;
    final saved = AllergyStore.instance.selected.value;
    setState(() {
      for (final k in _allergies.keys.toList()) {
        _allergies[k] = saved.contains(k);
      }
    });
  }

  Future<void> _saveAndContinue() async {
    final names =
        _allergies.entries.where((e) => e.value).map((e) => e.key).toList();
    await AllergyStore.instance.save(names);
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeShell()),
      );
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
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            foregroundColor: const Color(0xFF1F2A24),
            elevation: 0,
            scrolledUnderElevation: 0,
            shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E5E5), width: 1),
        ),
      ),
      body: Column(
        children: [
          // 안내 문구
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFD1E7CE),
            child: Column(
              children: [
                const Text('알레르기 유발 성분을 선택해주세요',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('선택된 성분: $selectedCount개',
                    style: const TextStyle(
                        color: Color(0xFF2F6B54),
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // 알레르기 목록
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                          ? const Color(0xFF2F6B54)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2F6B54)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        key,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
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
                  backgroundColor: const Color(0xFF2F6B54),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveAndContinue,
                child: const Text('저장하기',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}