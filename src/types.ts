/**
 * Type definitions for react-native-face-sdk
 * Wrapper for FaceSDK.xcframework (iOS) and FaceKit AAR (Android)
 */

export interface InitializeOptions {
  /** License key from server */
  licenseKey: string;
  /** Optional face ID (will be used as userId in registration) */
  faceId?: string;
  /** Optional user name (will be used as userName in registration) */
  userName?: string;
}

export interface InitializeResult {
  success: boolean;
  message?: string;
  /** Organization ID returned from license server */
  orgId?: string;
  error?: string;
}

export interface LicenseResult {
  valid: boolean;
  status?: number;
  message?: string;
}

export interface LicenseInfo {
  isValid: boolean;
  status: number;
  message?: string;
  expiryDate?: string;
  maxUsers?: number;
  currentUsers?: number;
  features?: string[];
}

export interface PermissionResult {
  granted: boolean;
  status: 'granted' | 'denied' | 'restricted' | 'undetermined' | 'unknown';
}

export interface RegistrationOptions {
  /** Optional user ID (uses faceId from initialize if not provided) */
  userId?: string;
  /** Optional user display name (uses userName from initialize if not provided) */
  userName?: string;
  /** Skip name dialog and use provided userName directly */
  skipNameDialog?: boolean;
}

export interface RegistrationResult {
  success: boolean;
  userId?: string;
  userName?: string;
  orgId?: string;
  featureCount?: number;
  serverSynced?: boolean;
  error?: string;
}

export interface RecognitionOptions {
  /** Recognition timeout in seconds (default: 30) */
  timeoutSeconds?: number;
}

export interface RecognitionResult {
  success: boolean;
  /** Whether the face is live (not a photo/video) */
  isLive: boolean;
  /** Whether a user was recognized */
  isRecognized: boolean;
  /** User ID if recognized */
  userId?: string;
  /** User name if recognized */
  userName?: string;
  /** Recognition confidence score (0-1) */
  confidence?: number;
  /** Path to captured face image */
  imagePath?: string;
  error?: string;
}

export interface RefreshResult {
  success: boolean;
  /** Number of users deleted from local DB */
  deletedCount: number;
  /** User ID of re-imported user */
  userId: string;
  /** User name of re-imported user */
  userName: string;
  message?: string;
}

export interface DeviceCompatibilityResult {
  /** Overall compatibility - true if all critical checks pass */
  compatible: boolean;
  /** Human-readable summary message */
  message: string;
  /** Platform: 'android' or 'ios' */
  platform: 'android' | 'ios';
  /** OS version string (e.g. '14.0', '33') */
  osVersion: string;
  /** Device model (e.g. 'iPhone 12', 'SM-G991B') */
  deviceModel: string;
  /** Detailed check results */
  checks: {
    /** Device has a front-facing camera */
    hasFrontCamera: boolean;
    /** OS version meets minimum requirement (Android 7+ / iOS 12+) */
    osVersionSupported: boolean;
    /** CPU architecture supports arm64 (required for AI models) */
    cpuArchSupported: boolean;
    /** Device has enough RAM (>= 2GB) */
    hasEnoughRAM: boolean;
    /** Device has enough free storage (>= 100MB) */
    hasEnoughStorage: boolean;
  };
  /** RAM in MB */
  totalRAM: number;
  /** Available storage in MB */
  availableStorage: number;
  /** List of reasons if not compatible */
  unsupportedReasons: string[];
}

export interface FaceSDKInterface {
  // Initialization
  initialize(options: InitializeOptions): Promise<InitializeResult>;
  setOrganization(orgId: string): Promise<{ success: boolean }>;
  isLicenseValid(): Promise<LicenseResult>;
  getLicenseInfo(): Promise<LicenseInfo>;
  getLicenseStatus(): Promise<number>;
  
  // Registration
  startRegistration(options?: RegistrationOptions): Promise<RegistrationResult>;
  isUserEnrolled(userId: string): Promise<boolean>;
  deleteUser(userId: string): Promise<boolean>;
  
  // Sync
  /** Refresh embeddings: delete local data and re-download from server */
  refreshEmbeddings(faceId: string): Promise<RefreshResult>;
  
  // Recognition
  startRecognition(options?: RecognitionOptions): Promise<RecognitionResult>;
  
  // Permissions
  checkPermission(): Promise<PermissionResult>;
  requestPermission(): Promise<PermissionResult>;
  checkCameraPermission(): Promise<PermissionResult>;
  requestCameraPermission(): Promise<PermissionResult>;
  
  // Cleanup & State
  /** Terminate the SDK and release all resources (AI models, sessions, etc.) */
  terminate(): Promise<{ success: boolean; message?: string }>;
  /** Check if SDK is initialized */
  isInitialized(): Promise<boolean>;

  // Device Compatibility
  /** Check if the current device is compatible with Face SDK */
  checkDeviceCompatibility(): Promise<DeviceCompatibilityResult>;
}

declare const FaceSDK: FaceSDKInterface;
export default FaceSDK;
