import SpriteKit
import GameplayKit

/// 무한 절차적 생성 — 화면 상단에 새 행성을 만들고, 화면 아래로 벗어난 행성은 풀로 반환한다.
final class WorldGenerator {

    weak var scene: SKScene?
    weak var worldNode: SKNode?

    private var rng: GKRandomSource = GKMersenneTwisterRandomSource()

    /// 관리되는 행성 목록 (씬에 실제로 붙어 있는 것들)
    private(set) var activePlanets: [PlanetNode] = []
    private(set) var activeMeteors: [MeteorNode] = []

    /// 가장 최근에 생성한 행성 — 다음 스폰 기준
    private var lastPlanet: PlanetNode?

    /// 난이도 상승 지표 (스코어 기반)
    var difficulty: CGFloat = 0

    /// 생성 범위 (스크린 폭)
    let worldWidth: CGFloat
    let worldHeight: CGFloat

    init(worldWidth: CGFloat, worldHeight: CGFloat, seed: UInt64 = UInt64(Date().timeIntervalSince1970)) {
        self.worldWidth = worldWidth
        self.worldHeight = worldHeight
        self.rng = GKMersenneTwisterRandomSource(seed: seed)
    }

    // MARK: - 초기 배치

    /// 게임 시작 시 첫 행성(아래)과 다음 행성(위)을 만든다.
    func seedInitialPlanets(firstPosition: CGPoint) -> PlanetNode {
        let first = makePlanet(at: firstPosition, kind: .standard,
                               radiusHint: 28, orbitHint: 80)
        attach(first)
        lastPlanet = first

        // 첫 점프 가능한 위치에 두 번째 행성
        var next = firstPosition
        next.y += 260
        next.x += CGFloat.random(in: -60...60)
        let second = makePlanet(at: next, kind: .standard, radiusHint: 24, orbitHint: 70)
        attach(second)
        lastPlanet = second
        return first
    }

    // MARK: - 상단에 계속 새 행성 추가

    /// 카메라(=플레이어가 보는 최상단) 위로 버퍼만큼 채운다.
    func ensurePlanetsAhead(cameraTopY: CGFloat) {
        let targetY = cameraTopY + worldHeight * 1.2
        while (lastPlanet?.position.y ?? -.infinity) < targetY {
            spawnNextPlanet()
        }
    }

    private func spawnNextPlanet() {
        guard let last = lastPlanet else { return }

        // 난이도에 따라 점프 거리 증가
        let baseDistance: CGFloat = 260 + difficulty * 40
        let spread: CGFloat = 60
        let jumpDistance = baseDistance + CGFloat.random(in: -spread...spread)

        // 수평 변위 — 양쪽 벽 내에 수렴
        var nextX = last.position.x + CGFloat.random(in: -160...160)
        let margin: CGFloat = 60
        nextX = nextX.clamped(-worldWidth/2 + margin, worldWidth/2 - margin)

        let nextPos = CGPoint(x: nextX, y: last.position.y + jumpDistance)

        // 행성 종류 추첨
        let kind: PlanetKind = pickKind()

        // 반경/궤도 조정
        let radius: CGFloat
        let orbit: CGFloat
        switch kind {
        case .standard:
            radius = CGFloat.random(in: 18...34)
            orbit = radius + CGFloat.random(in: 44...72)
        case .attractor:
            radius = CGFloat.random(in: 18...28)
            orbit = radius + CGFloat.random(in: 60...90)   // 초기엔 넉넉, 수축 여유
        case .repulsor:
            radius = CGFloat.random(in: 16...24)
            orbit = radius + CGFloat.random(in: 36...52)   // 초기엔 좁게, 팽창 여유
        case .booster:
            radius = CGFloat.random(in: 14...22)
            orbit = radius + CGFloat.random(in: 48...70)
        case .pulsar:
            radius = CGFloat.random(in: 16...26)
            orbit = radius + 70
        case .blackHole:
            radius = CGFloat.random(in: 12...20)
            orbit = radius + 60
        case .asteroid:
            radius = CGFloat.random(in: 20...32)
            orbit = radius + 30  // field/ring 모두 숨김
        }

        let planet = makePlanet(at: nextPos, kind: kind, radiusHint: radius, orbitHint: orbit)
        attach(planet)
        lastPlanet = planet

        // 가끔 유성 추가 (난이도 올라가면 더 자주)
        if difficulty > 2 && CGFloat.random(in: 0...1) < 0.25 {
            spawnMeteor(aroundY: nextPos.y)
        }
    }

    private func pickKind() -> PlanetKind {
        // 점수 기반 단계적 등장:
        // 0-1: standard, 소수의 pulsar
        // 1-2: attractor, repulsor 추가
        // 2-3: booster 추가, asteroid 등장
        // 3+: blackHole 등장, 위험도 증가
        if difficulty < 1 {
            return CGFloat.random(in: 0...1) < 0.2 ? .pulsar : .standard
        }

        let roll = CGFloat.random(in: 0...1)
        if difficulty >= 4 {
            if roll < 0.12 { return .blackHole }
            if roll < 0.24 { return .asteroid }
            if roll < 0.36 { return .attractor }
            if roll < 0.48 { return .repulsor }
            if roll < 0.60 { return .booster }
            if roll < 0.75 { return .pulsar }
            return .standard
        }
        if difficulty >= 3 {
            if roll < 0.08 { return .blackHole }
            if roll < 0.18 { return .asteroid }
            if roll < 0.30 { return .attractor }
            if roll < 0.42 { return .repulsor }
            if roll < 0.54 { return .booster }
            if roll < 0.70 { return .pulsar }
            return .standard
        }
        if difficulty >= 2 {
            if roll < 0.08 { return .asteroid }
            if roll < 0.22 { return .attractor }
            if roll < 0.34 { return .repulsor }
            if roll < 0.44 { return .booster }
            if roll < 0.62 { return .pulsar }
            return .standard
        }
        // difficulty 1-2: attractor, repulsor 도입
        if roll < 0.15 { return .attractor }
        if roll < 0.28 { return .repulsor }
        if roll < 0.45 { return .pulsar }
        return .standard
    }

    private func makePlanet(at pos: CGPoint, kind: PlanetKind,
                            radiusHint: CGFloat, orbitHint: CGFloat) -> PlanetNode {
        // 공전 방향/속도 — 행성 클수록 느리게, 50% 확률로 역방향
        let speedMag = CGFloat.random(in: 1.6...2.6) * (28.0 / radiusHint)
        let direction: CGFloat = Bool.random() ? 1 : -1
        let angular = speedMag * direction

        let tint: SKColor
        switch kind {
        case .standard:
            let palette: [SKColor] = [
                SKColor.fromHex(0x8FC7FF),
                SKColor.fromHex(0xA8A4FF),
                SKColor.fromHex(0x9CE7C7),
                SKColor.fromHex(0xFFD48A)
            ]
            tint = palette.randomElement()!
        case .attractor:
            tint = SKColor(red: 0.45, green: 0.95, blue: 0.55, alpha: 1.0)
        case .repulsor:
            tint = SKColor(red: 0.35, green: 0.85, blue: 0.95, alpha: 1.0)
        case .booster:
            tint = SKColor(red: 1.0, green: 0.4, blue: 0.75, alpha: 1.0)
        case .pulsar:
            tint = SKColor(red: 1.0, green: 0.7, blue: 0.35, alpha: 1.0)
        case .blackHole:
            tint = .black
        case .asteroid:
            tint = SKColor(red: 0.6, green: 0.25, blue: 0.2, alpha: 1.0)
        }

        let planet = PlanetNode(kind: kind, coreRadius: radiusHint,
                                orbitRadius: orbitHint, angularSpeed: angular, tint: tint)
        planet.position = pos
        return planet
    }

    private func spawnMeteor(aroundY y: CGFloat) {
        let fromLeft = Bool.random()
        let speed: CGFloat = CGFloat.random(in: 90...160)
        let startX = fromLeft ? -worldWidth/2 - 20 : worldWidth/2 + 20
        let dx: CGFloat = fromLeft ? speed : -speed
        let meteor = MeteorNode(radius: 4, velocity: CGVector(dx: dx, dy: 0))
        meteor.position = CGPoint(x: startX, y: y + CGFloat.random(in: -60...60))
        worldNode?.addChild(meteor)
        activeMeteors.append(meteor)
    }

    private func attach(_ planet: PlanetNode) {
        worldNode?.addChild(planet)
        activePlanets.append(planet)
    }

    // MARK: - 정리

    /// 카메라 기준선 아래로 내려간 행성·유성 제거.
    func cullBelow(_ y: CGFloat) {
        activePlanets.removeAll { p in
            if p.position.y < y - 200 {
                p.removeFromParent()
                return true
            }
            return false
        }
        activeMeteors.removeAll { m in
            // 화면 양옆으로 벗어났거나 카메라 아래로 간 유성 제거
            if m.position.y < y - 200 ||
               m.position.x < -worldWidth/2 - 80 ||
               m.position.x >  worldWidth/2 + 80 {
                m.removeFromParent()
                return true
            }
            return false
        }
    }

    func updateMeteors(dt: CGFloat) {
        for m in activeMeteors {
            m.update(dt: dt)
        }
    }

    /// 난이도를 현재 스코어로 갱신.
    func setDifficulty(fromScore score: Int) {
        difficulty = CGFloat(score) / 2500.0
    }

    /// 풀 사이즈 제한 (안전장치)
    func enforcePoolLimit(maxPlanets: Int = 24) {
        while activePlanets.count > maxPlanets {
            let p = activePlanets.removeFirst()
            p.removeFromParent()
        }
    }
}
