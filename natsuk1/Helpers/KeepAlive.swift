import AVFoundation
import CoreLocation
import Foundation
import Combine
nonisolated final class KeepAlive: NSObject, @unchecked Sendable {
static let shared = KeepAlive()
private(set) var audioActive: Bool = false
private(set) var locationActive: Bool = false
private var player: AVAudioPlayer?
private var locationManager: CLLocationManager?
override init() {
super.init()
}
func startAudio() {
guard !audioActive else { return }
do {
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
try session.setActive(true)
let wav = Self.silentWavData()
let url = FileManager.default.temporaryDirectory
.appendingPathComponent("keepalive.wav")
try wav.write(to: url)
let p = try AVAudioPlayer(contentsOf: url)
p.numberOfLoops = -1
p.volume = 0.0
p.prepareToPlay()
p.play()
player = p
audioActive = true
} catch {
NSLog("[KeepAlive] audio failed: \(error)")
audioActive = false
}
}
func stopAudio() {
guard audioActive else { return }
player?.stop()
player = nil
audioActive = false
}
func stopAll() {
stopAudio()
stopLocation()
}
func startLocation() {
guard !locationActive else { return }
let m = CLLocationManager()
m.delegate = self
m.desiredAccuracy = kCLLocationAccuracyThreeKilometers
m.distanceFilter = 3000
m.pausesLocationUpdatesAutomatically = false
m.allowsBackgroundLocationUpdates = true
m.showsBackgroundLocationIndicator = false
let status = m.authorizationStatus
if status == .notDetermined {
m.requestAlwaysAuthorization()
} else if status == .authorizedAlways || status == .authorizedWhenInUse {
m.startUpdatingLocation()
locationActive = true
}
locationManager = m
}
func stopLocation() {
locationManager?.stopUpdatingLocation()
locationManager = nil
locationActive = false
}
private static func silentWavData() -> Data {
let sampleRate: UInt32 = 8000
let channels: UInt16 = 1
let bitsPerSample: UInt16 = 16
let durationSec: UInt32 = 1
let numSamples = sampleRate * durationSec
let blockAlign = channels * bitsPerSample / 8
let byteRate = sampleRate * UInt32(blockAlign)
let dataSize = numSamples * UInt32(blockAlign)
var d = Data()
func u32(_ v: UInt32) {
var x = v.littleEndian
withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
}
func u16(_ v: UInt16) {
var x = v.littleEndian
withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
}
func str(_ s: String) { d.append(contentsOf: Array(s.utf8)) }
str("RIFF"); u32(36 + dataSize); str("WAVE")
str("fmt "); u32(16); u16(1); u16(channels)
u32(sampleRate); u32(byteRate); u16(blockAlign); u16(bitsPerSample)
str("data"); u32(dataSize)
d.append(Data(repeating: 0, count: Int(dataSize)))
return d
}
}
extension KeepAlive: CLLocationManagerDelegate {
func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
let status = manager.authorizationStatus
if status == .authorizedAlways || status == .authorizedWhenInUse {
manager.startUpdatingLocation()
locationActive = true
} else if status == .denied || status == .restricted {
locationActive = false
}
}
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
}
func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
NSLog("[KeepAlive] location error: \(error)")
}
}
