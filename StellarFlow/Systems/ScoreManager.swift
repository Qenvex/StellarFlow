import Foundation

final class ScoreManager {

    private static let highScoreKey = "stellarflow.highScore"

    private(set) var score: Int = 0

    var highScore: Int {
        get { UserDefaults.standard.integer(forKey: Self.highScoreKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.highScoreKey) }
    }

    func reset() { score = 0 }

    /// 궤도 포획 성공 시 호출. 행성 kind별로 가점.
    func gain(forCatchOf kind: PlanetKind) {
        switch kind {
        case .standard:  score += 100
        case .attractor: score += 180   // 위험 보상
        case .repulsor:  score += 160
        case .booster:   score += 200
        case .pulsar:    score += 250
        case .blackHole: score += 400
        case .asteroid:  break          // 캐치 불가
        }
    }

    /// 궤도에서 공전한 시간만큼 소소한 가점 (초당).
    func gainOrbitTime(_ dt: TimeInterval) {
        score += Int(dt * 10)
    }

    /// 높이·거리 기반 가점.
    func gainAltitude(_ amount: Int) {
        score += Swift.max(0, amount)
    }

    @discardableResult
    func commitIfHighScore() -> Bool {
        if score > highScore {
            highScore = score
            return true
        }
        return false
    }
}
