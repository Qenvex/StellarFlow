# BGM

배경음악(루프 재생용) 파일 보관 폴더

## 지원 포맷

- `.m4a` (추천 — 압축률/품질 균형)
- `.mp3`
- `.caf` (iOS 네이티브)
- `.wav`

## 파일명 규칙

`AudioManager.shared.playBGM(named: "메뉴")`를 호출할 때 쓰는 이름과 확장자 제외 파일명이 일치해야 함 `AudioManager`가 위 확장자들을 순서대로 탐색함

현재 게임에서 호출하는 트랙 이름:

| 이름 | 사용 씬 | 권장 분위기 |
|---|---|---|
| `menu` | MenuScene | 잔잔한 앰비언트 |
| `game` | GameScene | 드리프트감 있는 루프 |
| `gameover` | GameOverScene (선택) | 여운 있는 짧은 큐 |

## 추가 절차

1. 파일을 이 폴더에 복사 (예: `menu.m4a`)
2. 프로젝트 루트에서 `xcodegen generate` 실행
3. Xcode에서 빌드·실행

파일이 없으면 `AudioManager`는 조용히 무시하므로 부분적으로만 준비된 상태에서도 게임이 정상 작동
