import SpriteKit
import UIKit

// MARK: - 프로토콜 / 타입

/// 배경 테마 — 씬 뒤에 깔리는 배경을 만드는 방법을 정의.
/// 이미지 기반(Assets.xcassets)과 프로시저럴(코드로 별 생성) 모두 지원.
struct BackgroundTheme: Identifiable {
    let id: String
    let displayName: String
    let baseColor: SKColor
    let starDensityMultiplier: CGFloat    // 0.5 ~ 1.5 정도
    /// 선택 사항 — Assets에 이미지가 있으면 이름을 넣어 배경 스프라이트로 사용.
    let imageName: String?

    /// 테마에 맞는 배경 SKNode를 생성.
    /// sceneSize: 현재 씬 크기.
    func makeBackgroundNode(sceneSize: CGSize) -> SKNode {
        let container = SKNode()
        container.zPosition = -100

        if let imageName, let _ = UIImage(named: imageName) {
            let sprite = SKSpriteNode(imageNamed: imageName)
            sprite.size = sceneSize
            sprite.zPosition = -101
            container.addChild(sprite)
        }

        // 3 레이어 패럴랙스 별
        for layer in 0..<3 {
            let node = SKNode()
            node.zPosition = CGFloat(-100 + layer)
            let count = Int(CGFloat(60 + layer * 30) * starDensityMultiplier)
            let brightness: CGFloat = 0.3 + CGFloat(layer) * 0.2
            for _ in 0..<count {
                let r: CGFloat = CGFloat.random(in: 0.5...1.6)
                let s = SKShapeNode(circleOfRadius: r)
                s.fillColor = SKColor.white.withAlphaComponent(brightness)
                s.strokeColor = .clear
                s.position = CGPoint(
                    x: CGFloat.random(in: -sceneSize.width...sceneSize.width),
                    y: CGFloat.random(in: -sceneSize.height...sceneSize.height * 2)
                )
                node.addChild(s)
            }
            container.addChild(node)
        }

        return container
    }
}

/// 행성 스킨 — 행성 kind별 색상 팔레트 오버라이드.
/// 기본 스킨 외에 커스텀 스킨을 등록해 사용자가 선택할 수 있게.
struct PlanetSkin: Identifiable {
    let id: String
    let displayName: String
    /// kind별 대표 색. nil이면 기본 색 유지.
    let tintOverrides: [PlanetKindKey: SKColor]

    func tint(for kind: PlanetKindKey) -> SKColor? {
        tintOverrides[kind]
    }
}

/// PlanetKind를 Hashable 키로 쓰기 위한 래퍼.
/// (enum PlanetKind 자체는 이미 Hashable이지만 외부 모듈/파일에서 사용성 일관성을 위해)
enum PlanetKindKey: String, Hashable {
    case standard, attractor, repulsor, booster, pulsar, blackHole, asteroid

    static func from(_ kind: PlanetKind) -> PlanetKindKey {
        switch kind {
        case .standard:  return .standard
        case .attractor: return .attractor
        case .repulsor:  return .repulsor
        case .booster:   return .booster
        case .pulsar:    return .pulsar
        case .blackHole: return .blackHole
        case .asteroid:  return .asteroid
        }
    }
}

/// 플레이어(별빛) 스킨 — 본체 색과 꼬리 파티클 색을 커스터마이즈.
struct PlayerSkin: Identifiable {
    let id: String
    let displayName: String
    let coreColor: SKColor
    let trailColor: SKColor
}

// MARK: - 카탈로그

/// 앱 전역에서 사용하는 커스터마이징 허브.
/// 배경/행성/플레이어 스킨 목록을 한 곳에서 관리하고,
/// 현재 선택된 스킨을 UserDefaults에 영속화한다.
enum CustomizationCatalog {

    // MARK: - Keys

    private enum Keys {
        static let background = "custom.background"
        static let planetSkin = "custom.planetSkin"
        static let playerSkin = "custom.playerSkin"
    }

    // MARK: - 기본 프리셋

    static let defaultBackground = BackgroundTheme(
        id: "deep_space",
        displayName: "Deep Space",
        baseColor: SKColor(red: 0.023, green: 0.019, blue: 0.078, alpha: 1.0),
        starDensityMultiplier: 1.0,
        imageName: nil
    )

    static let allBackgrounds: [BackgroundTheme] = [
        defaultBackground,
        BackgroundTheme(
            id: "violet_drift",
            displayName: "Violet Drift",
            baseColor: SKColor(red: 0.08, green: 0.04, blue: 0.14, alpha: 1.0),
            starDensityMultiplier: 1.25,
            imageName: nil
        ),
        BackgroundTheme(
            id: "aurora_bay",
            displayName: "Aurora Bay",
            baseColor: SKColor(red: 0.02, green: 0.08, blue: 0.12, alpha: 1.0),
            starDensityMultiplier: 1.1,
            imageName: nil
        ),
        BackgroundTheme(
            id: "crimson_void",
            displayName: "Crimson Void",
            baseColor: SKColor(red: 0.10, green: 0.02, blue: 0.04, alpha: 1.0),
            starDensityMultiplier: 0.85,
            imageName: nil
        ),
        // 추후 이미지 기반 테마 예시 — Assets.xcassets/Backgrounds/nebula_violet 에셋 추가 후 활성화
        // BackgroundTheme(
        //     id: "nebula_violet",
        //     displayName: "Violet Nebula",
        //     baseColor: SKColor(red: 0.05, green: 0.03, blue: 0.12, alpha: 1.0),
        //     starDensityMultiplier: 1.0,
        //     imageName: "Backgrounds/nebula_violet"
        // ),
    ]

    static let defaultPlanetSkin = PlanetSkin(
        id: "classic",
        displayName: "Classic",
        tintOverrides: [:]   // 빈 맵 — 기본 색 유지
    )

    static let allPlanetSkins: [PlanetSkin] = [
        defaultPlanetSkin,
        PlanetSkin(
            id: "pastel",
            displayName: "Pastel",
            tintOverrides: [
                .standard:  SKColor(red: 0.70, green: 0.85, blue: 1.00, alpha: 1.0),
                .attractor: SKColor(red: 0.75, green: 0.95, blue: 0.80, alpha: 1.0),
                .repulsor:  SKColor(red: 0.75, green: 0.95, blue: 0.98, alpha: 1.0),
                .booster:   SKColor(red: 1.00, green: 0.75, blue: 0.88, alpha: 1.0),
                .pulsar:    SKColor(red: 1.00, green: 0.88, blue: 0.65, alpha: 1.0),
                .asteroid:  SKColor(red: 0.85, green: 0.55, blue: 0.55, alpha: 1.0)
            ]
        ),
        PlanetSkin(
            id: "neon",
            displayName: "Neon",
            tintOverrides: [
                .standard:  SKColor(red: 0.25, green: 0.70, blue: 1.00, alpha: 1.0),
                .attractor: SKColor(red: 0.20, green: 1.00, blue: 0.35, alpha: 1.0),
                .repulsor:  SKColor(red: 0.10, green: 1.00, blue: 0.95, alpha: 1.0),
                .booster:   SKColor(red: 1.00, green: 0.15, blue: 0.75, alpha: 1.0),
                .pulsar:    SKColor(red: 1.00, green: 0.85, blue: 0.15, alpha: 1.0),
                .asteroid:  SKColor(red: 1.00, green: 0.20, blue: 0.25, alpha: 1.0)
            ]
        )
    ]

    static let defaultPlayerSkin = PlayerSkin(
        id: "stardust_white",
        displayName: "Stardust",
        coreColor: .white,
        trailColor: .white
    )

    static let allPlayerSkins: [PlayerSkin] = [
        defaultPlayerSkin,
        PlayerSkin(
            id: "aurora_cyan",
            displayName: "Aurora",
            coreColor: SKColor(red: 0.70, green: 1.00, blue: 0.95, alpha: 1.0),
            trailColor: SKColor(red: 0.40, green: 0.85, blue: 1.00, alpha: 1.0)
        ),
        PlayerSkin(
            id: "ember",
            displayName: "Ember",
            coreColor: SKColor(red: 1.00, green: 0.85, blue: 0.55, alpha: 1.0),
            trailColor: SKColor(red: 1.00, green: 0.55, blue: 0.25, alpha: 1.0)
        ),
        PlayerSkin(
            id: "blossom",
            displayName: "Blossom",
            coreColor: SKColor(red: 1.00, green: 0.85, blue: 0.95, alpha: 1.0),
            trailColor: SKColor(red: 1.00, green: 0.45, blue: 0.75, alpha: 1.0)
        )
    ]

    // MARK: - 현재 선택

    static var selectedBackground: BackgroundTheme {
        let id = UserDefaults.standard.string(forKey: Keys.background) ?? defaultBackground.id
        return allBackgrounds.first(where: { $0.id == id }) ?? defaultBackground
    }

    static var selectedPlanetSkin: PlanetSkin {
        let id = UserDefaults.standard.string(forKey: Keys.planetSkin) ?? defaultPlanetSkin.id
        return allPlanetSkins.first(where: { $0.id == id }) ?? defaultPlanetSkin
    }

    static var selectedPlayerSkin: PlayerSkin {
        let id = UserDefaults.standard.string(forKey: Keys.playerSkin) ?? defaultPlayerSkin.id
        return allPlayerSkins.first(where: { $0.id == id }) ?? defaultPlayerSkin
    }

    // MARK: - 선택 변경

    static func selectBackground(id: String) {
        guard allBackgrounds.contains(where: { $0.id == id }) else { return }
        UserDefaults.standard.set(id, forKey: Keys.background)
    }

    static func selectPlanetSkin(id: String) {
        guard allPlanetSkins.contains(where: { $0.id == id }) else { return }
        UserDefaults.standard.set(id, forKey: Keys.planetSkin)
    }

    static func selectPlayerSkin(id: String) {
        guard allPlayerSkins.contains(where: { $0.id == id }) else { return }
        UserDefaults.standard.set(id, forKey: Keys.playerSkin)
    }
}
