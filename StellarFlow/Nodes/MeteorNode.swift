import SpriteKit

final class MeteorNode: SKNode {

    let radius: CGFloat
    var velocity: CGVector

    init(radius: CGFloat = 5, velocity: CGVector) {
        self.radius = radius
        self.velocity = velocity

        super.init()

        let shape = SKShapeNode(circleOfRadius: radius)
        shape.fillColor = SKColor(red: 1.0, green: 0.7, blue: 0.5, alpha: 1.0)
        shape.strokeColor = .clear
        shape.glowWidth = 4
        shape.zPosition = 4
        addChild(shape)

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.categoryBitMask = PhysicsCategory.meteor
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        body.affectedByGravity = false
        body.isDynamic = true
        self.physicsBody = body

        // 꼬리
        let trail = SKEmitterNode()
        trail.particleTexture = PlayerNode.makeSoftDotTexture()
        trail.particleBirthRate = 90
        trail.particleLifetime = 0.4
        trail.particleSize = CGSize(width: 6, height: 6)
        trail.particleAlpha = 0.9
        trail.particleAlphaSpeed = -2.0
        trail.particleColor = SKColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 1.0)
        trail.particleColorBlendFactor = 1.0
        trail.particleBlendMode = .add
        trail.particleSpeed = 0
        addChild(trail)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func update(dt: CGFloat) {
        position = CGPoint(x: position.x + velocity.dx * dt,
                           y: position.y + velocity.dy * dt)
    }
}
