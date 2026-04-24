import SpriteKit
import GameplayKit
import UIKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - 상태

    private enum PlayerState {
        /// 동적 궤도 — radius와 speedMultiplier가 효과에 의해 시간에 따라 변할 수 있음.
        case orbiting(planet: PlanetNode, angle: CGFloat, direction: CGFloat,
                      radius: CGFloat, speedMultiplier: CGFloat)
        case flying(velocity: CGVector)
        case dead
    }

    private var state: PlayerState = .flying(velocity: .zero)

    // MARK: - 노드

    private let worldNode = SKNode()
    private let backgroundNode = SKNode()
    private lazy var player: PlayerNode = PlayerNode(radius: 6)

    // HUD
    private var cameraNode: SKCameraNode!
    private var scoreLabel: SKLabelNode!
    private var hintLabel: SKLabelNode?
    private var pauseButton: SKNode!
    private var pauseOverlay: SKNode?

    // MARK: - 일시정지

    private var isGamePaused = false

    // MARK: - 시스템

    private var generator: WorldGenerator!
    private var score = ScoreManager()
    private var chaser: VoidChaserNode?
    private let chaserActivationScore: Int = 300

    // MARK: - 입력

    private var isHolding: Bool = false

    // MARK: - 카메라

    private let cameraLead: CGFloat = 180   // 플레이어를 화면 아래쪽 1/3 근처에 두기 위함
    private var cameraFollowRate: CGFloat = 4.0

    // MARK: - 타이밍

    private var lastUpdate: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var maxHeight: CGFloat = 0

    // MARK: - Life cycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor.fromHex(0x060514)
        scaleMode = .resizeFill

        setupPhysics()
        setupBackground()
        setupCamera()
        setupWorld()
        setupPlayer()
        setupHUD()
        showStartHint()
    }

    private func setupPhysics() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }

    private func setupBackground() {
        backgroundNode.zPosition = -100
        addChild(backgroundNode)
        seedStars()
    }

    private func seedStars() {
        // 다층 별 배경 (패럴랙스)
        for layer in 0..<3 {
            let container = SKNode()
            container.zPosition = CGFloat(-100 + layer)
            container.name = "starLayer\(layer)"
            let count = 60 + layer * 30
            let brightness: CGFloat = 0.3 + CGFloat(layer) * 0.2
            for _ in 0..<count {
                let r: CGFloat = CGFloat.random(in: 0.5...1.6)
                let s = SKShapeNode(circleOfRadius: r)
                s.fillColor = SKColor.white.withAlphaComponent(brightness)
                s.strokeColor = .clear
                s.position = CGPoint(
                    x: CGFloat.random(in: -size.width...size.width),
                    y: CGFloat.random(in: -size.height...size.height * 2)
                )
                container.addChild(s)
            }
            backgroundNode.addChild(container)
        }
    }

    private func setupCamera() {
        let cam = SKCameraNode()
        self.camera = cam
        addChild(cam)
        cameraNode = cam
    }

    private func setupWorld() {
        addChild(worldNode)
        generator = WorldGenerator(worldWidth: size.width, worldHeight: size.height)
        generator.scene = self
        generator.worldNode = worldNode
    }

    private func setupPlayer() {
        // 첫 행성 배치 (화면 중앙 하단)
        let firstPos = CGPoint(x: 0, y: -size.height * 0.1)
        let first = generator.seedInitialPlanets(firstPosition: firstPos)

        // 다음 행성들 미리 생성
        generator.ensurePlanetsAhead(cameraTopY: 0)

        // 플레이어를 첫 행성 궤도에 배치
        let startAngle: CGFloat = -.pi / 2
        let direction: CGFloat = 1
        let r0 = first.currentOrbitRadius
        player.position = first.position + CGPoint(x: cos(startAngle) * r0,
                                                   y: sin(startAngle) * r0)
        worldNode.addChild(player)
        if let trail = player.trail { trail.targetNode = worldNode }

        state = .orbiting(planet: first, angle: startAngle, direction: direction,
                          radius: r0, speedMultiplier: 1.0)
    }

    private func setupHUD() {
        let topInset: CGFloat = view?.safeAreaInsets.top ?? 44

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.fontSize = 28
        label.fontColor = SKColor.white.withAlphaComponent(0.9)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: 0, y: size.height / 2 - topInset - 12)
        label.zPosition = 1000
        label.text = "0"
        cameraNode.addChild(label)
        scoreLabel = label

        // Pause 버튼 — 우상단
        let btn = SKNode()
        btn.name = "pauseButton"
        btn.zPosition = 1000
        btn.position = CGPoint(x: size.width / 2 - 28, y: size.height / 2 - topInset - 24)

        // 히트 영역 (투명)
        let hit = SKShapeNode(rect: CGRect(x: -22, y: -22, width: 44, height: 44), cornerRadius: 10)
        hit.fillColor = SKColor.white.withAlphaComponent(0.001)
        hit.strokeColor = .clear
        hit.name = "pauseButton"
        btn.addChild(hit)

        // 두 개의 세로 바 (||)
        let barWidth: CGFloat = 4
        let barHeight: CGFloat = 16
        for dx in [CGFloat(-5), CGFloat(5)] {
            let bar = SKShapeNode(rect: CGRect(x: dx - barWidth/2, y: -barHeight/2,
                                               width: barWidth, height: barHeight),
                                  cornerRadius: 1.5)
            bar.fillColor = SKColor.white.withAlphaComponent(0.85)
            bar.strokeColor = .clear
            bar.name = "pauseButton"
            btn.addChild(bar)
        }
        cameraNode.addChild(btn)
        pauseButton = btn
    }

    private func togglePause() {
        if isGamePaused { resumeGame() } else { pauseGame() }
    }

    private func pauseGame() {
        if case .dead = state { return }
        isGamePaused = true
        isHolding = false
        showPauseOverlay()
        Haptics.impact(.light)
    }

    private func showPauseOverlay() {
        if pauseOverlay != nil { return }
        let overlay = SKNode()
        overlay.zPosition = 2000

        let bg = SKShapeNode(rect: CGRect(x: -size.width, y: -size.height,
                                          width: size.width * 2, height: size.height * 2))
        bg.fillColor = SKColor.black.withAlphaComponent(0.55)
        bg.strokeColor = .clear
        bg.name = "pauseBg"
        overlay.addChild(bg)

        let title = SKLabelNode(fontNamed: "AvenirNext-UltraLight")
        title.text = "PAUSED"
        title.fontSize = 36
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 80)
        overlay.addChild(title)

        let resume = menuButton(text: "RESUME", name: "resumeButton", y: 10)
        overlay.addChild(resume)

        let quit = menuButton(text: "QUIT", name: "quitButton", y: -50)
        overlay.addChild(quit)

        cameraNode.addChild(overlay)
        pauseOverlay = overlay
    }

    private func menuButton(text: String, name: String, y: CGFloat) -> SKNode {
        let container = SKNode()
        container.position = CGPoint(x: 0, y: y)
        container.name = name

        let bg = SKShapeNode(rect: CGRect(x: -90, y: -20, width: 180, height: 40), cornerRadius: 20)
        bg.fillColor = SKColor.white.withAlphaComponent(0.08)
        bg.strokeColor = SKColor.white.withAlphaComponent(0.4)
        bg.lineWidth = 1
        bg.name = name
        container.addChild(bg)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = name
        container.addChild(label)

        return container
    }

    private func resumeGame() {
        isGamePaused = false
        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
    }

    private func quitToMenu() {
        let menu = MenuScene(size: size)
        menu.scaleMode = scaleMode
        view?.presentScene(menu, transition: .crossFade(withDuration: 0.4))
    }

    private func showStartHint() {
        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hint.fontSize = 16
        hint.fontColor = SKColor.white.withAlphaComponent(0.8)
        hint.text = "TAP to launch · HOLD to catch orbit"
        let bottomInset: CGFloat = view?.safeAreaInsets.bottom ?? 34
        hint.position = CGPoint(x: 0, y: -size.height/2 + bottomInset + 48)
        hint.zPosition = 1000
        cameraNode.addChild(hint)
        hint.run(SKAction.sequence([
            SKAction.wait(forDuration: 4.0),
            SKAction.fadeOut(withDuration: 0.8),
            SKAction.removeFromParent()
        ]))
        hintLabel = hint
    }

    // MARK: - 입력

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        // HUD 버튼 우선 처리 (paused 중에도 버튼은 동작)
        let locInCamera = touch.location(in: cameraNode)
        for node in cameraNode.nodes(at: locInCamera) {
            switch node.name {
            case "pauseButton":
                togglePause()
                return
            case "resumeButton":
                resumeGame()
                return
            case "quitButton":
                quitToMenu()
                return
            case "pauseBg":
                return   // 오버레이 바탕 탭은 무시 (실수 방지)
            default:
                continue
            }
        }

        if isGamePaused { return }

        isHolding = true
        switch state {
        case .orbiting:
            break
        case .flying:
            tryCatch()
        case .dead:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGamePaused { return }
        isHolding = false
        switch state {
        case .orbiting(let planet, let angle, let direction, let radius, let speedMultiplier):
            launchFromOrbit(planet: planet, angle: angle, direction: direction,
                            radius: radius, speedMultiplier: speedMultiplier)
        case .flying, .dead:
            break
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - 유틸

    /// 지수 감쇠 기반 부드러운 수렴 (프레임-레이트 독립).
    /// rate가 클수록 빠르게 수렴. rate=7이면 약 0.4초 안에 ~90% 도달.
    private func smoothApproach(_ current: CGFloat, toward target: CGFloat,
                                dt: CGFloat, rate: CGFloat) -> CGFloat {
        let factor = 1 - exp(-rate * dt)
        return current + (target - current) * factor
    }

    // MARK: - 코어 로직

    /// 현재 궤도에서 이탈 — 접선 방향으로 튕겨 날아감.
    private func launchFromOrbit(planet: PlanetNode, angle: CGFloat, direction: CGFloat,
                                 radius: CGFloat, speedMultiplier: CGFloat) {
        let omega = abs(planet.angularSpeed) * speedMultiplier
        let linearSpeed = omega * radius

        // 접선 벡터 — 궤도 방향(direction)에 맞춰
        let tangent = CGPoint(x: -sin(angle), y: cos(angle)) * direction
        let velocity = CGVector(dx: tangent.x * linearSpeed, dy: tangent.y * linearSpeed)

        // 최소 속도 보정 — 너무 느린 행성에서 발사해도 어느 정도는 날아가도록
        let minSpeed: CGFloat = 260
        let mag = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        let finalVelocity: CGVector
        if mag < minSpeed {
            let scale = minSpeed / Swift.max(mag, 0.0001)
            finalVelocity = CGVector(dx: velocity.dx * scale, dy: velocity.dy * scale)
        } else {
            finalVelocity = velocity
        }

        state = .flying(velocity: finalVelocity)
        Haptics.impact(planet.kind == .booster ? .medium : .light)
    }

    /// 비행 중 Hold — 가장 가까운 행성의 중력장 내에 있다면 포획.
    private func tryCatch() {
        guard case .flying(let velocity) = state else { return }

        // 가장 가까운 행성
        let playerPos = player.position
        var bestPlanet: PlanetNode?
        var bestDistance: CGFloat = .infinity
        for planet in generator.activePlanets {
            if planet.kind == .blackHole || planet.kind == .asteroid { continue } // catch 불가
            let d = planet.position.distance(to: playerPos)
            if d < planet.fieldRadius && d < bestDistance {
                bestDistance = d
                bestPlanet = planet
            }
        }
        guard let planet = bestPlanet else { return }

        // 궤도 진입 — 현재 위치 기준 각도를 잡고, 궤도 반경은 현재 거리 유지 (단, 코어 안쪽이면 reject)
        let delta = playerPos - planet.position
        let distance = delta.length
        if distance < planet.coreRadius * 1.4 { return }

        let angle = delta.angle
        // 진입 방향 결정 — 현재 속도의 각운동량 부호로
        let tangentCCW = CGPoint(x: -sin(angle), y: cos(angle))
        let dot = CGPoint(x: velocity.dx, y: velocity.dy).dot(tangentCCW)
        let direction: CGFloat = dot >= 0 ? 1 : -1

        // 포획: 현재 거리를 초기 궤도 반경으로 사용 (순간이동 방지).
        // 이후 update loop에서 planet.currentOrbitRadius로 부드럽게 수렴.
        let r = distance

        // 속도 매칭: 비행 중이던 접선 방향 속도를 궤도 각속도로 변환.
        // 그래야 포획 순간 "쾅" 멈추거나 "슉" 가속되는 느낌 없이 자연스럽게 이어짐.
        let tangentialSpeed = abs(CGPoint(x: velocity.dx, y: velocity.dy).dot(tangentCCW))
        let nominalOmega = Swift.max(abs(planet.angularSpeed), 0.01)
        let incomingOmega = tangentialSpeed / Swift.max(r, 1)
        let initialMultiplier = (incomingOmega / nominalOmega).clamped(0.55, 2.4)

        state = .orbiting(planet: planet, angle: angle, direction: direction,
                          radius: r, speedMultiplier: initialMultiplier)
        score.gain(forCatchOf: planet.kind)
        Haptics.impact(.medium)
        playCatchFlourish(on: planet)
    }

    /// 포획 순간의 짧은 시각 효과 — 중력장 링 펄스 + 플레이어 할로 플래시.
    private func playCatchFlourish(on planet: PlanetNode) {
        planet.pulseCatch()

        // 플레이어 자리에서 퍼지는 원형 충격파
        let ring = SKShapeNode(circleOfRadius: 6)
        ring.strokeColor = SKColor.white.withAlphaComponent(0.7)
        ring.fillColor = .clear
        ring.lineWidth = 1.5
        ring.position = player.position
        ring.zPosition = 7
        ring.blendMode = .add
        worldNode.addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 6.0, duration: 0.35),
                SKAction.fadeOut(withDuration: 0.35)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        // paused 상태 — dt가 점프하지 않도록 lastUpdate만 갱신하고 프레임 스킵
        if isGamePaused {
            lastUpdate = currentTime
            return
        }

        let dt: CGFloat
        if lastUpdate == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = CGFloat(Swift.min(currentTime - lastUpdate, 1.0 / 30.0))
        }
        lastUpdate = currentTime
        elapsed += Double(dt)

        // 행성 업데이트 (펄사 숨쉬기 등)
        for p in generator.activePlanets {
            p.update(dt: dt, elapsed: CGFloat(elapsed))
        }

        // 플레이어 상태 업데이트
        switch state {
        case .orbiting(let planet, var angle, let direction, var radius, var speedMultiplier):
            // kind별 효과 — Hold 중일 때 점진적으로 반경/속도 변화
            let holding = isHolding   // orbit 상태는 Hold 전제지만, 안전하게 명시적 반영
            switch planet.kind {
            case .attractor:
                if holding {
                    let pullRate: CGFloat = 22   // pt/s
                    radius -= pullRate * dt
                    let minR = planet.coreRadius * 1.25
                    if radius <= minR {
                        // 코어에 빨려들어가 사망
                        radius = minR
                        dieFromCrash()
                        break
                    }
                }
            case .repulsor:
                if holding {
                    let pushRate: CGFloat = 28
                    radius += pushRate * dt
                    let maxR = planet.fieldRadius * 1.4
                    if radius >= maxR {
                        // 밀려서 접선 방향으로 튕겨나감
                        radius = maxR
                        launchFromOrbit(planet: planet, angle: angle, direction: direction,
                                        radius: radius, speedMultiplier: speedMultiplier)
                        break
                    }
                }
            case .booster:
                // 공전 속도가 시간에 따라 가속 + 반경은 부드럽게 궤도로 수렴
                speedMultiplier = Swift.min(speedMultiplier + 0.6 * dt, 2.4)
                radius = smoothApproach(radius, toward: planet.currentOrbitRadius, dt: dt, rate: 7.0)
            case .pulsar:
                // 펄사는 planet.currentOrbitRadius가 숨쉬듯 변함 — 부드럽게 따라감
                radius = smoothApproach(radius, toward: planet.currentOrbitRadius, dt: dt, rate: 6.0)
                speedMultiplier = smoothApproach(speedMultiplier, toward: 1.0, dt: dt, rate: 2.5)
            case .standard:
                // 부드럽게 궤도 반경/속도로 수렴 (catch 애니메이션)
                radius = smoothApproach(radius, toward: planet.currentOrbitRadius, dt: dt, rate: 7.0)
                speedMultiplier = smoothApproach(speedMultiplier, toward: 1.0, dt: dt, rate: 2.5)
            case .blackHole, .asteroid:
                break
            }

            if case .dead = state { break }  // die() 가 상태를 바꿨을 수 있음

            angle += abs(planet.angularSpeed) * speedMultiplier * direction * dt
            player.position = planet.position + CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            state = .orbiting(planet: planet, angle: angle, direction: direction,
                              radius: radius, speedMultiplier: speedMultiplier)
            score.gainOrbitTime(Double(dt))

            // 현재 궤도 행성 하이라이트
            for p in generator.activePlanets { p.highlightField(p === planet) }

        case .flying(var velocity):
            // 블랙홀의 중력 굴절 (스윙바이)
            applyBlackHolesBend(velocity: &velocity, dt: dt)

            player.position = CGPoint(x: player.position.x + velocity.dx * dt,
                                      y: player.position.y + velocity.dy * dt)
            state = .flying(velocity: velocity)

            // Hold 중이면 매 프레임 catch 시도 (중력장 진입 순간 포획되도록)
            if isHolding { tryCatch() }

            // 잠재적 포획 후보 하이라이트
            highlightCatchCandidate()

        case .dead:
            break
        }

        // 최대 높이 갱신 + 점수
        if player.position.y > maxHeight {
            let gained = Int((player.position.y - maxHeight) * 0.5)
            score.gainAltitude(gained)
            maxHeight = player.position.y
        }

        // 생성기
        generator.setDifficulty(fromScore: score.score)
        generator.ensurePlanetsAhead(cameraTopY: cameraNode.position.y + size.height / 2)
        generator.updateMeteors(dt: dt)

        // 파괴파 업데이트 / 스폰
        updateVoidChaser(dt: dt)

        // 카메라 추적
        updateCamera(dt: dt)

        // 배경 패럴랙스 (아래 레이어는 덜 움직임)
        updateParallax()

        // 범위 밖 오브젝트 제거
        generator.cullBelow(cameraNode.position.y - size.height)
        generator.enforcePoolLimit(maxPlanets: 18)

        // 실패 조건: 화면 밖으로 심우주 이탈
        checkOutOfBounds()

        // HUD
        scoreLabel.text = "\(score.score)"
    }

    // MARK: - 블랙홀 스윙바이

    private func applyBlackHolesBend(velocity: inout CGVector, dt: CGFloat) {
        for p in generator.activePlanets where p.kind == .blackHole {
            let delta = p.position - player.position
            let distSq = Swift.max(delta.length * delta.length, 100) // 안전 하한
            // 중력 세기 — 거리 제곱 반비례
            let strength: CGFloat = 28000
            let accel = delta.normalized * (strength / distSq)
            velocity.dx += accel.x * dt
            velocity.dy += accel.y * dt
        }
    }

    // MARK: - 후보 하이라이트

    private func highlightCatchCandidate() {
        let playerPos = player.position
        var best: PlanetNode?
        var bestDist: CGFloat = .infinity
        for planet in generator.activePlanets {
            if planet.kind == .blackHole || planet.kind == .asteroid { continue }
            let d = planet.position.distance(to: playerPos)
            if d < planet.fieldRadius && d < bestDist {
                bestDist = d
                best = planet
            }
        }
        for p in generator.activePlanets {
            p.highlightField(p === best)
        }
    }

    // MARK: - 카메라

    private func updateCamera(dt: CGFloat) {
        // 플레이어를 따라 위로 스크롤. 아래로는 절대 내려가지 않음 (최고점 유지).
        let targetY = Swift.max(cameraNode.position.y, player.position.y + cameraLead)
        let lerped = cameraNode.position.y + (targetY - cameraNode.position.y) * Swift.min(1.0, cameraFollowRate * dt)
        cameraNode.position = CGPoint(x: 0, y: lerped)
    }

    private func updateParallax() {
        // 아주 단순한 배경 패럴랙스 — 카메라에 맞춰 레이어 위치 보정
        let camY = cameraNode.position.y
        for (i, layer) in backgroundNode.children.enumerated() {
            let factor: CGFloat = [0.1, 0.3, 0.55][Swift.min(i, 2)]
            layer.position = CGPoint(x: 0, y: camY * (1 - factor))
        }
    }

    // MARK: - 충돌 / 사망

    func didBegin(_ contact: SKPhysicsContact) {
        let cats = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        if cats & PhysicsCategory.player != 0 {
            if cats & PhysicsCategory.planetCore != 0 {
                dieFromCrash()
            } else if cats & PhysicsCategory.meteor != 0 {
                dieFromCrash()
            }
        }
    }

    private func dieFromCrash() { die() }
    private func dieFromFall()  { die() }

    // MARK: - 파괴파

    private func updateVoidChaser(dt: CGFloat) {
        // 점수 임계값 이하에서는 등장하지 않음
        if score.score < chaserActivationScore {
            if let c = chaser { c.removeFromParent(); chaser = nil }
            return
        }

        // 최초 스폰
        if chaser == nil {
            let c = VoidChaserNode(worldWidth: size.width)
            c.reset(initialTopY: cameraNode.position.y - size.height * 1.2)
            worldNode.addChild(c)
            chaser = c
        }

        guard let chaser = chaser else { return }

        // 점수에 따라 상승 속도 증가 (베이스 60, 최대 ~220)
        let extra = CGFloat(Swift.max(0, score.score - chaserActivationScore)) / 20.0
        chaser.ascendSpeed = Swift.min(60 + extra, 220)

        chaser.update(dt: dt)

        // 파의 윗면이 플레이어보다 높으면 사망
        if player.position.y < chaser.topY + 4 {
            dieFromFall()
        }
    }

    private func checkOutOfBounds() {
        // flying 상태에서만 체크 (orbiting 중엔 강제 고정)
        guard case .flying = state else { return }
        let camY = cameraNode.position.y
        let dx = player.position.x
        let dy = player.position.y

        let belowLimit = camY - size.height * 0.8
        let aboveLimit = camY + size.height * 1.2
        let sideLimit: CGFloat = size.width / 2 + 240

        if dy < belowLimit || dy > aboveLimit || abs(dx) > sideLimit {
            dieFromFall()
        }
    }

    private func die() {
        if case .dead = state { return }
        state = .dead
        isHolding = false
        player.pulseDeath()
        Haptics.impact(.heavy)
        let isHigh = score.commitIfHighScore()
        let finalScore = score.score
        let highScore = score.highScore
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.run { [weak self] in
                self?.presentGameOver(finalScore: finalScore, highScore: highScore, isNew: isHigh)
            }
        ]))
    }

    private func presentGameOver(finalScore: Int, highScore: Int, isNew: Bool) {
        let scene = GameOverScene(size: size, finalScore: finalScore, highScore: highScore, newRecord: isNew)
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: .crossFade(withDuration: 0.6))
    }
}

// MARK: - Haptics

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }
}
