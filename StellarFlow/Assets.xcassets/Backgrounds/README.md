# Backgrounds

배경 이미지(성운, 은하 등)를 여기 **Image Set**으로 추가하세요.

## 추가 절차

1. Xcode에서 Assets.xcassets → Backgrounds 그룹 우클릭 → **New Image Set**
2. Image Set 이름 지정 (예: `nebula_violet`)
3. @1x / @2x / @3x 이미지 드래그
4. `CustomizationCatalog.swift`의 `allBackgrounds`에 새 항목 등록:

```swift
BackgroundTheme(
    id: "nebula_violet",
    displayName: "Violet Nebula",
    imageName: "Backgrounds/nebula_violet",
    starDensityMultiplier: 1.2
)
```

## 폴더 구조로 접근

`provides-namespace: true` 설정이 있어 코드에서 `"Backgrounds/이름"`으로 접근해야 합니다.
