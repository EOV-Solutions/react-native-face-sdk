//
//  RNFaceSDK.swift
//  react-native-face-sdk
//
//  React Native bridge for FaceSDK
//  Wraps FMFaceSDK from FaceSDK.xcframework
//
//  Copyright © 2024 EOV Solutions. All rights reserved.
//

import Foundation
import UIKit
import FaceSDK
import AVFoundation

@objc(RNFaceSDK)
class RNFaceSDK: RCTEventEmitter {
    
    // MARK: - Properties
    
    private let sdk = FMFaceSDK.shared
    private let licenseManager = FMLicenseManager.shared
    
    // MARK: - Module Setup
    
    @objc override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    override func supportedEvents() -> [String]! {
        return ["onProgress", "onError", "onFaceDetected"]
    }
    
    // MARK: - Initialize
    
    /// Initialize the SDK with license key
    /// Two-step process (Android parity):
    /// 1. Activate license
    /// 2. Initialize engine
    @objc func initialize(
        _ options: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let licenseKey = options["licenseKey"] as? String else {
            reject("E_INVALID_PARAMS", "licenseKey is required", nil)
            return
        }
        
        let faceId = options["faceId"] as? String
        let userName = options["userName"] as? String
        let orgId = options["orgId"] as? String
        
        // Set userName to LicenseManager before license activation
        // This is needed for registration flow to retrieve userName
        if let name = userName {
            licenseManager.setUserName(name)
        }
        
        // Step 1: Activate license (like Android FaceSDK.initializeLicense)
        licenseManager.activate(licenseKey: licenseKey, faceId: faceId) { [weak self] licenseResult in
            guard let self = self else { return }
            
            switch licenseResult {
            case .success:
                // Step 2: Initialize engine (like Android FaceSDK.initialize)
                self.sdk.initializeEngine { engineResult in
                    switch engineResult {
                    case .success:
                        // IMPORTANT: Set active organization from license (matching FMFaceSDK.initializeLicense behavior)
                        // This is needed for registration/recognition to work
                        // We need to WAIT for setOrganization to complete before resolving
                        if let licenseOrgId = self.licenseManager.currentOrgId {
                            print("RNFaceSDK: Setting organization from license: \(licenseOrgId)")
                            self.sdk.setOrganization(licenseOrgId) { orgResult in
                                // After license org is set, check if user provided override
                                if let org = orgId {
                                    print("RNFaceSDK: Overriding organization with user-provided: \(org)")
                                    self.sdk.setOrganization(org) { _ in
                                        // Auto-sync face data if faceId provided (matching Android behavior)
                                        if let fId = faceId {
                                            print("RNFaceSDK: Auto-syncing face data for: \(fId)")
                                            self.sdk.autoSyncFaceData(faceId: fId)
                                        }
                                        
                                        // Both orgs set, now resolve
                                        resolve([
                                            "success": true,
                                            "message": "SDK initialized successfully"
                                        ])
                                    }
                                } else {
                                    // Auto-sync face data if faceId provided (matching Android behavior)
                                    if let fId = faceId {
                                        print("RNFaceSDK: Auto-syncing face data for: \(fId)")
                                        self.sdk.autoSyncFaceData(faceId: fId)
                                    }
                                    
                                    // Only license org, resolve now
                                    resolve([
                                        "success": true,
                                        "message": "SDK initialized successfully"
                                    ])
                                }
                            }
                        } else if let org = orgId {
                            // No license org, but user provided one
                            print("RNFaceSDK: Setting user-provided organization: \(org)")
                            self.sdk.setOrganization(org) { _ in
                                // Auto-sync face data if faceId provided (matching Android behavior)
                                if let fId = faceId {
                                    print("RNFaceSDK: Auto-syncing face data for: \(fId)")
                                    self.sdk.autoSyncFaceData(faceId: fId)
                                }
                                
                                resolve([
                                    "success": true,
                                    "message": "SDK initialized successfully"
                                ])
                            }
                        } else {
                            // No org at all - resolve anyway (but can still sync if faceId provided)
                            if let fId = faceId {
                                print("RNFaceSDK: Auto-syncing face data for: \(fId)")
                                self.sdk.autoSyncFaceData(faceId: fId)
                            }
                            
                            resolve([
                                "success": true,
                                "message": "SDK initialized successfully"
                            ])
                        }
                    case .failure(let error):
                        reject("E_INIT_FAILED", error.localizedDescription, error)
                    }
                }
            case .failure(let error):
                reject("E_LICENSE_FAILED", error.localizedDescription, error)
            }
        }
    }

    /// Set organization ID
    @objc func setOrganization(
        _ orgId: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        sdk.setOrganization(orgId) { result in
            switch result {
            case .success:
                resolve(["success": true])
            case .failure(let error):
                reject("E_SET_ORG_FAILED", error.localizedDescription, error)
            }
        }
    }
    
    // MARK: - License
    
    /// Check if license is valid
    @objc func isLicenseValid(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let valid = sdk.isLicenseValid
        let status = sdk.licenseStatus
        let message = getLicenseStatusMessage(status)
        
        resolve([
            "valid": valid,
            "status": status.rawValue,
            "message": message
        ])
    }
    
    /// Get license info
    @objc func getLicenseInfo(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let status = sdk.licenseStatus
        resolve([
            "isValid": sdk.isLicenseValid,
            "status": status.rawValue,
            "message": getLicenseStatusMessage(status)
        ])
    }
    
    /// Get license status code (for Android parity)
    @objc func getLicenseStatus(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(sdk.licenseStatus.rawValue)
    }
    
    // MARK: - Terminate & Cleanup
    
    /// Terminate the SDK and release all resources (AI models, sessions, etc.)
    /// Call this when your app exits or when you want to free up memory.
    @objc func terminate(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        sdk.terminate()
        resolve([
            "success": true,
            "message": "SDK terminated successfully"
        ])
    }
    
    /// Check if SDK is initialized
    @objc func isInitialized(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(sdk.isInitialized)
    }
    
    private func getLicenseStatusMessage(_ status: FMLicenseStatus) -> String {
        switch status {
        case .notInitialized:
            return "License not initialized"
        case .valid:
            return "License is valid"
        case .expired:
            return "License has expired"
        case .gracePeriod:
            return "License in grace period"
        case .invalid:
            return "Invalid license"
        case .blocked:
            return "License blocked"
        case .quotaExceeded:
            return "Quota exceeded"
        @unknown default:
            return "Unknown license status"
        }
    }
    
    // MARK: - Registration
    
    /// Start face registration flow
    @objc func startRegistration(
        _ options: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard sdk.isInitialized else {
            reject("E_NOT_INITIALIZED", "SDK not initialized", nil)
            return
        }
        
        let userId = options["userId"] as? String
        let userName = options["userName"] as? String
        let orgId = options["orgId"] as? String
        // Note: skipNameDialog not implemented in iOS SDK yet
        
        // Set user info to LicenseManager (same as Android)
        if let name = userName, !name.isEmpty {
            FMLicenseManager.shared.setUserName(name)
        }
        
        // Set organization if provided
        if let org = orgId {
            sdk.setOrganization(org) { _ in }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let topVC = self.getTopViewController() else {
                reject("E_NO_ACTIVITY", "No view controller available", nil)
                return
            }
            
            // Create registration VC - pass userName/userId directly
            // SDK will fallback to LicenseManager if nil
            let registerVC = FMMultiStepRegisterViewController()
            registerVC.userName = userName
            registerVC.userId = userId
            
            // Set completion handlers
            registerVC.onComplete = { embeddings in
                // Registration successful - SDK handles server sync internally
                resolve([
                    "success": true,
                    "userId": userId ?? "",
                    "userName": userName ?? "",
                    "orgId": orgId ?? "",
                    "featureCount": embeddings.count,
                    "serverSynced": true
                ])
            }
            
            registerVC.onDismiss = {
                resolve([
                    "success": false,
                    "error": "Registration cancelled"
                ])
            }
            
            let nav = UINavigationController(rootViewController: registerVC)
            nav.modalPresentationStyle = .fullScreen
            topVC.present(nav, animated: true)
        }
    }
    
    /// Check if user is enrolled
    @objc func isUserEnrolled(
        _ userId: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(sdk.isUserEnrolled(userId))
    }
    
    /// Delete user
    @objc func deleteUser(
        _ userId: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(sdk.deleteUser(userId))
    }
    
    // MARK: - Refresh Embeddings
    
    /// Refresh embeddings: Delete local data and re-download from server
    @objc func refreshEmbeddings(
        _ faceId: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard sdk.isInitialized else {
            reject("E_NOT_INITIALIZED", "SDK not initialized", nil)
            return
        }
        
        sdk.refreshEmbeddings(faceId: faceId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    resolve([
                        "success": true,
                        "deletedCount": data.deletedCount,
                        "userId": data.userId,
                        "userName": data.userName,
                        "message": "Embeddings refreshed successfully"
                    ])
                case .failure(let error):
                    reject("E_REFRESH_FAILED", error.localizedDescription, error)
                }
            }
        }
    }
    
    // MARK: - Recognition
    
    /// Start face recognition flow
    @objc func startRecognition(
        _ options: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard sdk.isInitialized else {
            reject("E_NOT_INITIALIZED", "SDK not initialized", nil)
            return
        }
        
        let timeoutSeconds = options["timeoutSeconds"] as? Int ?? 30
        let orgId = options["orgId"] as? String
        
        // Set organization if provided
        if let org = orgId {
            sdk.setOrganization(org) { _ in }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let topVC = self.getTopViewController() else {
                reject("E_NO_ACTIVITY", "No view controller available", nil)
                return
            }
            
            // Create recognition VC
            let recognitionVC = FMLiveRecognitionViewController()
            recognitionVC.timeoutSeconds = timeoutSeconds
            
            // Set completion handlers
            recognitionVC.onResult = { result in
                // Use isRecognized from FMLiveRecognitionResult directly
                // The SDK sets isRecognized based on confidence >= threshold (0.50)
                resolve([
                    "success": true,
                    "isLive": result.isLive,
                    "isRecognized": result.isRecognized,
                    "userId": result.userId ?? "",
                    "userName": result.userName,
                    "confidence": result.confidence,
                    "imagePath": result.imagePath ?? ""
                ])
            }
            
            recognitionVC.onDismiss = {
                resolve([
                    "success": false,
                    "isLive": false,
                    "isRecognized": false,
                    "error": "Recognition cancelled or timeout"
                ])
            }
            
            let nav = UINavigationController(rootViewController: recognitionVC)
            nav.modalPresentationStyle = .fullScreen
            topVC.present(nav, animated: true)
        }
    }
    
    // MARK: - Permissions
    
    /// Check camera permission (alias for Android parity)
    @objc func checkPermission(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        checkCameraPermission(resolve, rejecter: reject)
    }
    
    /// Request camera permission (alias for Android parity)
    @objc func requestPermission(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        requestCameraPermission(resolve, rejecter: reject)
    }
    
    /// Check camera permission
    @objc func checkCameraPermission(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        var statusString: String
        var granted: Bool
        
        switch status {
        case .authorized:
            statusString = "granted"
            granted = true
        case .denied:
            statusString = "denied"
            granted = false
        case .restricted:
            statusString = "restricted"
            granted = false
        case .notDetermined:
            statusString = "undetermined"
            granted = false
        @unknown default:
            statusString = "undetermined"
            granted = false
        }
        
        resolve(["granted": granted, "status": statusString])
    }
    
    /// Request camera permission
    @objc func requestCameraPermission(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                resolve([
                    "granted": granted,
                    "status": granted ? "granted" : "denied"
                ])
            }
        }
    }
    
    // MARK: - Device Compatibility

    /// Check if the current device is compatible with Face SDK
    @objc func checkDeviceCompatibility(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        var unsupportedReasons: [String] = []

        // 1. Check front camera
        let hasFrontCamera = checkFrontCameraAvailable()
        if !hasFrontCamera {
            unsupportedReasons.append("No front-facing camera detected")
        }

        // 2. Check OS version (iOS 12+)
        let osVersion = UIDevice.current.systemVersion
        let versionComponents = osVersion.split(separator: ".").compactMap { Int($0) }
        let majorVersion = versionComponents.first ?? 0
        let osVersionSupported = majorVersion >= 12
        if !osVersionSupported {
            unsupportedReasons.append("iOS \(osVersion) is below minimum (iOS 12.0)")
        }

        // 3. Check CPU architecture (arm64 required for CoreML)
        var cpuArchSupported = false
        #if arch(arm64)
        cpuArchSupported = true
        #else
        unsupportedReasons.append("CPU architecture is not arm64")
        #endif

        // 4. Check RAM (>= 2GB)
        let totalRAMBytes = ProcessInfo.processInfo.physicalMemory
        let totalRAMMB = Int(totalRAMBytes / (1024 * 1024))
        let hasEnoughRAM = totalRAMMB >= 2048
        if !hasEnoughRAM {
            unsupportedReasons.append("Insufficient RAM: \(totalRAMMB)MB (minimum 2048MB)")
        }

        // 5. Check available storage (>= 100MB)
        let availableStorageMB = getAvailableStorageMB()
        let hasEnoughStorage = availableStorageMB >= 100
        if !hasEnoughStorage {
            unsupportedReasons.append("Insufficient storage: \(availableStorageMB)MB available (minimum 100MB)")
        }

        // Device model
        let deviceModel = getDeviceModelIdentifier()

        // Overall compatibility
        let compatible = hasFrontCamera && osVersionSupported && cpuArchSupported && hasEnoughRAM && hasEnoughStorage

        let message = compatible
            ? "Device is compatible with Face SDK"
            : "Device is NOT compatible: \(unsupportedReasons.joined(separator: "; "))"

        resolve([
            "compatible": compatible,
            "message": message,
            "platform": "ios",
            "osVersion": osVersion,
            "deviceModel": deviceModel,
            "checks": [
                "hasFrontCamera": hasFrontCamera,
                "osVersionSupported": osVersionSupported,
                "cpuArchSupported": cpuArchSupported,
                "hasEnoughRAM": hasEnoughRAM,
                "hasEnoughStorage": hasEnoughStorage
            ],
            "totalRAM": totalRAMMB,
            "availableStorage": availableStorageMB,
            "unsupportedReasons": unsupportedReasons
        ] as [String : Any])
    }

    private func checkFrontCameraAvailable() -> Bool {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )
        return !discoverySession.devices.isEmpty
    }

    private func getAvailableStorageMB() -> Int {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSize = attrs[.systemFreeSize] as? Int64 {
                return Int(freeSize / (1024 * 1024))
            }
        } catch {
            // Fall back to 0 if check fails
        }
        return 0
    }

    private func getDeviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    // MARK: - Helper
    
    private func getTopViewController() -> UIViewController? {
        var window: UIWindow?
        
        if #available(iOS 13.0, *) {
            window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            window = UIApplication.shared.keyWindow
        }
        
        guard let rootWindow = window else { return nil }
        
        var topVC = rootWindow.rootViewController
        while let presented = topVC?.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}
