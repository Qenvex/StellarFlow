import SpriteKit

final class PlayerNode: SKNode {

    private let core: SKShapeNode
    private let halo: SKShapeNode
    private(set) var trail: SKEmitterNode?

    init(radius: CGFloat = 6) {
        core = SKShapeNode(circleOfRadius: radius)
        core.fillColor = .white
        core.strokeColor = SKColor.white.withAlphaComponent(0.6)
        core.lineWidth = 1
        core.glowWidth = 6
        core.zPosition = 10

        halo = SKShapeNode(circleOfRadius: radius * 2.2)
        halo.fillColor = SKColor.white.withAlphaComponent(0.18)
        halo.strokeColor = .clear
        halo.glowWidth = 12
        halo.blendMode = .add
        halo.zPosition = 9

        super.init()
        addChild(halo)
        addChild(core)

        // 살짝 호흡
        halo.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.9),
            SKAction.scale(to: 0.92, duration: 0.9)
        ])))

        // 물리바디 — 접촉 감지용 (중력/충돌은 씬에서 수동 처리)
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.categoryBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.planetCore | PhysicsCategory.meteor | PhysicsCategory.blackHole
        body.collisionBitMask = PhysicsCategory.none
        body.affectedByGravity = false
        body.allowsRotation = false
        body.linearDamping = 0
        body.angularDamping = 0
        self.physicsBody = body

        attachTrail()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func attachTrail() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = PlayerNode.makeSoftDotTexture()
        emitter.particleBirthRate = 180
        emitter.particleLifetime = 0.9
        emitter.particleLifetimeRange = 0.3
        emitter.particleSize = CGSize(width: 8, height: 8)
        emitter.particleScale = 0.9
        emitter.particleScaleSpeed = -0.7
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.0
        emitter.particleColor = .white
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 4
        emitter.particleSpeedRange = 8
        emitter.targetNode = nil   // 씬에서 parent에 설정
        emitter.zPosition = 5
        self.trail = emitter
        addChild(emitter)
    }

    /// 반투명 원형 텍스처 (파티클용)
    static func makeSoftDotTexture() -> SKTexture {
        let size: CGFloat = 16
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [SKColor.white.cgColor, SKColor.white.withAlphaComponent(0).cgColor] as CFArray
            let locs: [CGFloat] = [0, 1]
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locs) {
                cg.drawRadialGradient(gradient,
                                      startCenter: CGPoint(x: size/2, y: size/2), startRadius: 0,
                                      endCenter: CGPoint(x: size/2, y: size/2), endRadius: size/2,
                                      options: [])
            }
        }
        return SKTexture(image: img)
    }

    func pulseDeath() {
        halo.removeAllActions()
        core.run(SKAction.group([
            SKAction.scale(to: 3.0, duration: 0.35),
            SKAction.fadeOut(withDuration: 0.35)
        ]))
        halo.run(SKAction.group([
            SKAction.scale(to: 5.0, duration: 0.5),
            SKAction.fadeOut(withDuration: 0.5)
        ]))
        trail?.particleBirthRate = 0
    }
}
