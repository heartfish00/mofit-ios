import AVFoundation
import SwiftData
import SwiftUI
import UIKit

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

    init(exerciseType: String, showConfetti: Binding<Bool>) {
        self.exerciseType = exerciseType
        self._showConfetti = showConfetti
        self._viewModel = StateObject(wrappedValue: TrackingViewModel(exerciseType: exerciseType))
    }

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

    @ViewBuilder
    private var overlayContent: some View {
        switch viewModel.state {
        case .idle:
            idleOverlay
        case .countdown(let seconds):
            countdownOverlay(seconds: seconds)
        case .tracking:
            trackingOverlay
        case .setComplete:
            setCompleteOverlay
        }
    }

    private var idleOverlay: some View {
        Text("손바닥을 보여주거나 화면을 탭하세요")
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(Color.black.opacity(0.6))
            .cornerRadius(16)
    }

    private func countdownOverlay(seconds: Int) -> some View {
        Text("\(seconds)")
            .font(.system(size: 120, weight: .bold))
            .foregroundColor(Theme.neonGreen)
    }

    private var trackingOverlay: some View {
        ZStack {
            VStack {
                HStack {
                    Text("세트 \(viewModel.currentSet)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)

                    Spacer()

                    Text(formatTime(viewModel.elapsedTime))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()
            }

            VStack(spacing: 8) {
                Text("\(viewModel.currentReps)")
                    .font(.system(size: 100, weight: .bold))
                    .foregroundColor(Theme.neonGreen)
                Text("끝낼 땐 화면을 탭하거나 손바닥을 보여주세요")
                    .font(.caption)
                    .foregroundColor(.white)
                    .opacity(0.7)
            }
        }
    }

    private var setCompleteOverlay: some View {
        Text("세트 \(viewModel.currentSet - 1) 완료!")
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(Color.black.opacity(0.6))
            .cornerRadius(16)
    }

    private var jointOverlay: some View {
        Canvas { context, _ in
            for point in viewModel.jointPoints {
                let rect = CGRect(
                    x: point.x - 6,
                    y: point.y - 6,
                    width: 12,
                    height: 12
                )
                context.fill(
                    Circle().path(in: rect),
                    with: .color(Theme.neonGreen)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private var closeButton: some View {
        Button {
            viewModel.stopSession(modelContext: modelContext, isLoggedIn: authManager.isLoggedIn)
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }

    private var stopButton: some View {
        Button {
            viewModel.stopSession(modelContext: modelContext, isLoggedIn: authManager.isLoggedIn)
            showConfetti = true
            dismiss()
        } label: {
            Image(systemName: "stop.fill")
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 72, height: 72)
                .background(Color.red)
                .clipShape(Circle())
        }
    }

    private func hintBanner(hint: DiagnosticHint) -> some View {
        HStack(spacing: 10) {
            Image(systemName: hint.iconName)
                .font(.subheadline)
                .foregroundColor(.white)
            Text(hint.message)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
