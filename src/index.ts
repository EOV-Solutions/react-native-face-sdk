/**
 * React Native Face SDK
 *
 * Face recognition module for React Native applications
 * Wrapper for FaceSDK.xcframework (iOS) and FaceKit AAR (Android)
 */

import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-face-sdk' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

// Native module name differs by platform
const moduleName = Platform.select({
  ios: 'RNFaceSDK',
  android: 'FaceSDK',
  default: 'FaceSDK',
});

const FaceSDKNative = NativeModules[moduleName!]
  ? NativeModules[moduleName!]
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

// Re-export types
export * from './types';

import type {
  InitializeOptions,
  InitializeResult,
  LicenseResult,
  LicenseInfo,
  PermissionResult,
  RegistrationOptions,
  RegistrationResult,
  RecognitionOptions,
  RecognitionResult,
  RefreshResult,
  DeviceCompatibilityResult,
} from './types';

// Store initialization data for use in registration
let _initData: {
  faceId?: string;
  userName?: string;
} = {};

// SDK Interface
const FaceSDK = {
  /**
   * Initialize the Face SDK with license key
   * @param options.licenseKey - License key from server
   * @param options.faceId - Optional face ID (used as userId in registration)
   * @param options.userName - Optional user name (used in registration)
   */
  async initialize(options: InitializeOptions): Promise<InitializeResult> {
    // Store init data for use in registration
    _initData = {
      faceId: options.faceId,
      userName: options.userName,
    };
    return FaceSDKNative.initialize(options);
  },

  /**
   * Check if license is valid and SDK is initialized
   */
  isLicenseValid(): Promise<LicenseResult> {
    return FaceSDKNative.isLicenseValid();
  },

  /**
   * Get detailed license information
   */
  getLicenseInfo(): Promise<LicenseInfo> {
    return FaceSDKNative.getLicenseInfo();
  },

  /**
   * Get license status code
   */
  getLicenseStatus(): Promise<number> {
    return FaceSDKNative.getLicenseStatus();
  },

  /**
   * Start face registration flow (5 poses: front, left, right, up, down)
   * Uses faceId as userId and userName from initialize() if not explicitly provided
   * orgId is automatically retrieved from license server during initialization
   * @param options.userId - Optional user ID (uses faceId from initialize if not provided)
   * @param options.userName - Optional user display name (uses userName from initialize if not provided)
   * @param options.skipNameDialog - Skip name dialog and use provided userName directly
   */
  startRegistration(options: RegistrationOptions = {}): Promise<RegistrationResult> {
    // Merge with init data - init data as defaults, options can override
    const mergedOptions: RegistrationOptions = {
      userId: options.userId ?? _initData.faceId,
      userName: options.userName ?? _initData.userName,
      skipNameDialog: options.skipNameDialog,
    };
    return FaceSDKNative.startRegistration(mergedOptions);
  },

  /**
   * Check if user is enrolled
   * @param userId - User ID to check
   */
  isUserEnrolled(userId: string): Promise<boolean> {
    return FaceSDKNative.isUserEnrolled(userId);
  },

  /**
   * Delete a user from the database
   * @param userId - User ID to delete
   */
  deleteUser(userId: string): Promise<boolean> {
    return FaceSDKNative.deleteUser(userId);
  },

  /**
   * Refresh embeddings: Delete all local embeddings and re-download from server.
   * Use this when embeddings are outdated or corrupted.
   * @param faceId - Face ID to re-download embeddings for (defaults to faceId from initialize)
   */
  refreshEmbeddings(faceId?: string): Promise<RefreshResult> {
    const id = faceId ?? _initData.faceId;
    if (!id) {
      return Promise.reject(new Error('faceId is required. Pass it as parameter or set it in initialize()'));
    }
    return FaceSDKNative.refreshEmbeddings(id);
  },

  /**
   * Start face recognition flow with liveness detection (3 random poses)
   * orgId is automatically managed by SDK from license server
   * @param options.timeoutSeconds - Recognition timeout (default: 30)
   */
  startRecognition(options: RecognitionOptions = {}): Promise<RecognitionResult> {
    return FaceSDKNative.startRecognition(options);
  },

  /**
   * Check camera permission status
   */
  checkPermission(): Promise<PermissionResult> {
    // Use platform-specific method name
    if (Platform.OS === 'ios') {
      return FaceSDKNative.checkCameraPermission();
    }
    return FaceSDKNative.checkPermission();
  },

  /**
   * Request camera permission
   */
  requestPermission(): Promise<PermissionResult> {
    // Use platform-specific method name
    if (Platform.OS === 'ios') {
      return FaceSDKNative.requestCameraPermission();
    }
    return FaceSDKNative.requestPermission();
  },

  /**
   * Check camera permission status (alias)
   */
  checkCameraPermission(): Promise<PermissionResult> {
    return FaceSDKNative.checkCameraPermission?.() ?? FaceSDKNative.checkPermission();
  },

  /**
   * Request camera permission (alias)
   */
  requestCameraPermission(): Promise<PermissionResult> {
    return FaceSDKNative.requestCameraPermission?.() ?? FaceSDKNative.requestPermission();
  },

  /**
   * Terminate the SDK and release all resources (AI models, sessions, etc.)
   * Call this when your app exits or when you want to free up memory.
   * After calling terminate(), you must call initialize() again before using other SDK functions.
   * @returns Promise<{success: boolean, message?: string}>
   */
  async terminate(): Promise<{ success: boolean; message?: string }> {
    // Clear stored init data
    _initData = {};
    return FaceSDKNative.terminate();
  },

  /**
   * Check if SDK is initialized
   * @returns Promise<boolean>
   */
  isInitialized(): Promise<boolean> {
    return FaceSDKNative.isInitialized();
  },

  /**
   * Check if the current device is compatible with the Face SDK.
   * Verifies: front camera, OS version, CPU architecture (arm64), RAM, available storage.
   * Call this BEFORE initialize() to give users early feedback
   * if their device cannot run face recognition.
   */
  checkDeviceCompatibility(): Promise<DeviceCompatibilityResult> {
    return FaceSDKNative.checkDeviceCompatibility();
  },
};

export default FaceSDK;
