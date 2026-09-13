import CoreAudio
import Foundation
import os

struct AppRouteParameters: Equatable {
    var volume: Double
    var isMuted: Bool
    var balance: Double
}

struct AppRouteSnapshot: Equatable {
    var bundleIdentifier: String
    var displayName: String
    var processIdentifier: pid_t
    var processObjectIDs: [AudioObjectID]
    var tapID: AudioObjectID
    var tapUID: String
    var aggregateDeviceID: AudioObjectID
    var streamDescription: String
    var parameters: AppRouteParameters
}

protocol AudioRoutingService: AnyObject {
    func startRouting(app: RunningAudioApp, outputDevice: AudioDevice, profile: AppAudioProfile) throws -> AppRouteSnapshot
    func stopRouting(bundleIdentifier: String) throws
    func stopAll()
    func updateParameters(bundleIdentifier: String, parameters: AppRouteParameters)
    func snapshot(bundleIdentifier: String) -> AppRouteSnapshot?
}

enum AudioRoutingError: LocalizedError {
    case unsupportedOS
    case processNotAvailable(pid_t)
    case matchingProcessNotAvailable(String)
    case outputDeviceMissingUID(String)
    case createTapFailed(OSStatus)
    case createAggregateFailed(OSStatus)
    case createIOProcFailed(OSStatus)
    case startIOFailed(OSStatus)
    case stopIOFailed(OSStatus)
    case destroyIOProcFailed(OSStatus)
    case destroyAggregateFailed(OSStatus)
    case destroyTapFailed(OSStatus)
    case readTapPropertyFailed(String, OSStatus)

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            "Core Audio process taps require macOS 14.2 or later."
        case .processNotAvailable(let pid):
            "No Core Audio process object is available for PID \(pid). Start audio in that app and try again."
        case .matchingProcessNotAvailable(let bundleIdentifier):
            "No Core Audio output process is available for \(bundleIdentifier). Start audio in that app and try again."
        case .outputDeviceMissingUID(let name):
            "The output device “\(name)” does not expose a UID, so it cannot be used in an aggregate route."
        case .createTapFailed(let status):
            "Could not create Core Audio process tap: \(status.osStatusDescription)."
        case .createAggregateFailed(let status):
            "Could not create Core Audio aggregate route: \(status.osStatusDescription)."
        case .createIOProcFailed(let status):
            "Could not create Core Audio route IO callback: \(status.osStatusDescription)."
        case .startIOFailed(let status):
            "Could not start Core Audio route IO: \(status.osStatusDescription)."
        case .stopIOFailed(let status):
            "Could not stop Core Audio route IO: \(status.osStatusDescription)."
        case .destroyIOProcFailed(let status):
            "Could not destroy Core Audio route IO callback: \(status.osStatusDescription)."
        case .destroyAggregateFailed(let status):
            "Could not destroy Core Audio aggregate route: \(status.osStatusDescription)."
        case .destroyTapFailed(let status):
            "Could not destroy Core Audio process tap: \(status.osStatusDescription)."
        case .readTapPropertyFailed(let property, let status):
            "Could not read tap \(property): \(status.osStatusDescription)."
        }
    }
}

final class CoreAudioTapRoutingService: AudioRoutingService {
    private struct ActiveRoute {
        var snapshot: AppRouteSnapshot
        var ioProcID: AudioDeviceIOProcID?
        var dspState: RouteDSPState
        var ioQueue: DispatchQueue
    }

    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private var routes: [String: ActiveRoute] = [:]

    deinit {
        stopAll()
    }

    func startRouting(app: RunningAudioApp, outputDevice: AudioDevice, profile: AppAudioProfile) throws -> AppRouteSnapshot {
        guard #available(macOS 14.2, *) else {
            throw AudioRoutingError.unsupportedOS
        }

        if let existing = routes[app.bundleIdentifier]?.snapshot {
            return existing
        }

        guard let outputDeviceUID = outputDevice.uid else {
            throw AudioRoutingError.outputDeviceMissingUID(outputDevice.name)
        }

        let processObjectIDs = try processObjectIDs(for: app)
        let description = CATapDescription(stereoMixdownOfProcesses: processObjectIDs)
        description.name = "AudioMixerClone Tap - \(app.name)"
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped
        
        var tapID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(description, &tapID)
        guard status == noErr, tapID != kAudioObjectUnknown else {
            throw AudioRoutingError.createTapFailed(status)
        }

        let tapUID = try readTapUID(tapID: tapID)
        let format = try readTapFormat(tapID: tapID)
        let aggregateDeviceID = try createAggregateDevice(
            appName: app.name,
            outputDeviceUID: outputDeviceUID,
            tapUID: tapUID
        )

        let parameters = AppRouteParameters(
            volume: profile.volume,
            isMuted: profile.isMuted,
            balance: profile.balance
        )
        let dspState = RouteDSPState(parameters: parameters)
        let ioQueue = DispatchQueue(label: "com.example.AudioMixerClone.route.\(app.bundleIdentifier)", qos: .userInteractive)
        var ioProcID: AudioDeviceIOProcID?
        let createIOStatus = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateDeviceID, ioQueue) { _, inputData, _, outputData, _ in
            dspState.render(inputData: inputData, outputData: outputData)
        }
        guard createIOStatus == noErr, let ioProcID else {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            AudioHardwareDestroyProcessTap(tapID)
            throw AudioRoutingError.createIOProcFailed(createIOStatus)
        }

        let startStatus = AudioDeviceStart(aggregateDeviceID, ioProcID)
        guard startStatus == noErr else {
            AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            AudioHardwareDestroyProcessTap(tapID)
            throw AudioRoutingError.startIOFailed(startStatus)
        }

        let snapshot = AppRouteSnapshot(
            bundleIdentifier: app.bundleIdentifier,
            displayName: app.name,
            processIdentifier: app.processIdentifier,
            processObjectIDs: processObjectIDs,
            tapID: tapID,
            tapUID: tapUID,
            aggregateDeviceID: aggregateDeviceID,
            streamDescription: format.readableSummary,
            parameters: parameters
        )

        routes[app.bundleIdentifier] = ActiveRoute(
            snapshot: snapshot,
            ioProcID: ioProcID,
            dspState: dspState,
            ioQueue: ioQueue
        )
        return snapshot
    }

    func stopRouting(bundleIdentifier: String) throws {
        guard #available(macOS 14.2, *) else {
            throw AudioRoutingError.unsupportedOS
        }

        guard let route = routes.removeValue(forKey: bundleIdentifier) else {
            return
        }

        if let ioProcID = route.ioProcID {
            let stopStatus = AudioDeviceStop(route.snapshot.aggregateDeviceID, ioProcID)
            guard stopStatus == noErr else {
                throw AudioRoutingError.stopIOFailed(stopStatus)
            }

            let destroyIOStatus = AudioDeviceDestroyIOProcID(route.snapshot.aggregateDeviceID, ioProcID)
            guard destroyIOStatus == noErr else {
                throw AudioRoutingError.destroyIOProcFailed(destroyIOStatus)
            }
        }

        let destroyAggregateStatus = AudioHardwareDestroyAggregateDevice(route.snapshot.aggregateDeviceID)
        guard destroyAggregateStatus == noErr else {
            throw AudioRoutingError.destroyAggregateFailed(destroyAggregateStatus)
        }

        let status = AudioHardwareDestroyProcessTap(route.snapshot.tapID)
        guard status == noErr else {
            throw AudioRoutingError.destroyTapFailed(status)
        }
    }

    func stopAll() {
        let activeRoutes = routes.values
        routes.removeAll()

        guard #available(macOS 14.2, *) else {
            return
        }

        for route in activeRoutes {
            if let ioProcID = route.ioProcID {
                AudioDeviceStop(route.snapshot.aggregateDeviceID, ioProcID)
                AudioDeviceDestroyIOProcID(route.snapshot.aggregateDeviceID, ioProcID)
            }
            AudioHardwareDestroyAggregateDevice(route.snapshot.aggregateDeviceID)
            AudioHardwareDestroyProcessTap(route.snapshot.tapID)
        }
    }

    func updateParameters(bundleIdentifier: String, parameters: AppRouteParameters) {
        guard var route = routes[bundleIdentifier] else {
            return
        }

        route.dspState.update(parameters)
        route.snapshot.parameters = parameters
        routes[bundleIdentifier] = route
    }

    func snapshot(bundleIdentifier: String) -> AppRouteSnapshot? {
        routes[bundleIdentifier]?.snapshot
    }

    private func processObjectIDs(for app: RunningAudioApp) throws -> [AudioObjectID] {
        let audioProcesses = readAudioProcesses()
        let matching = audioProcesses.filter { process in
            guard let bundleIdentifier = process.bundleIdentifier else {
                return false
            }

            return bundleIdentifier == app.bundleIdentifier ||
                bundleIdentifier.hasPrefix("\(app.bundleIdentifier).")
        }

        let outputMatches = matching.filter(\.isRunningOutput)
        if !outputMatches.isEmpty {
            return outputMatches.map(\.id)
        }

        if !matching.isEmpty {
            return matching.map(\.id)
        }

        if let mainProcessObjectID = try? processObjectID(for: app.processIdentifier) {
            return [mainProcessObjectID]
        }

        throw AudioRoutingError.matchingProcessNotAvailable(app.bundleIdentifier)
    }

    private struct AudioProcessInfo {
        var id: AudioObjectID
        var pid: pid_t?
        var bundleIdentifier: String?
        var isRunningOutput: Bool
    }

    private func readAudioProcesses() -> [AudioProcessInfo] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &dataSize) == noErr else {
            return []
        }

        let processCount = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        guard processCount > 0 else {
            return []
        }

        var processObjectIDs = Array(repeating: AudioObjectID(kAudioObjectUnknown), count: processCount)
        let status = processObjectIDs.withUnsafeMutableBufferPointer { buffer in
            AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, buffer.baseAddress!)
        }
        guard status == noErr else {
            return []
        }

        return processObjectIDs
            .filter { $0 != kAudioObjectUnknown }
            .map { processObjectID in
                AudioProcessInfo(
                    id: processObjectID,
                    pid: readProcessPID(processObjectID),
                    bundleIdentifier: readProcessBundleIdentifier(processObjectID),
                    isRunningOutput: readProcessIsRunningOutput(processObjectID)
                )
            }
    }

    private func processObjectID(for pid: pid_t) throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var processID = pid
        var processObjectID = AudioObjectID(kAudioObjectUnknown)
        var outputSize = UInt32(MemoryLayout<AudioObjectID>.size)
        let qualifierSize = UInt32(MemoryLayout<pid_t>.size)

        let status = withUnsafePointer(to: &processID) { pidPointer in
            AudioObjectGetPropertyData(
                systemObject,
                &address,
                qualifierSize,
                pidPointer,
                &outputSize,
                &processObjectID
            )
        }

        guard status == noErr, processObjectID != kAudioObjectUnknown else {
            throw AudioRoutingError.processNotAvailable(pid)
        }

        return processObjectID
    }

    private func readProcessPID(_ processObjectID: AudioObjectID) -> pid_t? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var value = pid_t(0)
        var size = UInt32(MemoryLayout<pid_t>.size)
        let status = AudioObjectGetPropertyData(processObjectID, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private func readProcessBundleIdentifier(_ processObjectID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var bundleIdentifier: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &bundleIdentifier) { pointer in
            pointer.withMemoryRebound(to: CFString.self, capacity: 1) { reboundPointer in
                AudioObjectGetPropertyData(processObjectID, &address, 0, nil, &size, reboundPointer)
            }
        }

        return status == noErr ? bundleIdentifier as String? : nil
    }

    private func readProcessIsRunningOutput(_ processObjectID: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(processObjectID, &address, 0, nil, &size, &value)
        return status == noErr && value != 0
    }

    private func readTapUID(tapID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var uid: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &uid) { pointer in
            pointer.withMemoryRebound(to: CFString.self, capacity: 1) { reboundPointer in
                AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, reboundPointer)
            }
        }

        guard status == noErr, let uid else {
            throw AudioRoutingError.readTapPropertyFailed("UID", status)
        }

        return uid as String
    }

    private func readTapFormat(tapID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format)
        guard status == noErr else {
            throw AudioRoutingError.readTapPropertyFailed("format", status)
        }

        return format
    }

    private func createAggregateDevice(appName: String, outputDeviceUID: String, tapUID: String) throws -> AudioObjectID {
        let aggregateUID = "com.example.AudioMixerClone.aggregate.\(UUID().uuidString)"
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "AudioMixerClone Route - \(appName)",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceMainSubDeviceKey: outputDeviceUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputDeviceUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tapUID,
                    kAudioSubTapDriftCompensationKey: true
                ]
            ]
        ]

        var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateDeviceID)
        guard status == noErr, aggregateDeviceID != kAudioObjectUnknown else {
            throw AudioRoutingError.createAggregateFailed(status)
        }

        return aggregateDeviceID
    }
}

private final class RouteDSPState {
    private let lock = OSAllocatedUnfairLock(initialState: AppRouteParameters(volume: 1, isMuted: false, balance: 0))

    init(parameters: AppRouteParameters) {
        lock.withLock { state in
            state = parameters
        }
    }

    func update(_ parameters: AppRouteParameters) {
        lock.withLock { state in
            state = parameters
        }
    }

    func render(inputData: UnsafePointer<AudioBufferList>, outputData: UnsafeMutablePointer<AudioBufferList>) {
        let parameters = lock.withLock { $0 }
        let gain = Float32(parameters.isMuted ? 0 : max(0, min(parameters.volume, 1.5)))
        let balance = Float32(max(-1, min(parameters.balance, 1)))
        let leftGain = gain * (balance > 0 ? 1 - balance : 1)
        let rightGain = gain * (balance < 0 ? 1 + balance : 1)

        let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
        let outputBuffers = UnsafeMutableAudioBufferListPointer(outputData)
        let count = min(inputBuffers.count, outputBuffers.count)

        for index in 0..<count {
            let inputBuffer = inputBuffers[index]
            let outputBuffer = outputBuffers[index]

            guard let inputPointer = inputBuffer.mData?.assumingMemoryBound(to: Float32.self),
                  let outputPointer = outputBuffer.mData?.assumingMemoryBound(to: Float32.self) else {
                continue
            }

            let sampleCount = min(Int(inputBuffer.mDataByteSize), Int(outputBuffer.mDataByteSize)) / MemoryLayout<Float32>.size
            let channelCount = max(1, Int(outputBuffer.mNumberChannels))

            for sampleIndex in 0..<sampleCount {
                let channelIndex = sampleIndex % channelCount
                let channelGain: Float32
                if channelCount == 1 {
                    channelGain = gain
                } else if channelIndex == 0 {
                    channelGain = leftGain
                } else if channelIndex == 1 {
                    channelGain = rightGain
                } else {
                    channelGain = gain
                }

                outputPointer[sampleIndex] = inputPointer[sampleIndex] * channelGain
            }
        }
    }
}

private extension AudioStreamBasicDescription {
    var readableSummary: String {
        let sampleRate = Int(mSampleRate.rounded())
        return "\(mChannelsPerFrame) ch, \(sampleRate) Hz, \(mBitsPerChannel)-bit"
    }
}

private extension OSStatus {
    var osStatusDescription: String {
        if self == noErr {
            return "noErr"
        }

        let code = UInt32(bitPattern: self)
        let bytes = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]

        if bytes.allSatisfy({ (32...126).contains($0) }) {
            let fourCC = String(decoding: bytes, as: UTF8.self)
            return "\(self) ('\(fourCC)')"
        }

        return "\(self)"
    }
}
