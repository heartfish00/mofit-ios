# docs-diff: tap-fallback

Baseline: `32f2b75`

## `docs/spec.md`

```diff
diff --git a/docs/spec.md b/docs/spec.md
index c002449..9228dc7 100644
--- a/docs/spec.md
+++ b/docs/spec.md
@@ -45,10 +45,10 @@ MofitApp
 
 ```
 idle
-  ── 손바닥 1초 ──▶ countdown(5s)
+  ── 손바닥 1초 OR 화면 탭 ──▶ countdown(5s)
                       └─ 완료 ──▶ tracking
 tracking
-  ── 손바닥 1초 ──▶ setComplete
+  ── 손바닥 1초 OR 화면 탭(rep > 0) ──▶ setComplete
                       └─ 표시 후 ──▶ countdown(5s) ──▶ tracking (다음 세트)
 any
   ── stop 버튼 ──▶ saveRecord ──▶ home (폭죽 연출)
```
