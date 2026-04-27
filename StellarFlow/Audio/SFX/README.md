# SFX (효과음)

짧은 효과음 파일 보관소

## 지원 포맷

- `.caf` (추천 — 짧은 효과음에 최적)
- `.wav`
- `.m4a`
- `.mp3`

## 예상 사용 트랙

| 이름 | 트리거 |
|---|---|
| `catch` | 행성 포획 성공 (Haptic과 동시 재생) |
| `launch` | 궤도에서 발사 |
| `boost` | Booster 행성 가속 피크 |
| `warn` | 파괴파/소행성 근접 경고 |
| `death` | 게임 오버 |
| `ui_tap` | 메뉴 버튼 탭 |

## 추가 절차

1. 파일을 이 폴더에 복사 (예: `catch.caf`)
2. `xcodegen generate`
3. 코드에서 `AudioManager.shared.playSFX(named: "catch")`로 재생

파일이 없으면 조용히 무시됨
