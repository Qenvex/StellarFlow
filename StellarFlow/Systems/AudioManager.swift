import Foundation
import AVFoundation

/// 게임 내 모든 오디오 재생을 담당하는 싱글톤.
/// - BGM: `AVAudioPlayer` (루프 + 페이드 인/아웃)
/// - SFX: 풀링된 `AVAudioPlayer` (짧은 효과음 일회 재생)
/// - 번들에 해당 파일이 없으면 조용히 무시 — 에셋이 부분 준비 상태여도 게임 크래시 없음.
final class AudioManager {

    static let shared = AudioManager()

    // MARK: - Persisted settings

    private enum Keys {
        static let muted = "audio.muted"
        static let musicVolume = "audio.musicVolume"
        static let sfxVolume = "audio.sfxVolume"
    }

    var isMuted: Bool {
        get { UserDefaults.standard.object(forKey: Keys.muted) as? Bool ?? false }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.muted)
            applyVolumes()
        }
    }

    /// 0.0 ~ 1.0
    var musicVolume: Float {
        get { UserDefaults.standard.object(forKey: Keys.musicVolume) as? Float ?? 0.6 }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.musicVolume)
            applyVolumes()
        }
    }

    /// 0.0 ~ 1.0
    var sfxVolume: Float {
        get { UserDefaults.standard.object(forKey: Keys.sfxVolume) as? Float ?? 0.8 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.sfxVolume) }
    }

    // MARK: - Internal state

    private var bgmPlayer: AVAudioPlayer?
    private var currentBGMName: String?

    /// 동시 SFX 재생을 위한 플레이어 풀.
    private var sfxPlayers: [AVAudioPlayer] = []
    private let sfxPoolLimit = 8

    /// 번들에서 찾을 확장자 (우선순위 순)
    private let supportedExtensions = ["m4a", "mp3", "caf", "wav", "aac"]

    private init() {
        configureAudioSession()
    }

    // MARK: - Audio session

    private func configureAudioSession() {
        #if os(iOS)
        do {
            // Ambient — 다른 앱 오디오(예: 사용자가 틀어둔 음악)를 방해하지 않음
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // 오디오 세션 설정 실패 — 치명적이지 않으므로 무시
        }
        #endif
    }

    // MARK: - File lookup

    private func urlForResource(named name: String) -> URL? {
        for ext in supportedExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    // MARK: - BGM

    /// BGM 재생. 같은 이름이 이미 재생 중이면 무시.
    /// 파일이 번들에 없으면 no-op.
    func playBGM(named name: String, fadeIn: TimeInterval = 1.0) {
        if currentBGMName == name, bgmPlayer?.isPlaying == true { return }

        guard let url = urlForResource(named: name) else {
            // 파일이 없으면 현재 재생 중이던 것만 유지
            return
        }

        // 기존 BGM 페이드아웃 후 교체
        let previous = bgmPlayer
        previous?.setVolume(0, fadeDuration: fadeIn)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeIn) {
            previous?.stop()
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1   // infinite loop
            player.volume = 0
            player.prepareToPlay()
            player.play()
            player.setVolume(effectiveMusicVolume(), fadeDuration: fadeIn)
            bgmPlayer = player
            currentBGMName = name
        } catch {
            // 재생 실패 — 조용히 무시
        }
    }

    /// 현재 BGM 정지 (페이드아웃 후).
    func stopBGM(fadeOut: TimeInterval = 0.8) {
        guard let player = bgmPlayer else { return }
        player.setVolume(0, fadeDuration: fadeOut)
        let target = player
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut) { [weak self] in
            target.stop()
            if self?.bgmPlayer === target {
                self?.bgmPlayer = nil
                self?.currentBGMName = nil
            }
        }
    }

    /// 씬 전환 중 임시 일시정지 (Pause 오버레이 등에서 호출).
    func pauseBGM() { bgmPlayer?.pause() }
    func resumeBGM() {
        if let p = bgmPlayer, !p.isPlaying { p.play() }
    }

    // MARK: - SFX

    /// 짧은 효과음 일회 재생. 파일이 없으면 no-op.
    /// `volumeScale`은 0...1 — 최종 볼륨은 `sfxVolume * volumeScale * (muted ? 0 : 1)`.
    func playSFX(named name: String, volumeScale: Float = 1.0) {
        guard let url = urlForResource(named: name) else { return }

        // 재사용 가능한 플레이어 찾기 (재생이 끝난 것)
        if let idle = sfxPlayers.first(where: { !$0.isPlaying }),
           idle.url == url {
            idle.volume = effectiveSFXVolume(scale: volumeScale)
            idle.currentTime = 0
            idle.play()
            return
        }

        // 새 플레이어 생성
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = effectiveSFXVolume(scale: volumeScale)
            player.prepareToPlay()
            player.play()

            // 풀 관리 — 제한 초과 시 가장 오래된(정지된) 것 제거
            if sfxPlayers.count >= sfxPoolLimit {
                if let idx = sfxPlayers.firstIndex(where: { !$0.isPlaying }) {
                    sfxPlayers.remove(at: idx)
                }
            }
            sfxPlayers.append(player)
        } catch {
            // 재생 실패 — 무시
        }
    }

    // MARK: - Volume helpers

    private func effectiveMusicVolume() -> Float {
        isMuted ? 0 : musicVolume
    }

    private func effectiveSFXVolume(scale: Float) -> Float {
        isMuted ? 0 : sfxVolume * scale
    }

    private func applyVolumes() {
        bgmPlayer?.volume = effectiveMusicVolume()
    }

    // MARK: - Debug

    /// 현재 번들에 존재하는 BGM 파일 이름 목록 (확장자 제외). UI용.
    func availableBGMNames() -> [String] {
        // 번들 디렉터리를 스캔하기는 제한적이므로, CustomizationCatalog가 등록한 목록을 쓰는 편이 더 낫다.
        // 여기서는 공지된 후보만 체크.
        let candidates = ["menu", "game", "gameover"]
        return candidates.filter { urlForResource(named: $0) != nil }
    }
}
