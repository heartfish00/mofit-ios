# QA Checklist — iteration 1 (exercise-coming-soon)

무인 세션에서는 시뮬레이터 실행이 불가능하다. 릴리즈 빌드 전 사용자가 디바이스/시뮬레이터에서 아래를 직접 확인한다.

- [ ] 1. 스쿼트 셀 탭 → ExercisePicker가 dismiss 되고 `selectedExerciseName`이 "스쿼트"로 설정됨.
- [ ] 2. 푸쉬업 셀 탭 → 바텀시트가 dismiss 되지 않고, 하단에 토스트 "현재는 스쿼트만 지원합니다"가 나타남.
- [ ] 3. 싯업 셀 탭 → 푸쉬업과 동일 동작(dismiss 없음 + 토스트).
- [ ] 4. 토스트가 1.5초 후 자동 소멸. 연속 tap 시 타이머가 reset되어 마지막 tap 기준 1.5초 후 사라짐.
- [ ] 5. locked 셀(푸쉬업/싯업)에 selected 하이라이트(네온그린 테두리/텍스트)가 절대 뜨지 않음. opacity는 0.4.
- [ ] 6. 푸쉬업/싯업 탭 시 가벼운 햅틱(light impact) 피드백이 한 번 발생.

결과는 각 항목 체크 + 실패 시 메모. 이 파일은 iteration 산출물로 git에 커밋된다.
