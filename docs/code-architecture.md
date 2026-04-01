# 코드 아키텍처

## 패턴
단순 MVVM. 과한 추상화 없이 빠르게 구현.

## 디렉토리 구조
```
Mofit/
├── App/
│   ├── MofitApp.swift              # @main, 온보딩 분기, SwiftData 컨테이너
│   └── ContentView.swift           # TabView (홈/기록/AI코칭)
│
├── Models/
│   ├── UserProfile.swift
│   ├── WorkoutSession.swift
│   └── CoachingFeedback.swift
│
├── Views/
│   ├── Onboarding/
│   │   └── OnboardingView.swift    # 단계별 온보딩 전체 (1파일)
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── ExercisePickerView.swift
│   ├── Tracking/
│   │   └── TrackingView.swift      # 카메라 프리뷰 + 상태별 오버레이
│   ├── Records/
│   │   └── RecordsView.swift
│   ├── Coaching/
│   │   └── CoachingView.swift
│   └── Profile/
│       └── ProfileEditView.swift
│
├── ViewModels/
│   ├── TrackingViewModel.swift     # 핵심. 상태 머신 + 카메라 + 포즈 + 카운팅
│   └── CoachingViewModel.swift     # API 호출 + 횟수 관리
│
├── Services/
│   ├── PoseDetectionService.swift  # VNDetectHumanBodyPoseRequest 래퍼
│   ├── HandDetectionService.swift  # VNDetectHumanHandPoseRequest 래퍼
│   ├── SquatCounter.swift          # 관절 각도 → rep 판정
│   └── ClaudeAPIService.swift      # Claude API 호출
│
├── Camera/
│   ├── CameraManager.swift         # AVCaptureSession 설정/관리
│   └── CameraPreviewView.swift     # UIViewRepresentable
│
├── Config/
│   ├── Secrets.swift               # API key (.gitignore)
│   └── Secrets.example.swift       # 템플릿 (git 포함)
│
└── Utils/
    └── Theme.swift                 # 형광초록(#__), 무채색 팔레트
```

## 카메라 파이프라인
```
AVCaptureSession (전면 카메라)
  → CMSampleBuffer
     ├─ AVCaptureVideoPreviewLayer (30fps, 항상 부드러움)
     └─ Vision 분석 (15fps 샘플링)
          ├─ VNDetectHumanBodyPoseRequest → SquatCounter
          └─ VNDetectHumanHandPoseRequest → 손바닥 판정
```
프리뷰와 분석을 분리. 프리뷰는 네이티브 레이어가 직접 렌더링하므로 Vision 처리 빈도와 무관하게 항상 30fps.

## 스쿼트 판정
```
hip-knee-ankle 세 관절의 각도 계산
  서있음: 각도 > 160°
  앉음:   각도 < 100°
  서있음 → 앉음 → 서있음 = 1 rep
```

## 손바닥 판정
5개 손가락 끝(tip)과 손목(wrist) 사이 관절들이 전부 펴진 상태 = 손바닥.
1초간 연속 유지 시 트리거.

## 트래킹 상태 머신
```
idle → (palm 1s) → countdown → (5s) → tracking
tracking → (palm 1s) → setComplete → countdown → (5s) → tracking
any state → (stop btn) → saveRecord → home
```

## 화면 자동 잠금
트래킹 화면 진입 시 `UIApplication.shared.isIdleTimerDisabled = true`, 퇴장 시 복원.
