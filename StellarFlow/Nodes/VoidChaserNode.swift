import SpriteKit

/// 화면 아래에서 위로 상승해 오는 "파괴파". 닿으면 즉시 게임오버.
final class VoidChaserNode: SKNode {

    /// 파의 가장 윗면 y (씬 좌표). 플레이어가 이 값보다 낮으면 사망.
    var topY: CGFloat = 0

    /// 상승 속도 (pt/s). GameScene이 score에 따라 동적으로 조정.
    var ascendSpeed: CGFloat = 60

    private let width: CGFloat
    private let height: CGFloat

    private let base: SKShapeNode
    private let edge: SKShapeNode
    private let edgeGlow: SKShapeNode
    private let emberEmitter: SKEmitterNode

    init(worldWidth: CGFloat) {
        // 파의 세로 범위는 화면 크기를 넘는 큰 사각형 — 맨 위 가장자리만 경계로 사용
        self.width = worldWidth * 2.4
        self.height = 2400

        // 본체 — 아주 어두운 자주색 큰 직사각형
        base = SKShapeNode(rect: CGRect(x: -width/2, y: -height, width: width, height: height),
                           cornerRadius: 0)
        base.fillColor = SKColor(red: 0.05, green: 0.0, blue: 0.08, alpha: 0.95)
        base.strokeColor = .clear
        base.zPosition = 50

        // 위 가장자리 라인 — 위험을 알리는 진홍색 빛
        edge = SKShapeNode(rect: CGRect(x: -width/2, y: -1, width: width, height: 2))
        edge.fillColor = SKColor(red: 0.9, green: 0.15, blue: 0.5, alpha: 1.0)
        edge.strokeColor = .clear
        edge.glowWidth = 8
        edge.zPosition = 52

        // 바깥쪽 글로우 — 넓게 번지는 자주/분홍
        edgeGlow = SKShapeNode(rect: CGRect(x: -width/2, y: -12, width: width, height: 24))
        edgeGlow.fillColor = SKColor(red: 0.6, green: 0.1, blue: 0.4, alpha: 0.35)
        edgeGlow.strokeColor = .clear
        edgeGlow.glowWidth = 18
        edgeGlow.blendMode = .add
        edgeGlow.zPosition = 51

        // 상승하는 잔불 파티클
        emberEmitter = SKEmitterNode()
        emberEmitter.particleTexture = PlayerNode.makeSoftDotTexture()
        emberEmitter.position = .zero
        emberEmitter.particlePositionRange = CGVector(dx: width, dy: 2)
        emberEmitter.particleBirthRate = 70
        emberEmitter.particleLifetime = 2.2
        emberEmitter.particleLifetimeRange = 0.8
        emberEmitter.particleSize = CGSize(width: 6, height: 6)
        emberEmitter.particleAlpha = 0.7
        emberEmitter.particleAlphaSpeed = -0.35
        emberEmitter.particleColor = SKColor(red: 1.0, green: 0.25, blue: 0.55, alpha: 1.0)
        emberEmitter.particleColorBlendFactor = 1.0
        emberEmitter.particleBlendMode = .add
        emberEmitter.emissionAngle = .pi / 2
        emberEmitter.emissionAngleRange = .pi / 5
        emberEmitter.particleSpeed = 80
        emberEmitter.particleSpeedRange = 40
        emberEmitter.particleScaleSpeed = -0.25
        emberEmitter.zPosition = 53

        super.init()
        addChild(base)
        addChild(edgeGlow)
        addChild(edge)
        addChild(emberEmitter)

        // 가장자리 맥동
        edge.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.7),
            SKAction.fadeAlpha(to: 1.0, duration: 0.7)
        ])))
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    /// 매 프레임 호출. 현재 y(=topY에 해당)를 갱신.
    func update(dt: CGFloat) {
        let dy = ascendSpeed * dt
        position = CGPoint(x: 0, y: position.y + dy)
        topY = position.y
    }

    /// 시작 위치로 이동 (카메라에서 멀리 아래).
    func reset(initialTopY: CGFloat) {
        position = CGPoint(x: 0, y: initialTopY)
        topY = initialTopY
    }
}
