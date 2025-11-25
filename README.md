# KYC Sample Flutter

Flutter 기반 KYC(Know Your Customer) 인증 샘플 애플리케이션입니다. WebView를 통해 KYC 서비스와 통합하여 신원 인증 프로세스를 구현합니다.

## 프로젝트 개요

이 애플리케이션은 사용자의 신원 정보를 수집하고 KYC 인증 서비스를 통해 본인 인증을 수행하는 Flutter 앱입니다. iOS와 Android 플랫폼을 모두 지원하며, 카메라 및 마이크 권한을 활용하여 실시간 신원 확인 기능을 제공합니다.

## 주요 기능

- 사용자 정보 입력 폼 (이름, 생년월일, 전화번호, 이메일)
- 플랫폼별 카메라 및 마이크 권한 관리
- WebView 기반 KYC 서비스 통합
- Base64 인코딩을 통한 안전한 데이터 전송
- 실시간 KYC 인증 프로세스
- 인증 결과 처리 및 시각화

## 기술 스택

- **Flutter SDK**: 3.0.0 이상
- **Dart**: 3.0.0 이상
- **주요 패키지**:
  - `webview_flutter: ^4.7.0` - WebView 통합
  - `permission_handler: ^11.3.1` - 권한 관리
  - `flutter_webrtc: ^1.2.0` - WebRTC 지원
  - `webview_flutter_wkwebview: ^3.23.3` - iOS WKWebView 지원
  - `convert: ^3.1.1` - Base64 인코딩

## 시작하기

### 사전 요구사항

- Flutter SDK 3.0.0 이상
- iOS 개발: Xcode 14 이상, macOS
- Android 개발: Android Studio, JDK 11 이상

### 설치

1. 저장소 클론
```bash
git clone <repository-url>
cd kyc-sample-flutter
```

2. 의존성 설치
```bash
flutter pub get
```

3. iOS 의존성 설치 (iOS 개발 시)
```bash
cd ios
pod install
cd ..
```

### 실행

```bash
# 연결된 디바이스 확인
flutter devices

# 앱 실행
flutter run

# 특정 디바이스에서 실행
flutter run -d <device-id>
```

## 설정

### KYC 서비스 인증 정보

`lib/main.dart` 파일의 `_encodeInitialUserInfo()` 메서드에서 실제 KYC 서비스 인증 정보를 설정해야 합니다:

```dart
Map<String, dynamic> requestMap = {
  'customer_id': 12,              // 실제 고객 ID로 변경
  'id': 'demoUser',               // 실제 서비스 ID로 변경
  'key': 'demoUser0000!',         // 실제 서비스 키로 변경
  // ... 사용자 입력 정보
};
```

### iOS 권한 설정

`ios/Runner/Info.plist` 파일에 다음 권한 설명을 추가해야 합니다:

```xml
<key>NSCameraUsageDescription</key>
<string>신원 인증을 위해 카메라 접근 권한이 필요합니다.</string>
<key>NSMicrophoneUsageDescription</key>
<string>신원 인증을 위해 마이크 접근 권한이 필요합니다.</string>
```

### Android 권한 설정

`android/app/src/main/AndroidManifest.xml` 파일에 다음 권한을 추가해야 합니다:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

## 아키텍처

### 애플리케이션 흐름

1. **사용자 정보 입력**: 이름, 생년월일, 전화번호, 이메일 입력
2. **권한 요청**: 카메라 및 마이크 권한 확인 및 요청
3. **WebView 초기화**: KYC 서비스 URL 로드
4. **데이터 전송**: Base64 인코딩된 사용자 정보 전송
5. **KYC 프로세스**: 신원 인증 진행
6. **결과 처리**: 인증 결과 수신 및 표시

### 주요 컴포넌트

- `MyApp`: 애플리케이션 진입점
- `InputFormScreen`: 사용자 정보 입력 화면 관리
- `_InputFormScreenState`: 상태 관리 및 비즈니스 로직
  - 권한 처리 (`_handleCameraPermission`)
  - WebView 초기화 (`_initializeWebViewController`)
  - 데이터 인코딩 (`_encodeInitialUserInfo`)
  - 메시지 처리 (`_handleMessageFromWeb`)
  - 결과 처리 (`_processKycResult`)

### 데이터 인코딩 프로세스

```
사용자 데이터 → JSON → URI 인코딩 → UTF-8 바이트 → Base64 인코딩 → WebView 전송
```

## 빌드

### Android 빌드

```bash
# APK 빌드
flutter build apk --release

# App Bundle 빌드
flutter build appbundle --release
```

### iOS 빌드

```bash
# iOS 빌드 (Xcode 프로젝트 생성)
flutter build ios --release

# 또는 Xcode에서 직접 빌드
open ios/Runner.xcworkspace
```

## 테스트

```bash
# 단위 테스트 실행
flutter test

# 통합 테스트 실행
flutter test integration_test
```

## 문제 해결

### 일반적인 문제

1. **권한 거부 오류**
   - 설정 > 앱 권한에서 카메라 및 마이크 권한 확인
   - Info.plist/AndroidManifest.xml 권한 설정 확인

2. **WebView 로딩 실패**
   - 네트워크 연결 확인
   - KYC 서비스 URL 및 인증 정보 확인

3. **빌드 오류**
   ```bash
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   flutter run
   ```

## 프로젝트 구조

```
kyc-sample-flutter/
├── lib/
│   └── main.dart              # 메인 애플리케이션 로직
├── android/                   # Android 네이티브 코드
├── ios/                       # iOS 네이티브 코드
├── web/                       # Web 플랫폼 지원
├── linux/                     # Linux 플랫폼 지원
├── macos/                     # macOS 플랫폼 지원
├── pubspec.yaml               # 프로젝트 의존성
└── README.md                  # 프로젝트 문서
```

## 라이선스

이 프로젝트는 샘플 코드로 제공됩니다.

## 작성자

- sb.go@alcherainc.com

## 참고 자료

- [Flutter 공식 문서](https://docs.flutter.dev/)
- [WebView Flutter 패키지](https://pub.dev/packages/webview_flutter)
- [Permission Handler 패키지](https://pub.dev/packages/permission_handler)

## 지원

문의사항이나 이슈가 있는 경우 sb.go@alcherainc.com으로 연락해주세요.
