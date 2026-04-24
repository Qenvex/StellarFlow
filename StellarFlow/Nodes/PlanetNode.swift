import SpriteKit

enum PlanetKind {
    case standard    // 파랑 — 기본. 안정적 궤도.
    case attractor   // 녹색 — Hold 중이면 궤도가 코어 쪽으로 수축 (위험). 놓기 타이밍으로 강한 슬링샷.
    case repulsor    // 청록 — Hold 중이면 궤도가 점점 바깥으로 팽창. 너무 커지면 튕겨나감.
    case booster     // 분홍 — 공전 속도가 시간이 갈수록 가속. 발사 시 초고속.
    case pulsar      // 노랑 — 궤도 반경이 주기적으로 숨쉬듯 변함.
    case blackHole   // 검정 — 궤도 없음. 스윙바이 중력 굴절.
    case asteroid    // 빨강 — 공전 불가. 접촉 시 즉사.
}

final class PlanetNode: SKNode {

    let kind: PlanetKind
    let coreRadius: CGFloat      // 충돌 반경 (행성 본체)
    var orbitRadius: CGFloat     // 안전 궤도 반경
    let fieldRadius: CGFloat     // Hold로 포획 가능한 중력장 반경
    let angularSpeed: CGFloat    // 공전 각속도 (rad/s). 플레이어 이동 방향 부호.

    private let coreSprite: SKShapeNode
    private let glow: SKShapeNode
    private let orbitRing: SKShapeNode
    private let fieldRing: SKShapeNode

    // Pulsar state
    private var pulsarBaseRadius: CGFloat = 0
    private var pulsarPhase: CGFloat = 0
    private var pulsarAmplitude: CGFloat = 0
    private var pulsarRate: CGFloat = 0  // rad/s

    init(kind: PlanetKind, coreRadius: CGFloat, orbitRadius: CGFloat, angularSpeed: CGFloat, tint: SKColor) {
        self.kind = kind
        self.coreRadius = coreRadius
        self.orbitRadius = orbitRadius
        self.fieldRadius = orbitRadius * 1.9
        self.angularSpeed = angularSpeed

        // 본체 스프라이트
        coreSprite = SKShapeNode(circleOfRadius: coreRadius)
        coreSprite.fillColor = tint
        coreSprite.strokeColor = tint.withAlphaComponent(0.6)
        coreSprite.lineWidth = 1.0
        coreSprite.glowWidth = 2
        coreSprite.zPosition = 2

        // 은은한 글로우
        glow = SKShapeNode(circleOfRadius: coreRadius * 1.8)
        glow.fillColor = tint.withAlphaComponent(0.10)
        glow.strokeColor = .clear
        glow.glowWidth = 8
        glow.zPosition = 1
        glow.blendMode = .add

        // 궤도 링 (점선)
        orbitRing = SKShapeNode(circleOfRadius: orbitRadius)
        orbitRing.strokeColor = SKColor.white.withAlphaComponent(0.35)
        orbitRing.fillColor = .clear
        orbitRing.lineWidth = 1.2
        orbitRing.zPosition = 0
        orbitRing.glowWidth = 0.5
        // 점선 효과: dash pattern
        if let dashed = orbitRing.path?.copy(dashingWithPhase: 0, lengths: [6, 6]) {
            orbitRing.path = dashed
        }

        // 중력장 영역 표시 (아주 흐릿하게)
        fieldRing = SKShapeNode(circleOfRadius: fieldRadius)
        fieldRing.strokeColor = tint.withAlphaComponent(0.10)
        fieldRing.fillColor = .clear
        fieldRing.lineWidth = 0.8
        fieldRing.zPosition = -1

        super.init()

        addChild(glow)
        addChild(fieldRing)
        addChild(orbitRing)
        addChild(coreSprite)

        // 물리바디 — 코어와의 충돌 감지용
        let body = SKPhysicsBody(circleOfRadius: coreRadius)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.planetCore
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        self.physicsBody = body

        configureKindBehavior()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func configureKindBehavior() {
        switch kind {
        case .standard:
            coreSprite.run(SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.scale(to: 1.03, duration: 1.8),
                    SKAction.scale(to: 0.97, duration: 1.8)
                ])
            ))
        case .attractor:
            // 녹색 — 흡인 경고. 안쪽으로 빨려들어오는 듯한 스파이럴
            coreSprite.fillColor = SKColor(red: 0.45, green: 0.95, blue: 0.55, alpha: 1.0)
            coreSprite.strokeColor = SKColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 0.7)
            orbitRing.strokeColor = SKColor(red: 0.4, green: 1.0, blue: 0.55, alpha: 0.4)
            glow.fillColor = SKColor(red: 0.3, green: 0.9, blue: 0.45, alpha: 0.18)
            // 수축 표시 — 가는 호가 코어 쪽으로 파장처럼 들어옴
            for i in 0..<3 {
                let wave = SKShapeNode(circleOfRadius: orbitRadius)
                wave.strokeColor = SKColor(red: 0.4, green: 1.0, blue: 0.55, alpha: 0.5)
                wave.fillColor = .clear
                wave.lineWidth = 1.0
                wave.zPosition = -0.5
                let delay = Double(i) * 0.7
                wave.alpha = 0
                wave.setScale(1.0)
                wave.run(SKAction.sequence([
                    SKAction.wait(forDuration: delay),
                    SKAction.repeatForever(SKAction.sequence([
                        SKAction.group([
                            SKAction.scale(to: coreRadius / orbitRadius, duration: 2.1),
                            SKAction.fadeAlpha(to: 0.0, duration: 2.1)
                        ]),
                        SKAction.group([
                            SKAction.scale(to: 1.0, duration: 0),
                            SKAction.fadeAlpha(to: 0.55, duration: 0)
                        ])
                    ]))
                ]))
                addChild(wave)
            }
        case .repulsor:
            // 청록 — 밖으로 밀어내는 파문
            coreSprite.fillColor = SKColor(red: 0.35, green: 0.85, blue: 0.95, alpha: 1.0)
            coreSprite.strokeColor = SKColor(red: 0.45, green: 0.95, blue: 1.0, alpha: 0.7)
            orbitRing.strokeColor = SKColor(red: 0.45, green: 0.95, blue: 1.0, alpha: 0.4)
            glow.fillColor = SKColor(red: 0.35, green: 0.85, blue: 0.95, alpha: 0.18)
            for i in 0..<3 {
                let wave = SKShapeNode(circleOfRadius: coreRadius * 1.1)
                wave.strokeColor = SKColor(red: 0.5, green: 0.95, blue: 1.0, alpha: 0.5)
                wave.fillColor = .clear
                wave.lineWidth = 1.0
                wave.zPosition = -0.5
                let delay = Double(i) * 0.7
                wave.alpha = 0
                wave.setScale(1.0)
                wave.run(SKAction.sequence([
                    SKAction.wait(forDuration: delay),
                    SKAction.repeatForever(SKAction.sequence([
                        SKAction.group([
                            SKAction.scale(to: orbitRadius / (coreRadius * 1.1) * 1.1, duration: 2.1),
                            SKAction.fadeAlpha(to: 0.0, duration: 2.1)
                        ]),
                        SKAction.group([
                            SKAction.scale(to: 1.0, duration: 0),
                            SKAction.fadeAlpha(to: 0.55, duration: 0)
                        ])
                    ]))
                ]))
                addChild(wave)
            }
        case .booster:
            // 분홍 — 가속. 코어가 빠르게 맥동
            coreSprite.fillColor = SKColor(red: 1.0, green: 0.4, blue: 0.75, alpha: 1.0)
            coreSprite.strokeColor = SKColor(red: 1.0, green: 0.55, blue: 0.85, alpha: 0.8)
            orbitRing.strokeColor = SKColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 0.45)
            glow.fillColor = SKColor(red: 1.0, green: 0.4, blue: 0.75, alpha: 0.2)
            coreSprite.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.12, duration: 0.3),
                SKAction.scale(to: 0.92, duration: 0.3)
            ])))
            // 스파크 파티클
            let spark = SKEmitterNode()
            spark.particleTexture = PlayerNode.makeSoftDotTexture()
            spark.particleBirthRate = 40
            spark.particleLifetime = 0.6
            spark.particleSize = CGSize(width: 4, height: 4)
            spark.particleAlpha = 0.9
            spark.particleAlphaSpeed = -1.5
            spark.particleColor = SKColor(red: 1.0, green: 0.55, blue: 0.85, alpha: 1.0)
            spark.particleColorBlendFactor = 1.0
            spark.particleBlendMode = .add
            spark.emissionAngleRange = .pi * 2
            spark.particleSpeed = 30
            spark.particleSpeedRange = 20
            spark.zPosition = 1.5
            addChild(spark)
        case .pulsar:
            pulsarBaseRadius = orbitRadius
            pulsarAmplitude = orbitRadius * 0.35
            pulsarRate = 1.6
            orbitRing.strokeColor = SKColor(red: 1.0, green: 0.75, blue: 0.45, alpha: 0.45)
            coreSprite.fillColor = SKColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0)
        case .blackHole:
            // 블랙홀은 궤도/중력장 표시를 다르게 — 스윙바이만 유도
            orbitRing.isHidden = true
            fieldRing.strokeColor = SKColor.purple.withAlphaComponent(0.2)
            coreSprite.fillColor = .black
            coreSprite.strokeColor = SKColor.purple.withAlphaComponent(0.6)
            glow.fillColor = SKColor.purple.withAlphaComponent(0.2)
            // 회전하는 accretion ring
            let ring = SKShapeNode(circleOfRadius: coreRadius * 1.4)
            ring.strokeColor = SKColor.purple.withAlphaComponent(0.5)
            ring.lineWidth = 1.0
            ring.fillColor = .clear
            ring.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 2.0)))
            addChild(ring)
        case .asteroid:
            // 궤도/중력장 숨김 — 닿으면 죽는 위험 덩어리
            orbitRing.isHidden = true
            fieldRing.isHidden = true
            coreSprite.fillColor = SKColor(red: 0.55, green: 0.22, blue: 0.22, alpha: 1.0)
            coreSprite.strokeColor = SKColor(red: 1.0, green: 0.45, blue: 0.3, alpha: 0.9)
            coreSprite.lineWidth = 2
            coreSprite.glowWidth = 6
            glow.fillColor = SKColor(red: 1.0, green: 0.35, blue: 0.25, alpha: 0.25)
            // 표면 파편 (원 위에 불규칙 점들)
            for _ in 0..<6 {
                let chunk = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
                chunk.fillColor = SKColor(red: 0.3, green: 0.1, blue: 0.1, alpha: 1.0)
                chunk.strokeColor = .clear
                let a = CGFloat.random(in: 0...(.pi * 2))
                let r = coreRadius * CGFloat.random(in: 0.4...0.85)
                chunk.position = CGPoint(x: cos(a) * r, y: sin(a) * r)
                coreSprite.addChild(chunk)
            }
            // 위험 펄스 — 붉은 링이 펄럭임
            let warn = SKShapeNode(circleOfRadius: coreRadius * 1.3)
            warn.strokeColor = SKColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 0.45)
            warn.fillColor = .clear
            warn.lineWidth = 1.2
            warn.zPosition = 1
            warn.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.4, duration: 1.0),
                    SKAction.fadeAlpha(to: 0.0, duration: 1.0)
                ]),
                SKAction.group([
                    SKAction.scale(to: 1.0, duration: 0.0),
                    SKAction.fadeAlpha(to: 0.6, duration: 0.0)
                ])
            ])))
            addChild(warn)
            // 느릿한 자전
            coreSprite.run(SKAction.repeatForever(
                SKAction.rotate(byAngle: .pi * 2, duration: CGFloat.random(in: 6...10))
            ))
        }
    }

    /// 매 프레임 호출. 펄사의 궤도 반경을 숨쉬게 한다.
    func update(dt: CGFloat, elapsed: CGFloat) {
        guard kind == .pulsar else { return }
        pulsarPhase += dt * pulsarRate
        let osc = sin(pulsarPhase)
        orbitRadius = pulsarBaseRadius + pulsarAmplitude * osc
        // path 재생성은 비용이 크므로 scale 기반으로 처리
        let scale = orbitRadius / pulsarBaseRadius
        orbitRing.setScale(scale)
        fieldRing.setScale(scale)
    }

    /// 현재 궤도 반경 (펄사 감안)
    var currentOrbitRadius: CGFloat { orbitRadius }

    /// 중력장 경계를 시각적으로 살짝 강조한다 (포획 가능 상태일 때)
    func highlightField(_ on: Bool) {
        let target: CGFloat = on ? 0.45 : 0.10
        fieldRing.removeAllActions()
        fieldRing.run(SKAction.fadeAlpha(to: target, duration: 0.12))
    }

    /// 포획 순간 — 궤도 링과 글로우를 짧게 펄스.
    func pulseCatch() {
        // 궤도 링: 빠르게 밝아졌다 원래대로
        orbitRing.removeAllActions()
        let origAlpha = orbitRing.alpha
        orbitRing.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 1.0, duration: 0.08),
                SKAction.scale(to: 1.08, duration: 0.14)
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: origAlpha, duration: 0.4),
                SKAction.scale(to: 1.0, duration: 0.4)
            ])
        ]))

        // 본체 글로우 살짝 팽창
        glow.run(SKAction.sequence([
            SKAction.scale(to: 1.35, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.4)
        ]))
    }
}
