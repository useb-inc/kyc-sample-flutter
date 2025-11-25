import 'dart:io';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart'; // 이 줄 추가
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.top]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '입력 폼 예제',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      home: const InputFormScreen(),
    );
  }
}

class InputFormScreen extends StatefulWidget {
  const InputFormScreen({super.key});

  @override
  State<InputFormScreen> createState() => _InputFormScreenState();
}

class _InputFormScreenState extends State<InputFormScreen> {
  // ========================================
  // 상태 변수
  // ========================================
  late WebViewController _controller;
  bool _hasDataBeenSent = false;
  bool _permissionsGranted = false;
  final String _kycUri = "https://kyc.useb.co.kr/auth";

  // 폼 입력 컨트롤러
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 진행 상태
  String progress = 'toDo';
  String _encodeInitialUserInfo() {
    // 생년월일 포맷 변환 로직
    String birthdayInput = _dobController.text;
    String formattedBirthday = birthdayInput;

    if (birthdayInput.length == 8 && RegExp(r'^\d+$').hasMatch(birthdayInput)) {
      formattedBirthday =
          '${birthdayInput.substring(0, 4)}-${birthdayInput.substring(4, 6)}-${birthdayInput.substring(6, 8)}';
    }

    // 요청 데이터 구성 (실제 값으로 대체 필요)
    Map<String, dynamic> requestMap = {
      // NOTE: 여기의 ID와 KEY는 실제 서비스 키로 대체해야 합니다.
      'customer_id': 12,
      'id': 'demoUser',
      'key': 'demoUser0000!',
      'name': _nameController.text,
      'birthday': formattedBirthday,
      'phone_number': _phoneController.text,
      'email': _emailController.text,
    };

    // 인코딩 체인: JSON → URI → Base64 (Swift 샘플과 동일한 인코딩 방식)
    String requestData = json.encode(requestMap);
    String urlEncodedData = Uri.encodeComponent(requestData);
    List<int> bytes = utf8.encode(urlEncodedData);
    return base64Encode(bytes);
  }

  // KYC 결과 저장
  Map<String, String> kycResult = {
    'rsp_result': '',
    'rsp_review_result': '',
    'evt_result': '',
  };

  // ========================================
  // 생명주기 메서드
  // ========================================
  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ========================================
  // 1단계: 권한 처리
  // ========================================
  Future<bool> _handleCameraPermission() async {
    // iOS: 카메라 + 마이크 권한 요청
    if (Platform.isIOS) {
      print('iOS: 카메라 및 마이크 권한 요청 시작');

      var cameraStatus = await Permission.camera.request();
      var micStatus = await Permission.microphone.request();

      print('iOS 카메라 권한: ${cameraStatus.isGranted ? '허용됨' : '거부됨'}');
      print('iOS 마이크 권한: ${micStatus.isGranted ? '허용됨' : '거부됨'}');

      bool bothGranted = cameraStatus.isGranted && micStatus.isGranted;

      setState(() {
        _permissionsGranted = bothGranted;
      });

      if (!bothGranted) {
        if (!mounted) return false;

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('권한 필요'),
              content: const Text('KYC 인증을 위해 카메라와 마이크 권한이 필요합니다.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings();
                  },
                  child: const Text('설정하기'),
                ),
              ],
            );
          },
        );
        return false;
      }

      return true;
    }

    // Android: 카메라 권한만 요청
    if (Platform.isAndroid) {
      print('Android: 카메라 권한 요청 시작');
      var status = await Permission.camera.request();

      setState(() {
        _permissionsGranted = status.isGranted;
      });

      print('Android 카메라 권한: ${status.isGranted ? '허용됨' : '거부됨'}');

      if (!status.isGranted) {
        if (!mounted) return false;

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('권한 필요'),
              content: const Text('KYC 인증을 위해 카메라 권한이 필요합니다.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings();
                  },
                  child: const Text('설정하기'),
                ),
              ],
            );
          },
        );
        return false;
      }

      return status.isGranted;
    }

    return false;
  }

  // ========================================
  // 2단계: 폼 제출 및 WebView 초기화
  // ========================================
  void _submitData() async {
    if (_formKey.currentState!.validate()) {
      // 카메라 권한 요청 및 확인
      bool isGranted = await _handleCameraPermission();
      if (!isGranted) {
        print('오류: 카메라 권한이 필요합니다. 데이터 전송 중단.');
        return;
      }

      // WebView 초기화 및 설정
      _initializeWebViewController();

      // 화면을 WebView로 전환
      setState(() {
        progress = 'inProgress';
      });
    }
  }

  void _initializeWebViewController() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      // iOS: 미디어 자동 재생 및 권한 설정
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'alcherakyc',
        onMessageReceived: _handleMessageFromWeb,
      );
    _controller.setOnConsoleMessage((message) {
      print(':  [WebView Console] ${message.level.name}: ${message.message}');
    });
    if (Platform.isIOS) {
      final iosController = _controller.platform as WebKitWebViewController;
      iosController.setOnJavaScriptAlertDialog((request) async {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(request.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      });
      // 권한 요청 핸들러 등록
      iosController.setOnPlatformPermissionRequest((request) async {
        await request.grant();
      });
    }
    // Android 전용 설정
    if (Platform.isAndroid) {
      final androidController =
          _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setOnPlatformPermissionRequest((request) {
        request.grant();
      });
    }
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) => print('페이지 로딩 시작: $url'),
        onProgress: (p) => print('페이지 로딩 진행률: $p%'),
        onPageFinished: _handlePageFinished,
        onWebResourceError: (error) {},
      ),
    );

    _controller.loadRequest(Uri.parse(_kycUri));
  }

  void _handlePageFinished(String url) async {
    print('🎯🎯🎯 _handlePageFinished 호출됨!!! url: $url');

    if (url == _kycUri || url.contains('kyc.useb.co.kr')) {
      print('✅ KYC 페이지 확인됨');

      // ⭐ 데이터가 아직 전송되지 않았을 때만 전송
      if (!_hasDataBeenSent) {
        print('⏱️ 500ms 후 데이터 전송 예약');

        // ✅ 실제로 500ms 대기
        await Future.delayed(const Duration(milliseconds: 500));

        print('📤 데이터 전송 시작');

        // ⭐ requestData null 체크 추가
        final requestData = _encodeInitialUserInfo();
        if (requestData.isNotEmpty) {
          await _controller.runJavaScript("postMessage('$requestData')");
          print('✅ postMessage 전송 완료');
          print('************전송된 데이터: $requestData');
          setState(() {
            _hasDataBeenSent = true;
          });
        } else {
          print('❌ 전송할 데이터가 비어있습니다');
        }
      } else {
        print('✅ 데이터가 이미 전송되었습니다.');
      }
    } else {
      print('❌ KYC 페이지가 아님: $url');
    }
  }

  void _handleMessageFromWeb(JavaScriptMessage message) {
    final raw = message.message;
    print('[alcherakyc] raw length=${raw.length}');
    final preview = raw.length > 200 ? raw.substring(0, 200) + '...' : raw;
    print('[alcherakyc] raw preview: $preview');

    try {
      // 디코딩 체인: Base64 → UTF-8 → URI → JSON
      final bytes = base64Decode(raw.trim());
      final utf8Str = utf8.decode(bytes);
      final decoded = Uri.decodeComponent(utf8Str);
      final parsed = jsonDecode(decoded);

      if (parsed is Map) {
        print('[alcherakyc] JSON keys: ${parsed.keys.toList()}');

        if (parsed.containsKey('result')) {
          final result = parsed['result'];
          print('[alcherakyc] result: $result');

          // 결과에 따른 처리
          _processKycResult(result, parsed);
        }
      }
      print('[alcherakyc] JSON: ${jsonEncode(parsed)}');
    } catch (e, st) {
      print('[alcherakyc] 디코딩/파싱 실패: $e');
      print(st.toString().split('\n').take(5).join('\n'));
    }
  }

  // ========================================
  // 7단계: KYC 결과 처리 로직
  // ========================================
  void _processKycResult(String result, Map<dynamic, dynamic> parsed) {
    switch (result) {
      case 'success':
        print('✅ KYC 작업이 성공했습니다.');
        if (parsed.containsKey('review_result')) {
          setState(() {
            kycResult['rsp_review_result'] =
                jsonEncode(parsed['review_result']);
          });
        }
        if (parsed.containsKey('api_response')) {
          setState(() {
            kycResult['rsp_result'] = jsonEncode(parsed['api_response']);
          });
        }
        break;

      case 'failed':
        print('❌ KYC 작업이 실패했습니다.');
        setState(() {
          kycResult['evt_result'] = 'failed';
          progress = 'done';
        });
        break;

      case 'complete':
        print('🎉 KYC가 완료되었습니다.');
        setState(() {
          kycResult['evt_result'] = 'complete';
          progress = 'done';
        });
        break;

      case 'close':
        print('⚠️ KYC가 완료되지 않았습니다.');
        setState(() {
          kycResult['evt_result'] = 'close';
          progress = 'done';
        });
        break;

      default:
        print('❓ 알 수 없는 result: $result');
    }
  }

  // ========================================
  // UI 빌드
  // ========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (progress == 'done') {
              return _buildResultScreen();
            }

            if (progress == 'inProgress') {
              return WebViewWidget(controller: _controller);
            }

            return _buildInputForm();
          },
        ),
      ),
    );
  }

  // ========================================
  // UI: 입력 폼
  // ========================================
  Widget _buildInputForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '이름 (예: 홍길동)',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '이름을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _dobController,
              decoration: const InputDecoration(
                labelText: '생년월일 (예: YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.datetime,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '생년월일을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '전화번호 (예: 01012345678)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '전화번호를 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '이메일(예: email@address.com)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '이메일을 입력해주세요 ';
                }
                return null;
              },
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _submitData,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('정보 전송', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // UI: 결과 화면
  // ========================================
  Widget _buildResultScreen() {
    String statusMessage = '';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.info;

    switch (kycResult['evt_result']) {
      case 'complete':
        statusMessage = 'KYC 인증이 완료되었습니다! 🎉';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusMessage = 'KYC 인증이 실패했습니다. ❌';
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'close':
        statusMessage = 'KYC 인증이 완료되지 않았습니다. ⚠️';
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      default:
        statusMessage = '결과를 기다리는 중...';
        statusColor = Colors.blue;
        statusIcon = Icons.hourglass_empty;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            color: statusColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(statusIcon, size: 64, color: statusColor),
                  const SizedBox(height: 16),
                  Text(
                    statusMessage,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                progress = 'toDo';
                _hasDataBeenSent = false;
                _nameController.clear();
                _dobController.clear();
                _phoneController.clear();
                _emailController.clear();
                kycResult = {
                  'rsp_result': '',
                  'rsp_review_result': '',
                  'evt_result': '',
                };
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시작', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
          const SizedBox(height: 30),
          if (kycResult['rsp_review_result']?.isNotEmpty ?? false) ...[
            ExpansionTile(
              title: const Text(
                '상세 결과 보기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _formatImageData(kycResult['rsp_review_result'] ?? ''),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ========================================
  // 유틸리티: 이미지 데이터 포맷팅
  // ========================================
  String _formatImageData(String raw) {
    if (!raw.contains('/9')) return raw;

    final parts = raw.split('/9');
    if (parts.length < 2) return raw;

    final beforeImage = parts[0] + '/9';
    final imageData = parts.sublist(1).join('/9');

    if (imageData.length > 20) {
      final preview = imageData.substring(0, 20);
      final remaining = imageData.length - 20;
      return '$beforeImage$preview... ($remaining자 생략)';
    }

    return raw;
  }
}
