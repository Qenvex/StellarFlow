# Stellar Flow

> **Ride the gravity. Flow the stars.**

행성의 **중력 궤도**를 타고 넘나들며 우주 깊은 곳으로 끝없이 나아가는 원터치 물리 아케이드 힐링 게임. *Alto's Adventure*, *Mars Mars* 같은 잔잔한 리듬과 무한 생성의 재미를 우주 유영으로 재해석했다.

- **플랫폼**: iOS (iPhone / iPad, 세로 고정)
- **엔진**: SpriteKit (Swift 5)
- **개발 환경**: Xcode 26 / xcodegen
- **최소 지원**: iOS 16.0

---

## 컨셉

로켓 추진기 대신 행성의 중력에 몸을 맡긴다. **터치 한 번**으로 현재 궤도를 이탈해 접선 방향으로 튕겨나가고, **손가락을 눌러** 다음 행성의 중력장에 몸을 맡긴다. 원운동이 주는 시각적 편안함과 속도감, 곡선 위주의 부드러운 궤적이 핵심 디자인 철학.

## 조작법

| 입력 | 동작 |
|---|---|
| **Tap (궤도 중)** | 현재 궤도 이탈 — 접선 방향으로 관성 비행 |
| **Hold (비행 중)** | 가장 가까운 행성의 중력장에 포획되어 궤도 진입 |
| **Release** | 동일 — 손을 떼면 접선으로 발사 |

**실패 조건**
- 타이밍을 놓쳐 심우주(화면 밖)로 이탈
- 행성 코어에 충돌
- 소행성 또는 파괴파(Void Chaser)에 접촉

## 행성 종류

각 색깔마다 고유의 효과를 가진다. 점수가 올라갈수록 새로운 유형이 등장한다.

| 색 | 이름 | 효과 |
|---|---|---|
| 파랑 | **Standard** | 기본 궤도. 안정적이며 가장 자주 등장 |
| 녹색 | **Attractor** | Hold 중 궤도가 코어 쪽으로 **수축**. 늦게 놓으면 충돌, 적절히 놓으면 강한 슬링샷 |
| 청록 | **Repulsor** | Hold 중 궤도가 **팽창**. 한계치에서 자동으로 접선 방향으로 튕겨나감 |
| 분홍 | **Booster** | 공전 속도가 시간이 갈수록 **가속** (최대 2.4배). 발사 시 초고속 |
| 노랑 | **Pulsar** | 궤도 반경이 **주기적으로 숨쉬듯** 변함. 타이밍 싸움 |
| 검정 | **Black Hole** | 궤도 없음. 통과하는 궤적을 **중력으로 굴절**시킴 (스윙바이) |
| 빨강 | **Asteroid** | 공전 불가. 접촉하면 **즉시 사망** |

## 우주 위협

점수에 따라 단계적으로 등장하는 방해 요소.

- **유성우 (Meteor Shower)** — 난이도 2+에서 행성 사이를 가로지르는 유성. 접촉 시 사망.
- **파괴파 (Void Chaser)** — 점수 300점 이상에서 활성화. 화면 아래에서부터 위로 상승해 오는 어두운 자주색 벽. 속도가 점수에 따라 60 → 220 pt/s로 가속한다. 윗면에 닿는 순간 즉사.

## 핵심 메커니즘

### 부드러운 포획 (Smooth Catch)
순간이동 없는 자연스러운 진입:
- 잡힌 **그 위치**에서 바로 공전 시작
- 궤도 반경은 `smoothApproach()`로 행성의 나이브 궤도 반경에 지수 감쇠 수렴 (~0.4초)
- 비행 속도를 각속도로 변환해 **속도 매칭** — 빠르게 진입하면 빠르게 돌고, 서서히 평상 속도로 수렴

### 무한 절차적 생성
- 카메라가 상승하면 상단에 새 행성이 생성
- 화면 아래로 벗어난 행성은 풀에서 제거 (최대 18개 유지)
- 점수 2500 단위로 난이도 +1 → 새로운 행성/위협이 해금

### 물리 구현
- **궤도**: 수학적 원운동 직접 계산 (각도 × 각속도 × dt) — 완벽한 원궤도 보장
- **블랙홀**: 비행 중일 때만 중력 가속도 `strength / distSq`를 적분
- **SKEmitterNode** 기반 별먼지 꼬리 / 스파크 / 파괴파 잔불

## 빌드 & 실행

프로젝트는 **xcodegen**으로 관리된다.

```bash
# 1. 프로젝트 파일 생성 (최초 1회 또는 project.yml 변경 시)
xcodegen generate

# 2. Xcode로 열기
open StellarFlow.xcodeproj

# 3. 또는 CLI로 시뮬레이터에 빌드·설치·실행
xcodebuild -project StellarFlow.xcodeproj \
           -scheme StellarFlow \
           -sdk iphonesimulator \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           CODE_SIGNING_ALLOWED=NO build
```

### 실기기에 설치 시 주의
무료 Apple Developer 계정은 **동일 기기에 최대 3개 앱**만 설치 가능. 한도 초과 시 기존 앱을 하나 삭제하거나 유료 계정($99/년)으로 전환한다.

## 프로젝트 구조

```
Stellar_Flow/
├── project.yml                 # xcodegen 명세
├── StellarFlow.xcodeproj/      # 자동 생성 (xcodegen generate)
├── StellarFlow/
│   ├── AppDelegate.swift
│   ├── GameViewController.swift
│   ├── Info.plist
│   ├── Assets.xcassets/
│   ├── Base.lproj/
│   │   ├── LaunchScreen.storyboard
│   │   └── Main.storyboard
│   ├── Scenes/
│   │   ├── MenuScene.swift         # 시작 메뉴 + 데모 애니메이션
│   │   ├── GameScene.swift         # 메인 게임 루프
│   │   └── GameOverScene.swift     # 스코어 / 신기록
│   ├── Nodes/
│   │   ├── PlayerNode.swift        # 별빛 캐릭터 + stardust 꼬리
│   │   ├── PlanetNode.swift        # 7종의 행성 (kind별 효과)
│   │   ├── MeteorNode.swift        # 유성
│   │   └── VoidChaserNode.swift    # 파괴파
│   ├── Systems/
│   │   ├── WorldGenerator.swift    # 무한 절차적 생성 + 풀링
│   │   └── ScoreManager.swift      # 점수 / UserDefaults 하이스코어
│   └── Utilities/
│       ├── PhysicsCategory.swift
│       └── CGExtensions.swift
└── Stellar Flow.pdf            # 설계 명세서
```

## 로드맵 / 알려진 이슈

개발 예정 항목과 TODO는 [TODO.md](./TODO.md) 참고.

## 크레딧

- **게임 설계**: *Stellar Flow* 디자인 명세서 (리포 루트의 `Stellar Flow.pdf`)
- **구현**: Claude Code 협업 개발
