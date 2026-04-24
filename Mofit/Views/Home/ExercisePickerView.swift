import SwiftUI
import UIKit

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedExerciseName: String

    private let exercises: [(name: String, icon: String, locked: Bool)] = [
        ("스쿼트", "figure.strengthtraining.traditional", false),
        ("푸쉬업", "figure.strengthtraining.functional", true),
        ("싯업", "figure.core.training", true),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    @State private var showToast: Bool = false
    @State private var toastWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack {
            Theme.darkBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("운동 선택")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.top, 24)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(exercises, id: \.name) { exercise in
                        exerciseCard(name: exercise.name, icon: exercise.icon, locked: exercise.locked)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    Text("현재는 스쿼트만 지원합니다")
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .padding(.bottom, 40)
                        .transition(.opacity)
                } else {
                    EmptyView()
                }
            }
            .animation(.easeInOut, value: showToast)
        }
    }

    private func exerciseCard(name: String, icon: String, locked: Bool) -> some View {
        Button {
            if locked {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                toastWorkItem?.cancel()
                showToast = true
                let newItem = DispatchWorkItem { showToast = false }
                toastWorkItem = newItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: newItem)
            } else {
                selectedExerciseName = name
                dismiss()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundColor(selectedExerciseName == name && !locked ? Theme.neonGreen : Theme.textPrimary)

                    Text(name)
                        .font(.headline)
                        .foregroundColor(selectedExerciseName == name && !locked ? Theme.neonGreen : Theme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(Theme.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selectedExerciseName == name && !locked ? Theme.neonGreen : Color.clear, lineWidth: 2)
                )
                .opacity(locked ? 0.4 : 1.0)

                if locked {
                    Text("준비중")
                        .font(.caption2)
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.textSecondary.opacity(0.25))
                        .cornerRadius(8)
                        .padding(8)
                }
            }
        }
    }
}
