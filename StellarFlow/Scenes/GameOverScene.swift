import SpriteKit

final class GameOverScene: SKScene {

    private let finalScore: Int
    private let highScore: Int
    private let newRecord: Bool

    init(size: CGSize, finalScore: Int, highScore: Int, newRecord: Bool) {
        self.finalScore = finalScore
        self.highScore = highScore
        self.newRecord = newRecord
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor.fromHex(0x060514)
        scaleMode = .resizeFill

        let title = SKLabelNode(fontNamed: "AvenirNext-UltraLight")
        title.text = newRecord ? "NEW BEST" : "LOST IN SPACE"
        title.fontSize = 32
        title.fontColor = newRecord ? SKColor.fromHex(0xFFD48A) : .white
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.66)
        addChild(title)

        let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.text = "\(finalScore)"
        scoreLabel.fontSize = 64
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.54)
        addChild(scoreLabel)

        let hs = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hs.text = "BEST  \(highScore)"
        hs.fontSize = 16
        hs.fontColor = SKColor.white.withAlphaComponent(0.7)
        hs.position = CGPoint(x: size.width / 2, y: size.height * 0.46)
        addChild(hs)

        let tap = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        tap.text = "TAP TO FLOW AGAIN"
        tap.fontSize = 18
        tap.fontColor = .white
        tap.position = CGPoint(x: size.width / 2, y: size.height * 0.28)
        tap.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])))
        addChild(tap)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let scene = GameScene(size: size)
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: .crossFade(withDuration: 0.4))
    }
}
