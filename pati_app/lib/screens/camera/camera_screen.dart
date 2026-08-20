import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import '../scan_result/scan_result_screen.dart';

// TODO(프론트엔드): 실제 서버 배포 주소로 교체 필요.
// - 컴퓨터에서 Flutter 웹/데스크톱으로 테스트: http://127.0.0.1:8000
// - 안드로이드 에뮬레이터에서 테스트: http://10.0.2.2:8000  (127.0.0.1은 에뮬레이터 자기 자신을 가리켜서 안 됨)
// - 실제 폰(같은 와이파이)에서 테스트: http://<컴퓨터의 로컬 IP>:8000  (예: 192.168.0.5:8000)
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

  // TODO(프론트엔드): allergy_profile_screen에서 저장한 사용자 알레르기 목록을
  // 실제로 가져오도록 교체 필요. (예: SharedPreferences, Provider, Riverpod 등
  // 프로젝트에서 쓰는 상태관리 방식에 맞게)
  // 지금은 임시로 하드코딩된 값을 사용함.
  List<String> _getUserAllergens() {
    return ["난류", "우유", "새우"]; // 임시값 - 실제 사용자 설정으로 교체 필요
  }

  Future<void> _captureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isAnalyzing = true);

    try {
      final image = await _controller!.takePicture();
      final userAllergens = _getUserAllergens();

      // ---- 서버로 이미지 + 알레르기 목록 전송 ----
      final uri = Uri.parse("$kServerBaseUrl/scan");
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('file', image.path),
      );
      request.fields['allergens'] = userAllergens.join(',');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        // 서버가 에러를 반환한 경우 (400, 422, 500 등)
        final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody['detail'] ?? '분석 중 오류가 발생했습니다.');
      }

      final result = jsonDecode(utf8.decode(response.bodyBytes));
      // result 형태: {"위험": [...], "주의": [...], "안전": [...]}

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScanResultScreen(
              imagePath: image.path,
              // TODO(프론트엔드): ScanResultScreen이 이 결과를 받아서
              // 위험/주의/안전 목록을 화면에 표시하도록 파라미터 추가 필요.
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