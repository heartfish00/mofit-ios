# Phase 1: permission-flow-impl

## 사전 준비

**전제**: 작업 시작 시 아래 커맨드가 빈 결과여야 한다 (Phase 0 이 이미 커밋되어 있어야 한다).

```bash
git status --porcelain -- docs/ Mofit/ MofitTests/ project.yml README.md
```

출력되는 파일이 있으면 working tree 가 더럽다. 진행하지 말고 `tasks/7-camera-permission-recovery/index.json` 의 phase 1 status 를 `"error"`로 변경, `error_message` 에 `dirty working tree before phase 1` 로 기록 후 중단하라.

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/spec.md` (§1 탭 구성, §2.4 카메라 파이프라인, §2.5 진단 힌트, §2.6 autosave, **§2.8 카메라 권한 분기** — Phase 0 신규. 이번 phase 설계 원전. §3.1 데이터 모델, §5 분기 테이블)
- `docs/adr.md` (**ADR-019** — Phase 0 신설. 이번 phase 설계 원전. ADR-017 스쿼트 전용 스코프 준수, ADR-018 진단 힌트 / ADR-009 autosave 전례, ADR-015 외부 의존성 최소화)
- `docs/code-architecture.md` (디렉토리 구조, 특히 `Views/Tracking/`, `Views/Home/`, `Camera/` 블록. 이번 phase 는 tree 업데이트 없음)
- `docs/testing.md` ("XCTest 타겟" 섹션 — Phase 0 에서 `CameraPermissionResolver` 4 케이스 불릿 추가됨. 이번 phase 가 실제 구현 + 테스트 파일 생성)
- `tasks/7-camera-permission-recovery/docs-diff.md` (Phase 0 docs 변경 실제 diff — runner 자동 생성)
- `iterations/8-20260424_234219/requirement.md` (iteration 원문 읽기 전용. 특히 §구현 스케치 1~5, §CTO 승인 조건부 조건 1~5 — 조건 1 일반화 금지, 2 `.notDetermined` 배지 금지, 3 프라이버시 카피 사실 정합, 4 싱글톤/추상화 금지, 5 실기기 QA 필수화 금지)
- `tasks/6-coaching-generator/phase1.md` — 가장 최근 구현 phase 의 작성 톤/xcodegen 처리/MofitTests 확장 패턴 참조. 이번 phase 는 target 신설 없이 기존 `MofitTests/` 에 1 파일 추가.

그리고 이전 phase 의 작업물 + 기존 코드를 반드시 확인하라:

- `Mofit/Views/Tracking/TrackingView.swift` — **부분 수정**. 현재 구조(참조용):
  - L1~17 import / properties / init — **불변**. `@StateObject private var viewModel: TrackingViewModel` (L9), `@Binding var showConfetti: Bool`, `init(exerciseType:showConfetti:)` 유지.
  - L19~73 `body` — **최상단에 권한 분기 도입**. 기존 `GeometryReader { ZStack { ... } }` 블록을 `.ready` 브랜치에 한정. `.requestInline` / `.showSettingsFallback` 브랜치는 신규 subview.
  - L75~230 private subview 들 (`overlayContent`, `idleOverlay`, `countdownOverlay`, `trackingOverlay`, `setCompleteOverlay`, `jointOverlay`, `closeButton`, `stopButton`, `hintBanner`, `formatTime`) — **불변**. 전부 `.ready` 브랜치에서만 사용되므로 그대로 유지.
  - **중요**: `viewModel.startSession(modelContext:isLoggedIn:)` 호출은 `.onAppear` 안에 있으며 (L52), 기존 위치 그대로 `.ready` 브랜치 내부 GeometryReader 의 `.onAppear` 에 남긴다. `.requestInline` / `.showSettingsFallback` 브랜치에는 startSession 호출 금지.
- `Mofit/Views/Home/HomeView.swift` — **부분 수정**. 현재 구조(참조용):
  - L1~15 import / @Query / @State — **불변**. `@State private var showTracking = false` / `@State private var showConfetti = false` 등 유지.
  - L62~121 `body` — **부분 수정**. `startButton` 호출부(L73~75) 를 VStack 으로 감싸 배지를 버튼 아래에 배치. 새 `@State var cameraStatus: AVAuthorizationStatus` 추가 + `.onAppear` / `.onChange(of: scenePhase)` hook.
  - L163~176 `startButton` — **불변**. 버튼 자체 수정 없음. 배지는 별도 subview 로 버튼 아래 배치.
  - 나머지 (`loadServerData`, `parseISO8601Date`, `topBar`, `todaySummaryCard`, `summaryItem`, `formatDuration`, `ConfettiView`, `ConfettiParticle`) — **전부 불변**.
- `Mofit/Camera/CameraManager.swift` — **수정 금지**. 권한 체크를 Manager 에 두면 책임 번짐(CTO 조건 4 — 싱글톤/추상화 금지). 이번 phase 는 Camera 디렉토리 미변경.
- `Mofit/ViewModels/TrackingViewModel.swift` — **수정 금지**. `startSession` / `stopSession` 시그니처 유지.
- `project.yml` — **`INFOPLIST_KEY_NSCameraUsageDescription` 한 줄만 갱신**. 다른 키 / target / scheme 수정 금지.
- `Mofit.xcodeproj/project.pbxproj` — xcodegen 이 재생성. 직접 편집 금지.
- `MofitTests/CoachingSampleGeneratorTests.swift` — **불변**. 이번 phase 는 새 파일 1개만 추가.

**목표**: `TrackingView` 상단 권한 분기 + `HomeView` 배지 + `CameraPermissionResolver.swift` 신규 + `CameraPermissionResolverTests.swift` 신규 + `project.yml` 1 라인 갱신 + `xcodegen generate` + build + test.

## 작업 내용

### 대상 파일 (정확히 4개 수정/신규 + 1개 xcodegen 재생성)

1. **부분 수정**: `Mofit/Views/Tracking/TrackingView.swift` (권한 분기 + 폴백 subview + requestInline subview)
2. **부분 수정**: `Mofit/Views/Home/HomeView.swift` (배지 + scenePhase hook)
3. **부분 수정**: `project.yml` (NSCameraUsageDescription 카피 갱신)
4. **신규 생성**: `Mofit/Views/Tracking/CameraPermissionResolver.swift` (Foundation-only pure struct + enum)
5. **신규 생성**: `MofitTests/CameraPermissionResolverTests.swift` (4 XCTest 케이스)
6. **재생성**: `Mofit.xcodeproj/project.pbxproj` (xcodegen 자동)

### 목적

iter 8 persona 가 "설치 → 카메라 권한 거부 → 빈 검은 화면 → 이탈" 경로를 제거한다. 해결책은 `CameraPermissionResolver` 로 권한 상태를 3분기 enum 에 매핑하고, `TrackingView` 가 이 decision 에 따라 기존 트래킹 body / 풀스크린 폴백 카드 / requestInline 중 하나만 렌더하도록 하는 것. `HomeView` 는 `.denied` / `.restricted` 때만 배지로 힌트.

### 구현 요구사항

#### 1) `Mofit/Views/Tracking/CameraPermissionResolver.swift` — 신규 생성

파일 전체를 아래 내용으로 생성한다. Foundation-only pure struct + enum. AVFoundation 은 `AVAuthorizationStatus` enum 값 접근만을 위한 import — runtime API (`AVCaptureDevice.authorizationStatus` / `requestAccess` / `AVCaptureSession`) 호출 금지.

```swift
// iter 8 (task 7-camera-permission-recovery): 카메라 권한 상태 → 분기 decision 매핑.
// Foundation + AVFoundation(AVAuthorizationStatus enum 접근 한정). runtime API 호출 금지.
// spec §2.8, ADR-019.

import AVFoundation
import Foundation

enum CameraPermissionDecision: Equatable {
    case ready
    case requestInline
    case showSettingsFallback
}

struct CameraPermissionResolver {
    static func decide(status: AVAuthorizationStatus) -> CameraPermissionDecision {
        switch status {
        case .authorized:
            return .ready
        case .notDetermined:
            return .requestInline
        case .denied, .restricted:
            return .showSettingsFallback
        @unknown default:
            return .showSettingsFallback
        }
    }
}
```

**핵심 제약**:
- 파일 최상단 1줄 코멘트 필수 (grep 가드 대상 아니지만 git blame 추적용).
- `import AVFoundation` 허용 (AVAuthorizationStatus enum 리터럴 매칭용). `import SwiftUI` / `import SwiftData` / `import UIKit` / `import Vision` 금지.
- `@Model` / `@Query` / `@Published` / `ObservableObject` / `AVCaptureDevice` / `AVCaptureSession` 심볼 사용 금지 (runtime API 미호출 원칙).
- `CameraPermissionDecision` 은 associated value 없는 enum 이라 자동 Equatable 파생. 현재 associated value 없으므로 `: Equatable` 명시 선언 허용 (XCTestAssertEqual 가독성). 향후 associated value 추가 시 명시 `: Equatable` 필요 — 구현 phase 주석은 별도로 추가하지 말 것 (주석 scope creep 방지).
- `@unknown default: return .showSettingsFallback` — fail-closed. 이 fallback 은 Apple SDK 향후 enum 추가 시 방어.
- 접근 제어자 전부 internal (default). public 노출 금지. `@testable import Mofit` 로 테스트 접근.

#### 2) `Mofit/Views/Tracking/TrackingView.swift` — 상단 권한 분기

##### 2-a) 파일 최상단 import 추가

기존 L1~2:

```swift
import SwiftData
import SwiftUI
```

아래로 교체 (AVFoundation + UIKit 추가):

```swift
import AVFoundation
import SwiftData
import SwiftUI
import UIKit
```

- `UIKit` — `UIApplication.shared.open(URL)` / `UIApplication.shared.isIdleTimerDisabled` 직접 참조를 위함. 기존 L51 `UIApplication.shared.isIdleTimerDisabled = true` 는 SwiftUI-only 환경에서도 컴파일되지만, 딥링크 API 호출을 위해 명시적 import.
- `AVFoundation` — `AVCaptureDevice.authorizationStatus(for: .video)` / `requestAccess(for: .video)` 호출용.

##### 2-b) `@State` 추가 + `@Environment(\.scenePhase)` 추가

기존 L10~11 (StateObject + Binding) 다음 라인에 `@State` + `@Environment` 추가. 파일 상단 properties 블록:

```swift
struct TrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var authManager: AuthManager
    let exerciseType: String
    @StateObject private var viewModel: TrackingViewModel
    @Binding var showConfetti: Bool
    @State private var showSaveError = false
    @State private var permissionDecision: CameraPermissionDecision = CameraPermissionResolver.decide(
        status: AVCaptureDevice.authorizationStatus(for: .video)
    )
```

- `@Environment(\.scenePhase)` 는 `@Environment(\.dismiss)` 바로 아래. SwiftUI convention 상 Environment 들끼리 인접.
- `permissionDecision` 의 초기값은 뷰 init 시점 상태에서 resolve. SwiftUI 가 View struct 를 재생성할 수 있지만 `@State` 가 persistent storage 에 값을 보관.

##### 2-c) `body` 최상단 권한 분기 도입

기존 L19~73 의 `body` 본체를 아래 구조로 교체한다. 기존 GeometryReader 블록 통째로 `readyContent` 라는 private `@ViewBuilder` 로 이동하지 말고, `body` 내부 switch 분기로 유지하되 `.ready` 브랜치 안에 **원본 GeometryReader { ZStack { ... } } 코드 그대로** 배치. subview 추출 금지 (CTO 조건 4 — 추상화 금지).

교체 후 body 구조:

```swift
    var body: some View {
        Group {
            switch permissionDecision {
            case .ready:
                readyContent
            case .requestInline:
                requestInlineContent
            case .showSettingsFallback:
                settingsFallbackContent
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .alert("저장 실패", isPresented: $showSaveError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.saveError ?? "운동 기록 저장에 실패했습니다")
        }
        .onChange(of: viewModel.saveError) { _, error in
            if error != nil {
                showSaveError = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                permissionDecision = CameraPermissionResolver.decide(
                    status: AVCaptureDevice.authorizationStatus(for: .video)
                )
            }
        }
    }
```

- `.preferredColorScheme(.dark)` / `.statusBarHidden()` / `.alert` / `.onChange(viewModel.saveError)` modifier 는 기존 L61~72 의 것 그대로 `Group` 에 부착. 3 브랜치 모두 dark + statusBarHidden 일관.
- `.onChange(of: scenePhase)` 는 신규. `.active` 전이 시 권한 재조회 (사용자 설정 앱 갔다 옴 복귀).

##### 2-d) `@ViewBuilder` 로 3 브랜치 subview 정의

기존 subview 블록(`overlayContent` ~ `formatTime`) **위** 에 `readyContent`, `requestInlineContent`, `settingsFallbackContent` 3 개 `@ViewBuilder` 프로퍼티를 추가한다.

**`readyContent`** — 기존 L20~60 GeometryReader { ZStack { ... } } 블록 그대로 이동:

```swift
    @ViewBuilder
    private var readyContent: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreviewView(session: viewModel.captureSession)
                    .ignoresSafeArea()

                overlayContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if case .tracking = viewModel.state {
                    jointOverlay
                }

                if let hint = viewModel.diagnosticHint {
                    hintBanner(hint: hint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 120)
                }

                closeButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 60)
                    .padding(.leading, 20)

                stopButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 60)
            }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.handleScreenTap() }
            .onAppear {
                viewModel.viewSize = geometry.size
                UIApplication.shared.isIdleTimerDisabled = true
                viewModel.startSession(modelContext: modelContext, isLoggedIn: authManager.isLoggedIn)
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: geometry.size) { _, newSize in
                viewModel.viewSize = newSize
            }
        }
    }
```

- `startSession` / `isIdleTimerDisabled = true` 가드는 `.ready` 브랜치 `.onAppear` 안에서만 호출. `.requestInline` / `.showSettingsFallback` 에서는 호출되지 않아 AVCaptureSession.startRunning() 실행 0, 빈 preview 0.
- 기존 L61~72 의 `.preferredColorScheme` / `.statusBarHidden` / `.alert` / `.onChange(viewModel.saveError)` modifier 들은 `readyContent` 에 부착하지 마라 — `body` 의 Group 에 부착했다.

**`requestInlineContent`** — `.notDetermined` 브랜치. 시스템 prompt 호출 + completion hook.

```swift
    @ViewBuilder
    private var requestInlineContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .tint(.white)
                Text("카메라 권한을 확인하고 있어요")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                Task { @MainActor in
                    permissionDecision = CameraPermissionResolver.decide(
                        status: AVCaptureDevice.authorizationStatus(for: .video)
                    )
                }
            }
        }
    }
```

- `AVCaptureDevice.requestAccess(for: .video)` completion 은 background queue 에서 호출. `Task { @MainActor in ... }` 로 메인 스레드 전이 후 decision 재계산.
- completion 파라미터 `granted: Bool` 대신 `_` 로 받고 `authorizationStatus` 를 다시 조회하는 이유: resolver 1 곳으로 매핑 집중. granted=true 시 `.authorized` 가 반환될 것으로 기대.
- "카메라 권한을 확인하고 있어요" 는 system prompt 가 뜨는 동안 일시 표시. 유저가 "허용" 선택 시 completion → `.ready` 로 즉시 전환. "거부" 선택 시 → `.showSettingsFallback` 으로 전환.
- 추가 버튼/이미지 금지 — system prompt 가 이미 UI 를 가리므로 fallback 텍스트만.

**`settingsFallbackContent`** — `.denied` / `.restricted` 브랜치. 풀스크린 폴백 카드.

```swift
    @ViewBuilder
    private var settingsFallbackContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.neonGreen)

                VStack(spacing: 12) {
                    Text("카메라 권한이 필요해요")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Mofit은 iPhone 카메라로 스쿼트 자세·횟수를 분석합니다. 영상은 저장/전송되지 않고 온디바이스에서 즉시 폐기됩니다.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("설정에서 권한 켜기")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.darkBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Theme.neonGreen)
                            .cornerRadius(12)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("홈으로 돌아가기")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
                .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
```

- `Theme.neonGreen` / `Theme.darkBackground` 는 기존 사용 중인 심볼 (HomeView / TrackingView 참조). 신규 Theme 토큰 추가 금지.
- `UIApplication.openSettingsURLString` URL force-unwrap 회피를 위해 `if let url = URL(string: ...)` 가드. Swift 최적화로 런타임 오류 방지.
- Secondary button 스타일은 minimal (배경 없음, 텍스트만) — Primary CTA 와 시각 위계 확보.
- `camera.fill` SF Symbol — 기본 제공, 추가 asset 금지.

##### 2-e) 기존 subview 블록 불변 확인

L75~230 의 `overlayContent`, `idleOverlay`, `countdownOverlay`, `trackingOverlay`, `setCompleteOverlay`, `jointOverlay`, `closeButton`, `stopButton`, `hintBanner`, `formatTime` **전부 불변**. 한 줄도 건드리지 마라. 들여쓰기 / Korean 문자열 / SF Symbol 이름 / Theme 참조 전부 그대로.

#### 3) `Mofit/Views/Home/HomeView.swift` — 배지 + scenePhase hook

##### 3-a) 파일 최상단 import 추가

기존 L1~2:

```swift
import SwiftData
import SwiftUI
```

아래로 교체:

```swift
import AVFoundation
import SwiftData
import SwiftUI
```

##### 3-b) `@State` + `@Environment` 추가

기존 `@State private var showConfetti = false` (L15 부근) **다음** 에 아래 추가:

```swift
    @Environment(\.scenePhase) private var scenePhase
    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
```

- `cameraStatus` 초기값은 뷰 생성 시점 AVCaptureDevice.authorizationStatus. `@State` storage 에 보관.
- `scenePhase` 는 .onChange hook 에서 재조회 트리거.

##### 3-c) `startButton` 을 VStack 으로 감싸 배지 부착

기존 L73~75 (ScrollView > VStack 내부):

```swift
                        startButton
                            .padding(.horizontal)
                            .padding(.top, 32)
```

을 아래로 교체:

```swift
                        VStack(spacing: 8) {
                            startButton
                            cameraPermissionBadge
                        }
                        .padding(.horizontal)
                        .padding(.top, 32)
```

- padding modifier 는 VStack 에 부착 (기존 startButton 에 부착했던 것).
- `cameraPermissionBadge` 는 아래 3-d 에서 정의. `.denied` / `.restricted` 일 때만 실제 뷰 렌더, 그 외는 `EmptyView`.

##### 3-d) 새 private 프로퍼티 2개 추가 — `cameraPermissionBadge` + `refreshCameraStatus` helper

기존 `startButton` 프로퍼티(L163~176) 정의 **바로 뒤** 에 아래 추가:

```swift
    @ViewBuilder
    private var cameraPermissionBadge: some View {
        if cameraStatus == .denied || cameraStatus == .restricted {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("카메라 권한 필요")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.15))
            .cornerRadius(8)
        } else {
            EmptyView()
        }
    }

    private func refreshCameraStatus() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
```

- `.denied` / `.restricted` **외** 상태(.authorized / .notDetermined) 에서는 `EmptyView()` — 배지 미노출. `.notDetermined` 배지 노출 금지 (CTO 조건 2, reject_trigger 재트리거 방지).
- 배지 카피 "카메라 권한 필요" 는 고정 (requirement 원문).
- `exclamationmark.triangle.fill` SF Symbol — 기본 제공.
- Color.orange — 기존 Theme 토큰(neonGreen/darkBackground/cardBackground/textPrimary/textSecondary) 에 warning 컬러가 없어 시스템 orange 사용. Theme 신규 토큰 추가 금지(CTO 조건 4 — 추상화 금지).

##### 3-e) `.onAppear` + `.onChange(of: scenePhase)` hook 추가

기존 `.onChange(of: showTracking)` modifier (L116~120 부근) 뒤에 2 개 modifier 추가:

```swift
        .onAppear {
            refreshCameraStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshCameraStatus()
            }
        }
```

- 삽입 위치: `.onChange(of: showTracking)` 블록 **뒤** . `.fullScreenCover($showTracking)` 와 `.task { await loadServerData() }` 사이를 건드리지 마라.
- `.onAppear` 는 기존 다른 .onAppear 와 충돌 없음 (ZStack level `.fullScreenCover` 는 sheet 전환 시 배경 뷰의 onAppear 를 재호출하지 않을 수 있어, scenePhase hook 을 병행).
- 트래킹 뷰에서 홈 복귀 시점에는 `.onChange(of: showTracking)` 이 이미 refresh 트리거 역할 → 이때도 status 를 재조회하도록 기존 handler 를 수정하지 말고 `.onAppear` + scenePhase 조합에 의존. 홈 뷰가 다시 포커스되면 scenePhase 가 .active 상태 유지 + .active 재발생 없음이므로 .onAppear 가 주 경로.

##### 3-f) 기타 경로 불변 검증 (수정 금지)

다음 경로는 이번 phase scope 외:

- `topBar` / `todaySummaryCard` / `summaryItem` / `formatDuration` / `ConfettiView` / `ConfettiParticle`
- `todaySessions` / `todayServerSessions` / `todayTotalSets` / `todayTotalReps` / `todayTotalDuration` / `hasTodaySessions`
- `loadServerData` / `parseISO8601Date`
- `.fullScreenCover($showProfileEdit)` / `.fullScreenCover($showTracking)` 블록
- `.task { await loadServerData() }` / `.onChange(of: authManager.isLoggedIn)` / `.onChange(of: showTracking)`

전부 한 줄도 건드리지 마라.

#### 4) `project.yml` — NSCameraUsageDescription 카피 갱신

기존 L27:

```yaml
        INFOPLIST_KEY_NSCameraUsageDescription: "운동 자세를 추적하기 위해 카메라가 필요합니다"
```

을 아래로 교체:

```yaml
        INFOPLIST_KEY_NSCameraUsageDescription: "Mofit은 iPhone 카메라로 스쿼트 자세·횟수를 분석합니다. 영상은 저장/전송되지 않고 온디바이스에서 즉시 폐기됩니다."
```

- 정확히 1 라인만 수정. 다른 `INFOPLIST_KEY_*` / target / scheme 설정 **전부 불변**.
- 이 카피는 spec §2.8 폴백 카드 서브카피와 **완전 일치**해야 한다 (system prompt ↔ 폴백 카드 일관성).

#### 5) `MofitTests/CameraPermissionResolverTests.swift` — 신규 생성

`MofitTests/` 디렉토리는 이미 존재 (iter 7 `CoachingSampleGeneratorTests.swift` 생성 시 신설). 추가 디렉토리 생성 불필요. 아래 내용을 정확히 담은 파일을 생성한다.

```swift
import AVFoundation
import XCTest
@testable import Mofit

final class CameraPermissionResolverTests: XCTestCase {

    func test_decide_authorized_returnsReady() {
        XCTAssertEqual(
            CameraPermissionResolver.decide(status: .authorized),
            .ready
        )
    }

    func test_decide_denied_returnsShowSettingsFallback() {
        XCTAssertEqual(
            CameraPermissionResolver.decide(status: .denied),
            .showSettingsFallback
        )
    }

    func test_decide_restricted_returnsShowSettingsFallback() {
        XCTAssertEqual(
            CameraPermissionResolver.decide(status: .restricted),
            .showSettingsFallback
        )
    }

    func test_decide_notDetermined_returnsRequestInline() {
        XCTAssertEqual(
            CameraPermissionResolver.decide(status: .notDetermined),
            .requestInline
        )
    }
}
```

- `import AVFoundation` — `AVAuthorizationStatus` enum 값 접근. runtime API 미호출.
- `@testable import Mofit` — `CameraPermissionResolver` / `CameraPermissionDecision` 이 internal 접근 제어자.
- **테스트 4개만**. `.authorized` / `.denied` / `.restricted` / `.notDetermined` 전 케이스 커버. `@unknown default` 추가 테스트 금지 (iter 8 CTO 조건 5 범위 준수 — enum assert 만).
- XCTestCase 상속, `final class`, `func test_*` naming convention 엄수.

#### 6) xcodegen generate

위 1~5 변경 완료 후 아래 실행:

```bash
xcodegen generate
```

- `project.yml` glob 기반이라 `Mofit/Views/Tracking/CameraPermissionResolver.swift` 1 파일 + `MofitTests/CameraPermissionResolverTests.swift` 1 파일이 추가되어 pbxproj 재생성 diff 가 발생 (file ref 추가).
- 신규 target / scheme 추가 없음 (`Mofit` + `MofitTests` 기존 target 재사용).

### 구현 후 코드 트레이스 검증 (XCTest 자동 검증과 병행)

XCTest 가 자동 검증하지만, AC 실행 전에 아래 4개 시나리오를 에이전트가 코드 흐름으로도 수학적으로 검증하라:

1. **테스트 1 — `.authorized`**: `CameraPermissionResolver.decide(status: .authorized)` → switch `.authorized` branch → return `.ready`. XCTAssertEqual pass.
2. **테스트 2 — `.denied`**: switch `.denied, .restricted` branch → return `.showSettingsFallback`. pass.
3. **테스트 3 — `.restricted`**: 테스트 2 와 동일 branch. return `.showSettingsFallback`. pass.
4. **테스트 4 — `.notDetermined`**: switch `.notDetermined` branch → return `.requestInline`. pass.

추가로 아래 3개 런타임 시나리오를 코드 트레이스로 확인:

5. **첫 설치 유저 (`.notDetermined`)**: `TrackingView.onAppear` → permissionDecision = `.requestInline` → `requestInlineContent.onAppear` → `AVCaptureDevice.requestAccess(for: .video)` → system prompt. 허용 시 completion callback → `Task { @MainActor in permissionDecision = .ready }` → readyContent 렌더 → .onAppear → `viewModel.startSession(...)`. 거부 시 completion → `permissionDecision = .showSettingsFallback` → 폴백 카드 렌더.
6. **거부 후 재진입 (`.denied`)**: HomeView 에서 `cameraPermissionBadge` 가 `.denied` 브랜치 렌더. 유저가 "스쿼트 시작" 탭 → TrackingView.onAppear → permissionDecision 초기값 = `.showSettingsFallback` → 폴백 카드 즉시 렌더 (빈 검은 preview 회피). "설정에서 권한 켜기" 탭 → UIApplication.openSettingsURLString → 설정 앱 → 권한 활성화 → 앱 복귀 → `.onChange(of: scenePhase) .active` → `permissionDecision = .ready` → readyContent 렌더 → startSession 호출.
7. **HomeView 배지 `.notDetermined` 미노출**: 첫 설치 유저가 TrackingView 에 진입하지 않은 상태. `cameraStatus == .notDetermined` → `cameraPermissionBadge` 의 `if` 조건 미충족 → `EmptyView()` 렌더 → 배지 비노출. CTO 조건 2 엄수.

불일치 시 구현 수정. 특히 3-e `.onChange(of: scenePhase)` hook 의 `.active` 전이 조건, 2-c `body` switch 의 3-way 분기 구조, 2-d 의 `readyContent` 내부 `.onAppear` 의 `startSession` 호출 위치를 재확인.

## Acceptance Criteria

아래 커맨드를 순서대로 실행하여 모두 exit 0 이어야 한다.

```bash
# 1) CameraPermissionResolver.swift 신규 생성 검증
test -f Mofit/Views/Tracking/CameraPermissionResolver.swift
grep -F 'iter 8 (task 7-camera-permission-recovery)' Mofit/Views/Tracking/CameraPermissionResolver.swift
grep -F 'enum CameraPermissionDecision: Equatable' Mofit/Views/Tracking/CameraPermissionResolver.swift
grep -F 'case ready' Mofit/Views/Tracking/CameraPermissionResolver.swift
grep -F 'case requestInline' Mofit/Views/Tracking/CameraPermissionResolver.swift
grep -F 'case showSettingsFallback' Mofit/Views/Tracking/CameraPermissionResolver.swift
grep -F 'struct CameraPermissionResolver' Mofit/Views/Tracking/CameraPermissionResolver.swift
grep -F 'static func decide(status: AVAuthorizationStatus) -> CameraPermissionDecision' Mofit/Views/Tracking/CameraPermissionResolver.swift
grep -F '@unknown default' Mofit/Views/Tracking/CameraPermissionResolver.swift
grep -F 'return .showSettingsFallback' Mofit/Views/Tracking/CameraPermissionResolver.swift

# 2) CameraPermissionResolver.swift import 제약
grep -F 'import AVFoundation' Mofit/Views/Tracking/CameraPermissionResolver.swift
grep -F 'import Foundation' Mofit/Views/Tracking/CameraPermissionResolver.swift
! grep -F 'import SwiftUI' Mofit/Views/Tracking/CameraPermissionResolver.swift
! grep -F 'import SwiftData' Mofit/Views/Tracking/CameraPermissionResolver.swift
! grep -F 'import UIKit' Mofit/Views/Tracking/CameraPermissionResolver.swift
! grep -F 'import Vision' Mofit/Views/Tracking/CameraPermissionResolver.swift

# 3) CameraPermissionResolver.swift runtime API 호출 금지
! grep -F 'AVCaptureDevice.authorizationStatus' Mofit/Views/Tracking/CameraPermissionResolver.swift
! grep -F 'AVCaptureDevice.requestAccess' Mofit/Views/Tracking/CameraPermissionResolver.swift
! grep -F 'AVCaptureSession' Mofit/Views/Tracking/CameraPermissionResolver.swift

# 4) TrackingView.swift 권한 분기 도입
grep -F 'import AVFoundation' Mofit/Views/Tracking/TrackingView.swift
grep -F '@Environment(\.scenePhase)' Mofit/Views/Tracking/TrackingView.swift
grep -F '@State private var permissionDecision: CameraPermissionDecision' Mofit/Views/Tracking/TrackingView.swift
grep -F 'CameraPermissionResolver.decide(' Mofit/Views/Tracking/TrackingView.swift
grep -F 'switch permissionDecision' Mofit/Views/Tracking/TrackingView.swift
grep -F 'case .ready:' Mofit/Views/Tracking/TrackingView.swift
grep -F 'case .requestInline:' Mofit/Views/Tracking/TrackingView.swift
grep -F 'case .showSettingsFallback:' Mofit/Views/Tracking/TrackingView.swift
grep -F 'private var readyContent: some View' Mofit/Views/Tracking/TrackingView.swift
grep -F 'private var requestInlineContent: some View' Mofit/Views/Tracking/TrackingView.swift
grep -F 'private var settingsFallbackContent: some View' Mofit/Views/Tracking/TrackingView.swift
grep -F 'AVCaptureDevice.requestAccess(for: .video)' Mofit/Views/Tracking/TrackingView.swift
grep -F 'UIApplication.openSettingsURLString' Mofit/Views/Tracking/TrackingView.swift
grep -F '카메라 권한이 필요해요' Mofit/Views/Tracking/TrackingView.swift
grep -F 'Mofit은 iPhone 카메라로 스쿼트 자세·횟수를 분석합니다. 영상은 저장/전송되지 않고 온디바이스에서 즉시 폐기됩니다.' Mofit/Views/Tracking/TrackingView.swift
grep -F '설정에서 권한 켜기' Mofit/Views/Tracking/TrackingView.swift
grep -F '홈으로 돌아가기' Mofit/Views/Tracking/TrackingView.swift

# 5) TrackingView.swift scenePhase hook
grep -F '.onChange(of: scenePhase)' Mofit/Views/Tracking/TrackingView.swift
grep -F 'newPhase == .active' Mofit/Views/Tracking/TrackingView.swift

# 6) TrackingView.swift — startSession 가드 위치 (.ready 브랜치 내부)
# startSession 호출이 readyContent 의 .onAppear 안에 1곳만 있는지
test "$(grep -cF 'viewModel.startSession(' Mofit/Views/Tracking/TrackingView.swift)" -eq 1

# 7) TrackingView.swift — 기존 subview 블록 불변 (grep 존재만 확인)
grep -F 'private var overlayContent: some View' Mofit/Views/Tracking/TrackingView.swift
grep -F 'private var idleOverlay' Mofit/Views/Tracking/TrackingView.swift
grep -F 'private func countdownOverlay(seconds: Int)' Mofit/Views/Tracking/TrackingView.swift
grep -F 'private var trackingOverlay' Mofit/Views/Tracking/TrackingView.swift
grep -F 'private var setCompleteOverlay' Mofit/Views/Tracking/TrackingView.swift
grep -F 'private var jointOverlay' Mofit/Views/Tracking/TrackingView.swift
grep -F 'private var closeButton' Mofit/Views/Tracking/TrackingView.swift
grep -F 'private var stopButton' Mofit/Views/Tracking/TrackingView.swift
grep -F 'private func hintBanner(hint: DiagnosticHint)' Mofit/Views/Tracking/TrackingView.swift
grep -F 'private func formatTime' Mofit/Views/Tracking/TrackingView.swift

# 8) HomeView.swift 배지 + hook
grep -F 'import AVFoundation' Mofit/Views/Home/HomeView.swift
grep -F '@Environment(\.scenePhase)' Mofit/Views/Home/HomeView.swift
grep -F '@State private var cameraStatus: AVAuthorizationStatus' Mofit/Views/Home/HomeView.swift
grep -F 'cameraPermissionBadge' Mofit/Views/Home/HomeView.swift
grep -F '카메라 권한 필요' Mofit/Views/Home/HomeView.swift
grep -F 'cameraStatus == .denied || cameraStatus == .restricted' Mofit/Views/Home/HomeView.swift
grep -F 'refreshCameraStatus()' Mofit/Views/Home/HomeView.swift
grep -F '.onChange(of: scenePhase)' Mofit/Views/Home/HomeView.swift
grep -F 'newPhase == .active' Mofit/Views/Home/HomeView.swift
grep -F 'AVCaptureDevice.authorizationStatus(for: .video)' Mofit/Views/Home/HomeView.swift

# 9) HomeView.swift — .notDetermined 배지 노출 금지 증거
! grep -F 'cameraStatus == .notDetermined' Mofit/Views/Home/HomeView.swift

# 10) HomeView.swift — startButton 블록 불변 (탭 시 showTracking = true)
grep -F 'Text("스쿼트 시작")' Mofit/Views/Home/HomeView.swift
grep -F 'showTracking = true' Mofit/Views/Home/HomeView.swift

# 11) project.yml — NSCameraUsageDescription 카피 갱신
grep -F 'Mofit은 iPhone 카메라로 스쿼트 자세·횟수를 분석합니다. 영상은 저장/전송되지 않고 온디바이스에서 즉시 폐기됩니다.' project.yml
! grep -F '운동 자세를 추적하기 위해 카메라가 필요합니다' project.yml

# 12) project.yml — 다른 키/target/scheme 불변
grep -F 'PRODUCT_BUNDLE_IDENTIFIER: com.mofit.app' project.yml
grep -F 'PRODUCT_BUNDLE_IDENTIFIER: com.mofit.tests' project.yml
grep -F 'INFOPLIST_KEY_UIUserInterfaceStyle: Dark' project.yml
grep -F 'type: bundle.unit-test' project.yml

# 13) MofitTests 파일 존재 + 내용 검증
test -f MofitTests/CameraPermissionResolverTests.swift
grep -F '@testable import Mofit' MofitTests/CameraPermissionResolverTests.swift
grep -F 'import AVFoundation' MofitTests/CameraPermissionResolverTests.swift
grep -F 'final class CameraPermissionResolverTests: XCTestCase' MofitTests/CameraPermissionResolverTests.swift
grep -F 'func test_decide_authorized_returnsReady()' MofitTests/CameraPermissionResolverTests.swift
grep -F 'func test_decide_denied_returnsShowSettingsFallback()' MofitTests/CameraPermissionResolverTests.swift
grep -F 'func test_decide_restricted_returnsShowSettingsFallback()' MofitTests/CameraPermissionResolverTests.swift
grep -F 'func test_decide_notDetermined_returnsRequestInline()' MofitTests/CameraPermissionResolverTests.swift
grep -F 'CameraPermissionResolver.decide(status: .authorized)' MofitTests/CameraPermissionResolverTests.swift
grep -F 'CameraPermissionResolver.decide(status: .denied)' MofitTests/CameraPermissionResolverTests.swift
grep -F 'CameraPermissionResolver.decide(status: .restricted)' MofitTests/CameraPermissionResolverTests.swift
grep -F 'CameraPermissionResolver.decide(status: .notDetermined)' MofitTests/CameraPermissionResolverTests.swift
# 테스트 4개만
test "$(grep -cE '^\s+func test_' MofitTests/CameraPermissionResolverTests.swift)" -eq 4

# 14) 변경 범위 — Mofit/ 하위 정확히 3개 파일
CHANGED_MOFIT=$(git diff --name-only HEAD -- Mofit/ | sort)
EXPECTED_MOFIT=$(printf 'Mofit/Views/Home/HomeView.swift\nMofit/Views/Tracking/CameraPermissionResolver.swift\nMofit/Views/Tracking/TrackingView.swift\n' | sort)
test "$CHANGED_MOFIT" = "$EXPECTED_MOFIT"

# 15) 모델 / 서비스 / 카메라 / 다른 View 전부 불변
git diff --quiet HEAD -- Mofit/Models/
git diff --quiet HEAD -- Mofit/Services/
git diff --quiet HEAD -- Mofit/Camera/
git diff --quiet HEAD -- Mofit/App/
git diff --quiet HEAD -- Mofit/ViewModels/
git diff --quiet HEAD -- Mofit/Views/Onboarding/
git diff --quiet HEAD -- Mofit/Views/Profile/
git diff --quiet HEAD -- Mofit/Views/Records/
git diff --quiet HEAD -- Mofit/Views/Coaching/
git diff --quiet HEAD -- Mofit/Views/Auth/
git diff --quiet HEAD -- Mofit/Utils/
git diff --quiet HEAD -- Mofit/Config/

# 16) docs / server / scripts / README 불변
git diff --quiet HEAD -- docs/ server/ scripts/ README.md

# 17) MofitTests/ 내 신규 파일 1개만 추가 (기존 CoachingSampleGeneratorTests.swift 불변)
git diff --quiet HEAD -- MofitTests/CoachingSampleGeneratorTests.swift
test "$(find MofitTests -type f -name '*.swift' | wc -l | tr -d ' ')" -eq 2

# 18) 신규 파일 금지 범위
test ! -f Mofit/Services/CameraPermissionService.swift
test ! -f Mofit/Camera/CameraPermissionManager.swift
test ! -f Mofit/Utils/PermissionKit.swift
test ! -f Mofit/Views/Camera/CameraPermissionView.swift

# 19) NotificationCenter 권한 관찰 금지 (CTO 조건 4 — 단일 뷰 로컬 상태)
! grep -F 'NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActive' Mofit/Views/Tracking/TrackingView.swift
! grep -F 'NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActive' Mofit/Views/Home/HomeView.swift

# 20) xcodegen 재생성 + xcodebuild build 성공
xcodegen generate
xcodebuild \
  -scheme Mofit \
  -destination 'generic/platform=iOS Simulator' \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | tail -80

# 21) xcodebuild test 성공 — destination 동적 선택 (iPhone simulator, 실패 시 iPhone 16 폴백)
SIMULATOR_NAME=$(xcrun simctl list devices available --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    if 'iOS' not in runtime:
        continue
    for d in devices:
        if d.get('isAvailable') and 'iPhone' in d.get('name', ''):
            print(d['name'])
            sys.exit(0)
" 2>/dev/null)
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
echo "Using simulator: ${SIMULATOR_NAME}"
xcodebuild \
  -scheme Mofit \
  -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  test \
  | tail -160
```

xcodebuild build 출력 말미에 `** BUILD SUCCEEDED **` 가 찍혀야 하고, xcodebuild test 출력 말미에 `** TEST SUCCEEDED **` 가 찍혀야 한다.

테스트 실행 시 총 6 케이스 실행 (기존 `CoachingSampleGeneratorTests` 2개 + 신규 `CameraPermissionResolverTests` 4개).

AC 20 와 21 둘 다 성공해야 한다 (build 는 generic destination 으로, test 는 concrete simulator destination 으로 분리 실행). xcrun simctl 이 없거나 사용 가능한 simulator 가 전혀 없으면 로그를 `error_message` 에 기록 후 에러 상태로 기록.

## AC 검증 방법

위 AC 커맨드를 순서대로 실행하라. 모두 통과하면 `tasks/7-camera-permission-recovery/index.json` 의 phase 1 status 를 `"completed"` 로 변경하라.
수정 3회 이상 시도해도 실패하면 status 를 `"error"` 로 변경하고, 해당 phase 객체에 `"error_message"` 필드로 에러 내용을 기록하라.

xcodebuild test 가 simulator runtime 부재로 실패할 경우:
- `xcrun simctl list runtimes` 로 설치된 runtime 확인.
- 사용 가능 device 가 전무하면 `xcrun simctl create "iPhone 15" "iPhone 15" "iOS 17.0"` 로 생성 시도.
- 그래도 안 되면 error 기록 후 중단 — 테스트 인프라 부재는 이번 task 의 AC 21 scope 외 (`docs/testing.md` 의 "CI 실행" 섹션에서 "destination 동적 선택" 방식 제안).

## 주의사항

- **`CameraManager.swift` 불변**: 권한 체크를 Manager 에 두면 책임 번짐(CTO 조건 4). `TrackingView` 가 권한 소비자이자 분기 책임자. 이 task 에서 Camera/ 디렉토리 안 건드린다.
- **`TrackingViewModel.swift` 불변**: `startSession(modelContext:isLoggedIn:)` / `stopSession(modelContext:isLoggedIn:)` / `handleScreenTap()` 시그니처 전부 유지. 권한 가드는 View 레이어에서만.
- **`@StateObject TrackingViewModel` 은 `.denied` 브랜치에서도 생성됨**: `TrackingView` struct init 시점에 StateObject 가 초기화되며 `TrackingViewModel.init` 내부에서 `CameraManager()` 도 생성된다. `CameraManager.init` 은 `sessionQueue.async { configureSession() }` 로 background 에서 device discovery 를 수행하지만, 실제 `startRunning()` 은 `.ready` 브랜치 `.onAppear` 의 `viewModel.startSession(...)` 에서만 호출되므로 `.denied` / `.requestInline` 브랜치에서 capture 프레임 0. 이 구조는 ADR-019 트레이드오프 (c) 로 문서화됨.
- **옵션 X (TrackingContent 자식 뷰 추출) 기각 유지**: 이번 task 는 subview 추출 없이 `body` switch 3-way 로 끝낸다. CTO 이전 턴 판정: "diff 230 lines 이동 → 회귀 위험 대비 실익 미검증. Y 로 구현 후 실기기에서 AVFoundation console warning 이 crash/hang 으로 이어지는 증거 관측 시 별건 티켓으로 X 전환". Phase 1 에이전트가 이 판정을 뒤집어 자체 판단으로 X 를 채택하지 마라.
- **requestAccess completion 은 background queue**: `AVCaptureDevice.requestAccess(for: .video) { granted in ... }` 의 completion 은 background dispatch. UI `@State` 갱신은 반드시 `Task { @MainActor in ... }` 로 메인 스레드 전이. granted 파라미터 직접 사용 대신 `AVCaptureDevice.authorizationStatus(for: .video)` 재조회 → resolver 통과 (분기 매핑 1 곳 집중).
- **`UIApplication.openSettingsURLString` force-unwrap 금지**: `URL(string: UIApplication.openSettingsURLString)` 는 Optional 반환. `if let url = ... { UIApplication.shared.open(url) }` 가드 필수.
- **폴백 카드 카피 사실 정합**: "영상은 저장/전송되지 않고 온디바이스에서 즉시 폐기됩니다" 는 `Mofit/Camera/CameraManager.swift` + `Mofit/Services/{PoseDetectionService,HandDetectionService}.swift` 의 sampleBuffer 처리 경로가 외부 전송 0 임을 전제 (Phase 0 시 검증 완료 — `URLSession` 호출부 `AuthManager/APIService/ClaudeAPIService` 와 교차 0). 구현 중 이 경로에 변경이 생기면 즉시 AC 실패로 간주하고 stop.
- **프라이버시 카피 3곳 동기화**: (a) `project.yml` `NSCameraUsageDescription`, (b) spec §2.8 폴백 카드 서브카피, (c) `TrackingView.settingsFallbackContent` 의 Text. 3곳이 문자 단위로 완전 일치해야 한다. 하나만 달라도 system prompt ↔ 폴백 카드 ↔ docs 불일치 → CTO 조건 3 위반.
- **HomeView `.notDetermined` 배지 노출 금지 (CTO 조건 2)**: `cameraStatus == .denied || cameraStatus == .restricted` 조건 외 branch 는 `EmptyView()`. `.notDetermined` 에서 배지가 보이면 reject_trigger 재트리거. AC 9 가 `! grep -F 'cameraStatus == .notDetermined'` 로 가드.
- **ADR-019 일반화 금지 재확인 (CTO 조건 1)**: 구현 코드의 주석 / grep-able 문자열 에 "다른 운동으로 재활용" / "pushup/situp 에도 적용 가능" 같은 일반화 문구 금지. spec/ADR 범위 "카메라 권한을 요구하는 모든 진입점에 동일 폴백" 수준 유지.
- **추상화 금지 (CTO 조건 4)**: `PermissionService` / `CameraPermissionManager` / `PermissionKit` 싱글톤 신설 금지. `NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification)` 금지 — `@Environment(\.scenePhase)` + `.onChange` 만 사용. AC 18, 19 가 가드.
- **실기기 QA 없음 (CTO 조건 5)**: `docs/user-intervention.md` 수정 금지. XCTest 4 케이스 자동 검증으로 완결.
- **AnalyticsService / Mixpanel 이벤트 추가 금지**: `camera_permission_denied` / `camera_permission_settings_tap` 같은 이벤트 추가 금지. `AnalyticsService` 파일 자체도 불변. 이번 task 는 행동 분석 대상 아님.
- **`CameraPermissionResolver` 확장 금지**: `decide(status:)` 한 함수만. `request()` / `observe()` / `openSettings()` 같은 메서드 추가 금지. 책임은 decision 매핑 1가지.
- **MofitTests 확장 금지**: 이번 phase 에서 `MofitTests/` 안에 `CameraPermissionResolverTests.swift` **외 다른 `.swift` 파일 생성 금지**. AC 17 의 `find MofitTests -type f -name '*.swift' | wc -l` 가 2 여야 한다 (기존 `CoachingSampleGeneratorTests.swift` + 신규 1). 다른 모듈 회고 테스트 추가는 scope creep.
- **xcodegen 재생성 후 pbxproj 수동 편집 금지**: Xcode 에서 파일을 손으로 추가한 것처럼 pbxproj 를 편집하지 마라. xcodegen 생성본 그대로 커밋.
- **폴백 카드 CTA 순서 고정**: Primary "설정에서 권한 켜기" (형광초록) → Secondary "홈으로 돌아가기" (텍스트 only). 역순 배치 / 제3의 CTA 추가 금지.
- **`readyContent.onAppear` 내부 3 라인 순서 보존**: `viewModel.viewSize = geometry.size` → `UIApplication.shared.isIdleTimerDisabled = true` → `viewModel.startSession(...)`. 기존 L50~53 순서 유지.
- **기존 `.onDisappear` 의 `isIdleTimerDisabled = false` 리셋 보존**: `readyContent` 안에 유지. `.showSettingsFallback` / `.requestInline` 브랜치에서는 `isIdleTimerDisabled` 를 건드리지 않음 (애초 true 로 설정되지 않으므로).
- **git status 클린 상태 시작**: dirty 면 error 기록 후 중단.
- **기존 테스트를 깨뜨리지 마라**: `CoachingSampleGeneratorTests` 2 케이스는 그대로 pass 해야 한다. 수정 금지.
