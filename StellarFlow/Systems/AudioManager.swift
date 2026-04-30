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
        ensureSessionActive()
    }

    /// 매 재생 직전 안전하게 호출 가능. category 미설정/비활성 상태면 다시 설정한다.
    private func ensureSessionActive() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            // soloAmbient — 다른 앱 음악은 정지, 무음 스위치는 따름.
            if session.category != .soloAmbient {
                try session.setCategory(.soloAmbient, mode: .default, options: [])
            }
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("[AudioManager] AVAudioSession activate failed: \(error)")
            #endif
        }
        #endif
    }

    // MARK: - File lookup

    /// 번들에서 오디오 파일 위치 탐색.
    /// Audio/ 가 파란 폴더 참조로 번들된 경우, `Bundle.main.url(forResource:withExtension:)`은
    /// 최상위만 검색하므로 `subdirectory:`를 명시해 하위 폴더까지 살핀다.
    private let resourceSearchPaths: [String?] = [
        nil,            // 번들 루트 (노란 그룹 또는 평탄화된 리소스)
        "Audio/BGM",
        "Audio/SFX",
        "Audio"
    ]

    private func urlForResource(named name: String) -> URL? {
        for ext in supportedExtensions {
            for subdir in resourceSearchPaths {
                if let url = Bundle.main.url(forResource: name,
                                             withExtension: ext,
                                             subdirectory: subdir) {
                    return url
                }
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
            #if DEBUG
            print("[AudioManager] BGM not found in bundle: \(name)")
            #endif
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

    /// 지정된 SFX들을 미리 메모리에 로드 (씬 진입 직전 호출 권장).
    /// 첫 재생 시의 AVAudioPlayer 할당으로 인한 메인 스레드 hitch를 방지.
    func preloadSFX(names: [String]) {
        for name in names {
            guard let url = urlForResource(named: name) else { continue }
            // 이미 같은 URL 플레이어가 있다면 스킵
            if sfxPlayers.contains(where: { $0.url == url }) { continue }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = 0  // 프리로드 — 무음 상태로 prepare만
                player.prepareToPlay()
                sfxPlayers.append(player)
                #if DEBUG
                print("[AudioManager] preloaded SFX: \(name)")
                #endif
            } catch {
                #if DEBUG
                print("[AudioManager] preload failed for '\(name)': \(error)")
                #endif
            }
        }
    }

    /// 짧은 효과음 일회 재생. 파일이 없으면 no-op.
    /// `volumeScale`은 0...1 — 최종 볼륨은 `sfxVolume * volumeScale * (muted ? 0 : 1)`.
    func playSFX(named name: String, volumeScale: Float = 1.0) {
        guard let url = urlForResource(named: name) else {
            #if DEBUG
            print("[AudioManager] SFX not found in bundle: \(name)")
            #endif
            return
        }

        ensureSessionActive()

        // 재사용 가능한 플레이어 찾기 (재생이 끝난 것)
        if let idle = sfxPlayers.first(where: { !$0.isPlaying }),
           idle.url == url {
            idle.volume = effectiveSFXVolume(scale: volumeScale)
            idle.currentTime = 0
            let ok = idle.play()
            #if DEBUG
            print("[AudioManager] SFX replay '\(name)' play()=\(ok) vol=\(idle.volume)")
            #endif
            return
        }

        // 새 플레이어 생성
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = effectiveSFXVolume(scale: volumeScale)
            player.prepareToPlay()
            let ok = player.play()
            #if DEBUG
            let session = AVAudioSession.sharedInstance()
            print("[AudioManager] SFX new '\(name)' play()=\(ok) vol=\(player.volume) " +
                  "duration=\(player.duration) isPlaying=\(player.isPlaying) " +
                  "session.category=\(session.category.rawValue) " +
                  "outputVol=\(session.outputVolume)")
            #endif

            // 풀 관리 — 제한 초과 시 가장 오래된(정지된) 것 제거
            if sfxPlayers.count >= sfxPoolLimit {
                if let idx = sfxPlayers.firstIndex(where: { !$0.isPlaying }) {
                    sfxPlayers.remove(at: idx)
                }
            }
            sfxPlayers.append(player)
        } catch {
            #if DEBUG
            print("[AudioManager] SFX init failed for '\(name)' at \(url.path): \(error)")
            #endif
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
