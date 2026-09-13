import CoreAudio
import Foundation

final class CoreAudioDeviceController {
    private let systemObject = AudioObjectID(kAudioObjectSystemObject)

    func defaultDevice(isInput: Bool) -> AudioDevice {
        let selector = isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &deviceID)

        let control = readVolume(deviceID: deviceID, isInput: isInput)
        let mute = readMute(deviceID: deviceID, isInput: isInput)

        return AudioDevice(
            id: deviceID,
            uid: readUID(deviceID: deviceID),
            name: readName(deviceID: deviceID, fallback: isInput ? "Input Device" : "Output Device"),
            volume: control.volume,
            isMuted: mute.value,
            canSetVolume: control.canSet,
            canSetMute: mute.canSet,
            isInput: isInput
        )
    }

    private func readUID(deviceID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard hasProperty(deviceID, address: &address) else {
            return nil
        }

        var uid: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &uid) { pointer in
            pointer.withMemoryRebound(to: CFString.self, capacity: 1) { reboundPointer in
                AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, reboundPointer)
            }
        }

        return status == noErr ? uid as String? : nil
    }

    func setVolume(_ volume: Double, for device: AudioDevice) {
        let clamped = min(max(volume, 0), 1)
        let scope = device.isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
        let elements = [kAudioObjectPropertyElementMain, 1, 2]

        for element in elements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: scope,
                mElement: AudioObjectPropertyElement(element)
            )
            guard hasProperty(device.id, address: &address), isSettable(device.id, address: &address) else {
                continue
            }

            var value = Float32(clamped)
            let size = UInt32(MemoryLayout<Float32>.size)
            AudioObjectSetPropertyData(device.id, &address, 0, nil, size, &value)
        }
    }

    func setMuted(_ muted: Bool, for device: AudioDevice) {
        let scope = device.isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
        let elements = [kAudioObjectPropertyElementMain, 1, 2]

        for element in elements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: scope,
                mElement: AudioObjectPropertyElement(element)
            )
            guard hasProperty(device.id, address: &address), isSettable(device.id, address: &address) else {
                continue
            }

            var value: UInt32 = muted ? 1 : 0
            let size = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectSetPropertyData(device.id, &address, 0, nil, size, &value)
        }
    }

    private func readName(deviceID: AudioObjectID, fallback: String) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard hasProperty(deviceID, address: &address) else {
            return fallback
        }

        var name: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &name) { pointer in
            pointer.withMemoryRebound(to: CFString.self, capacity: 1) { reboundPointer in
                AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, reboundPointer)
            }
        }

        return status == noErr ? (name as String? ?? fallback) : fallback
    }

    private func readVolume(deviceID: AudioObjectID, isInput: Bool) -> (volume: Double, canSet: Bool) {
        let scope = isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
        let elements = [kAudioObjectPropertyElementMain, 1, 2]
        var values: [Double] = []
        var canSet = false

        for element in elements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: scope,
                mElement: AudioObjectPropertyElement(element)
            )
            guard hasProperty(deviceID, address: &address) else {
                continue
            }

            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
            if status == noErr {
                values.append(Double(value))
                canSet = canSet || isSettable(deviceID, address: &address)
            }
        }

        guard !values.isEmpty else {
            return (0.75, false)
        }

        return (values.reduce(0, +) / Double(values.count), canSet)
    }

    private func readMute(deviceID: AudioObjectID, isInput: Bool) -> (value: Bool, canSet: Bool) {
        let scope = isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
        let elements = [kAudioObjectPropertyElementMain, 1, 2]

        for element in elements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: scope,
                mElement: AudioObjectPropertyElement(element)
            )
            guard hasProperty(deviceID, address: &address) else {
                continue
            }

            var value: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
            if status == noErr {
                return (value != 0, isSettable(deviceID, address: &address))
            }
        }

        return (false, false)
    }

    private func hasProperty(_ objectID: AudioObjectID, address: inout AudioObjectPropertyAddress) -> Bool {
        AudioObjectHasProperty(objectID, &address)
    }

    private func isSettable(_ objectID: AudioObjectID, address: inout AudioObjectPropertyAddress) -> Bool {
        var settable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(objectID, &address, &settable)
        return status == noErr && settable.boolValue
    }
}
