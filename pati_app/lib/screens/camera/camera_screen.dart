import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../main.dart' show supabase;
import '../scan_result/scan_result_screen.dart';
import '../profile/allergy_profile_screen.dart';

// TODO(프론트엔드): 실제 서버 배포 주소로 교체 필요.
// - 컴퓨터에서 Flutter 웹/데스크톱으로 테스트: http://127.0.0.1:8000
// - 안드로이드 에뮬레이터에서 테스트: http://10.0.2.2:8000
// - 실제 폰(같은 와이파이)에서 테스트: http://<컴퓨터의 로컬 IP>:8000
// - 나중에 서버를 실제로 배포하면 그 도메인/IP로 교체
const String kServerBaseUrl = "http://127.0.0.1:8000";

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    _controller = CameraController(
      _cameras[0],
      ResolutionPreset.high,
    );

    await _controller!.initialize();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // 로그인된 사용자의 알레르기 프로필을 Supabase에서 직접 조회
  Future<List<String>> _getUserAllergens() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final data = await supabase
          .from('profiles')
          .select('allergens')
          .eq('id', userId)
          .maybeSingle();

      if (data != null && data['allergens'] != null) {
        return List<String>.from(data['allergens']);
      }
    } catch (_) {
      // 조회 실패 시 빈 목록으로 진행 (서버가 빈 목록이면 전부 '안전'으로 반환함)
    }
    return [];
  }

  // 카메라로 촬영
  Future<void> _captureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final image = await _controller!.takePicture();
    await _analyzeImage(File(image.path));
  }

  // 갤러리에서 선택 (에뮬레이터 등에서 실제 카메라 대신 테스트용으로 사용 가능)
  Future<void> _pickFromGalleryAndAnalyze() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    await _analyzeImage(File(pickedFile.path));
  }

  // 카메라 촬영/갤러리 선택 공통으로 쓰는 서버 전송 + 분석 로직
  Future<void> _analyzeImage(File imageFile) async {
    setState(() => _isAnalyzing = true);

    try {
      final userAllergens = await _getUserAllergens();

      if (userAllergens.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('등록된 알레르기 정보가 없습니다. 설정에서 먼저 등록해주세요.')),
          );
        }
        return;
      }

      final uri = Uri.parse("$kServerBaseUrl/scan");
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      request.fields['allergens'] = userAllergens.join(',');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody['detail'] ?? '분석 중 오류가 발생했습니다.');
      }

      final result = jsonDecode(utf8.decode(response.bodyBytes));
      // result 형태: {"위험": [...], "주의": [...], "안전": [...]}

      // ---- 스캔 이력 저장 (실패해도 결과 화면 표시는 막지 않음) ----
      try {
        final dangerList = List.from(result['위험'] ?? []);
        final cautionList = List.from(result['주의'] ?? []);
        final safeList = List.from(result['안전'] ?? []);

        String historyResult = 'safe';
        if (dangerList.isNotEmpty) {
          historyResult = 'danger';
        } else if (cautionList.isNotEmpty) {
          historyResult = 'caution';
        }

        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          await supabase.from('scan_history').insert({
            'user_id': userId,
            'danger_count': dangerList.length,
            'caution_count': cautionList.length,
            'safe_count': safeList.length,
            'result': historyResult,
          });
        }
      } catch (_) {
        // 이력 저장 실패는 무시하고 계속 진행
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScanResultScreen(
              imagePath: imageFile.path,
              scanResult: result,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('분석 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('성분표 스캔',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        actions: [
          // 알레르기 설정 재편집 진입점
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '알레르기 설정',
            onPressed: _isAnalyzing
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AllergyProfileScreen(isEditMode: true),
                      ),
                    );
                  },
          ),
          // 갤러리 선택 버튼 (테스트/대체 입력용)
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: '갤러리에서 선택',
            onPressed: _isAnalyzing ? null : _pickFromGalleryAndAnalyze,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 카메라 프리뷰
          if (_isInitialized)
            SizedBox.expand(
              child: CameraPreview(_controller!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFE53935)),
            ),

          // 가이드 프레임 오버레이
          if (_isInitialized)
            Center(
              child: Container(
                width: 300,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE53935), width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '성분표를 프레임 안에 맞춰주세요',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),

          // 분석 중 로딩
          if (_isAnalyzing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFE53935)),
                    SizedBox(height: 20),
                    Text('성분 분석 중...',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
              ),
            ),

          // 촬영 버튼
          if (_isInitialized && !_isAnalyzing)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _captureAndAnalyze,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE53935),
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 32),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}