import CoreAudio
import Foundation

struct AudioInputDevice: Identifiable, Equatable {
    let id: String
    let deviceID: AudioDeviceID
    let uid: String
    let name: String
    let isDefault: Bool
}

enum AudioInputDeviceManager {
    static func inputDevices() -> [AudioInputDevice] {
        let defaultID = defaultInputDeviceID()
        return allAudioDeviceIDs()
            .filter { inputChannelCount(for: $0) > 0 }
            .compactMap { deviceID in
                guard let uid = stringProperty(kAudioDevicePropertyDeviceUID, for: deviceID),
                      let name = stringProperty(kAudioObjectPropertyName, for: deviceID) else {
                    return nil
                }
                return AudioInputDevice(
                    id: uid,
                    deviceID: deviceID,
                    uid: uid,
                    name: name,
                    isDefault: deviceID == defaultID
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDefault != rhs.isDefault {
                    return lhs.isDefault
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        inputDevices().first { $0.uid == uid }?.deviceID
    }

    static func defaultInputDeviceName() -> String? {
        guard let defaultID = defaultInputDeviceID() else { return nil }
        return stringProperty(kAudioObjectPropertyName, for: defaultID)
    }

    private static func allAudioDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(systemObjectID, &address, 0, nil, &dataSize) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }

        var devices = [AudioDeviceID](repeating: 0, count: count)
        let status = AudioObjectGetPropertyData(systemObjectID, &address, 0, nil, &dataSize, &devices)
        return status == noErr ? devices : []
    }

    private static func defaultInputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        return status == noErr && deviceID != 0 ? deviceID : nil
    }

    private static func stringProperty(_ selector: AudioObjectPropertySelector, for deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value)
        return status == noErr ? value?.takeUnretainedValue() as String? : nil
    }

    private static func inputChannelCount(for deviceID: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0 else {
            return 0
        }

        let bufferListPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferListPointer.deallocate() }

        let audioBufferList = bufferListPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, audioBufferList)
        guard status == noErr else { return 0 }

        return UnsafeMutableAudioBufferListPointer(audioBufferList)
            .reduce(0) { $0 + Int($1.mNumberChannels) }
    }
}
