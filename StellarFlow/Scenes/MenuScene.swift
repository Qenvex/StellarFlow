import SpriteKit

final class MenuScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = SKColor.fromHex(0x060514)
        scaleMode = .resizeFill

        seedStars()
        buildUI()

        // BGM 시작 — 파일이 없으면 no-op
        AudioManager.shared.playBGM(named: "menu", fadeIn: 1.2)
    }

    private func seedStars() {
        for _ in 0..<120 {
            let r: CGFloat = CGFloat.random(in: 0.5...1.6)
            let s = SKShapeNode(circleOfRadius: r)
            s.fillColor = SKColor.white.withAlphaComponent(CGFloat.random(in: 0.3...0.9))
            s.strokeColor = .clear
            s.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            addChild(s)
        }
    }

    private func buildUI() {
        let title = SKLabelNode(fontNamed: "AvenirNext-UltraLight")
        title.text = "STELLAR FLOW"
        title.fontSize = 42
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Regular")
        subtitle.text = "ride the gravity. flow the stars."
        subtitle.fontSize = 14
        subtitle.fontColor = SKColor.white.withAlphaComponent(0.7)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.56)
        addChild(subtitle)

        let highScore = UserDefaults.standard.integer(forKey: "stellarflow.highScore")
        if highScore > 0 {
            let hs = SKLabelNode(fontNamed: "AvenirNext-Medium")
            hs.text = "BEST  \(highScore)"
            hs.fontSize = 16
            hs.fontColor = SKColor.white.withAlphaComponent(0.85)
            hs.position = CGPoint(x: size.width / 2, y: size.height * 0.5)
            addChild(hs)
        }

        let tap = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        tap.text = "TAP TO START"
        tap.fontSize = 18
        tap.fontColor = .white
        tap.position = CGPoint(x: size.width / 2, y: size.height * 0.32)
        tap.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.25, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])))
        addChild(tap)

        // 미니 데모 — 한 행성이 돌고 있는 일러스트
        let demo = SKNode()
        demo.position = CGPoint(x: size.width / 2, y: size.height * 0.18)
        let core = SKShapeNode(circleOfRadius: 14)
        core.fillColor = SKColor.fromHex(0x8FC7FF)
        core.strokeColor = .clear
        core.glowWidth = 4
        demo.addChild(core)
        let orbit = SKShapeNode(circleOfRadius: 40)
        orbit.strokeColor = SKColor.white.withAlphaComponent(0.3)
        orbit.lineWidth = 1
        orbit.fillColor = .clear
        demo.addChild(orbit)
        let dot = SKShapeNode(circleOfRadius: 3)
        dot.fillColor = .white
        dot.glowWidth = 3
        let path = CGPath(ellipseIn: CGRect(x: -40, y: -40, width: 80, height: 80), transform: nil)
        dot.run(SKAction.repeatForever(
            SKAction.follow(path, asOffset: false, orientToPath: false, duration: 3.0)
        ))
        demo.addChild(dot)
        addChild(demo)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        AudioManager.shared.playSFX(named: "ui_tap")
        let scene = GameScene(size: size)
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: .crossFade(withDuration: 0.5))
    }
}
