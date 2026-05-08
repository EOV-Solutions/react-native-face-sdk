# React Native Face SDK

[![npm version](https://img.shields.io/npm/v/react-native-face-sdk.svg)](https://www.npmjs.com/package/react-native-face-sdk)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey.svg)](https://reactnative.dev/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

React Native module for Face Recognition SDK with face enrollment, recognition, liveness detection, and license management.

## Features

- 🔐 **License Management** — Activate and validate SDK license with server sync, offline grace period support
- 👤 **Face Registration** — Multi-pose face enrollment (front, left, right, up, down) with liveness check
- 🔍 **Face Recognition** — Real-time face matching with anti-spoofing detection (3 random poses)
- ☁️ **Auto Cloud Sync** — Automatically sync face embeddings from server on initialization
- 🔄 **Refresh Embeddings** — Delete local data and re-download from server when needed
- 📱 **Cross-platform** — iOS 12.0+ and Android API 24+

## Requirements

| Platform | Minimum Version | Recommended |
|----------|-----------------|-------------|
| iOS | 12.0+ | 15.0+ |
| Android | API 24+ (Android 7.0) | API 29+ |
| React Native | 0.60+ | 0.72+ |

## Installation

```bash
npm install react-native-face-sdk
# or
yarn add react-native-face-sdk
```

### iOS Setup

1. Add the native SDK to your project. Copy or link `FaceSDK.xcframework` to your iOS project.

2. Add to your `Podfile`:

```ruby
pod 'react-native-face-sdk', :path => '../node_modules/react-native-face-sdk'
```

3. Run pod install:

```bash
cd ios && pod install
```

4. Add camera usage description in `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed for face registration and recognition</string>
```

### Android Setup

1. Copy `facekit-release.aar` to `android/libs/` folder

2. The module auto-links with React Native 0.60+

3. Add camera permission in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

## Usage

### Initialize SDK

```typescript
import FaceSDK from 'react-native-face-sdk';

const result = await FaceSDK.initialize({
  licenseKey: 'YOUR_LICENSE_KEY',
  faceId: 'user-123',           // Will be used as userId in registration
  userName: 'John Doe',         // Will be used as userName in registration
});

if (result.success) {
  console.log('SDK initialized successfully');
  console.log('Organization:', result.orgId); // orgId returned from license server
}

// initialize() may return before background enrollment sync finishes.
// Wait briefly before treating a local false enrollment check as final.
const enrolled = await FaceSDK.waitForEnrollmentSync('user-123', {
  timeoutMs: 5000,
  intervalMs: 400,
});
console.log('Enrollment synced locally:', enrolled);
```

### Face Registration

```typescript
// userId and userName are automatically taken from initialize()
// orgId is automatically managed by SDK from license server
const result = await FaceSDK.startRegistration({
  skipNameDialog: true,
  mode: 'upsert', // 'create_only' | 'upsert' (default) | 'overwrite'
});

if (result.success) {
  console.log('Registered:', result.userId);
  console.log('Server synced:', result.serverSynced);
}
```

> **Note:** `faceId` from `initialize()` is used as `userId` in registration, and `userName` from `initialize()` is used as the display name. You can still override these values by passing them explicitly to `startRegistration()`.

**Registration Modes:**
| Mode | User EXISTS | User NOT EXISTS |
|------|-------------|------------------|
| `overwrite` | Delete all data + insert new | Insert |
| `upsert` | (Default) Update embeddings (keep user record) | Insert |
| `create_only` | Reject with error | Insert |

### Face Recognition

By default runs in **1:1 verify mode** — compares face only against the user enrolled with `faceId` from `initialize()`. Pass `mode: 'identify'` to search all users in the org (1:N).

```typescript
// 1:1 Verify (default) — userId auto-filled from initialize()
const result = await FaceSDK.startRecognition({
  timeoutSeconds: 30,
});

if (result.success && result.isRecognized) {
  console.log('Recognized:', result.userName);
  console.log('Confidence:', result.confidence);
  console.log('Is live:', result.isLive);
} else if (!result.success && result.error === 'Recognition cancelled') {
  console.log('Recognition cancelled by user');
} else if (result.success && !result.isLive) {
  console.log('Liveness failed or timed out');
} else if (!result.success) {
  console.error('Recognition error:', result.error);
}

// 1:N Identify — search all enrolled users
const result = await FaceSDK.startRecognition({ mode: 'identify' });

// Verify a specific user (different from the initialized faceId)
const result = await FaceSDK.startRecognition({ mode: 'verify', userId: 'other-user-id' });
```

> **Note:** When `mode` is `'verify'` and `userId` is not provided, the SDK automatically uses the `faceId` set in `initialize()`.

**Recognition result states:**

| Case | Result fields |
| ---- | ------------- |
| Completed successfully | `success: true`, `isLive: true` |
| Timeout / liveness failed | `success: true`, `isLive: false` |
| User closes camera | `success: false`, `error: 'Recognition cancelled'` |
| Native error | `success: false`, `error` |

### Refresh Embeddings

```typescript
// Re-download embeddings from server (useful when data is outdated or corrupted)
const result = await FaceSDK.refreshEmbeddings('user-123');

if (result.success) {
  console.log('Deleted local entries:', result.deletedCount);
  console.log('Re-imported user:', result.userId, result.userName);
}
```

> **Note:** If `faceId` was set during `initialize()`, you can call `refreshEmbeddings()` without arguments — it defaults to the initialized `faceId`.

### License Status

```typescript
// Quick validity check
const { valid, status, message } = await FaceSDK.isLicenseValid();
console.log('License valid:', valid);
console.log('Status:', status, message);

// Numeric status code
const statusCode = await FaceSDK.getLicenseStatus();
```

### Terminate SDK (Release Resources)

```typescript
// When your app exits or you want to free up memory
const result = await FaceSDK.terminate();

if (result.success) {
  console.log('SDK terminated and resources released');
}

// Check if SDK is still initialized
const isInit = await FaceSDK.isInitialized();
if (!isInit) {
  // Need to call initialize() again before using SDK
  await FaceSDK.initialize({ licenseKey: 'YOUR_LICENSE_KEY' });
}
```

> **Note:** After calling `terminate()`, you must call `initialize()` again before using other SDK functions. This releases AI models from memory.

### Check Device Compatibility

```typescript
// Call BEFORE initialize() to check if the device supports Face SDK
const compat = await FaceSDK.checkDeviceCompatibility();

console.log('Compatible:', compat.compatible);       // true/false
console.log('Platform:', compat.platform);            // 'android' | 'ios'
console.log('Model:', compat.deviceModel);            // e.g. 'Samsung SM-G991B'
console.log('RAM:', compat.totalRAM, 'MB');
console.log('Storage:', compat.availableStorage, 'MB');

// Individual checks
const { checks } = compat;
console.log('Front camera:', checks.hasFrontCamera);
console.log('OS supported:', checks.osVersionSupported);
console.log('CPU arm64:', checks.cpuArchSupported);
console.log('RAM >= 2GB:', checks.hasEnoughRAM);
console.log('Storage >= 100MB:', checks.hasEnoughStorage);

if (!compat.compatible) {
  Alert.alert('Device Not Supported', compat.unsupportedReasons.join('\n'));
}
```

> **Tip:** Call `checkDeviceCompatibility()` on app startup before `initialize()`. This lets you show a user-friendly message early if their phone can't run face recognition.

## API Reference

### Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `initialize(options)` | Initialize SDK with license key | `InitializeResult` |
| `isLicenseValid()` | Check license validity | `LicenseResult` |
| `getLicenseStatus()` | Get numeric license status code | `number` |
| `startRegistration(options?)` | Start multi-pose face registration | `RegistrationResult` |
| `isUserEnrolled(userId)` | Check if user is enrolled locally | `boolean` |
| `waitForEnrollmentSync(userId?, options?)` | Wait for background enrollment sync after initialize | `boolean` |
| `deleteUser(userId)` | Delete a user from the local database | `boolean` |
| `refreshEmbeddings(faceId?)` | Delete local embeddings & re-download from server | `RefreshResult` |
| `startRecognition(options?)` | Start face recognition with liveness check | `RecognitionResult` |
| `checkPermission()` | Check camera permission status | `PermissionResult` |
| `requestPermission()` | Request camera permission | `PermissionResult` |
| `terminate()` | Release SDK resources and AI models | `{ success, message? }` |
| `isInitialized()` | Check if SDK is currently initialized | `boolean` |
| `checkDeviceCompatibility()` | Check if device can run Face SDK | `DeviceCompatibilityResult` |

### Types

```typescript
interface InitializeOptions {
  licenseKey: string;       // License key (required)
  faceId?: string;          // Used as userId in registration
  userName?: string;        // Used as userName in registration
}

interface InitializeResult {
  success: boolean;
  message?: string;
  orgId?: string;           // Organization ID from license server
  error?: string;
}

interface LicenseResult {
  valid: boolean;
  status?: number;
  message?: string;
}

interface RegistrationOptions {
  userId?: string;          // Defaults to faceId from initialize()
  userName?: string;        // Defaults to userName from initialize()
  skipNameDialog?: boolean; // Skip name input dialog
  mode?: 'create_only' | 'upsert' | 'overwrite'; // Registration mode (default: 'upsert')
}

interface RegistrationResult {
  success: boolean;
  userId?: string;
  userName?: string;
  orgId?: string;
  featureCount?: number;
  serverSynced?: boolean;   // Whether data was synced to server
  error?: string;
}

interface RecognitionOptions {
  timeoutSeconds?: number;  // Default: 30
  mode?: 'verify' | 'identify'; // 'verify' = 1:1 (default), 'identify' = 1:N
  userId?: string;          // User to verify against (defaults to faceId from initialize())
}

interface RecognitionResult {
  success: boolean;
  isLive: boolean;          // Liveness check passed
  isRecognized: boolean;    // User was recognized
  userId?: string;
  userName?: string;
  confidence?: number;      // 0–1 similarity score
  imagePath?: string;       // Path to captured face image
  error?: string;           // 'Recognition cancelled' on user close, or native error message
}

interface RefreshResult {
  success: boolean;
  deletedCount: number;     // Number of local entries deleted
  userId: string;           // Re-imported user ID
  userName: string;         // Re-imported user name
  message?: string;
}

interface WaitForEnrollmentSyncOptions {
  timeoutMs?: number;        // Default: 5000
  intervalMs?: number;       // Default: 400
}

interface PermissionResult {
  granted: boolean;
  status: 'granted' | 'denied' | 'restricted' | 'undetermined' | 'unknown';
}

interface DeviceCompatibilityResult {
  compatible: boolean;        // Overall: all checks pass
  message: string;            // Human-readable summary
  platform: 'android' | 'ios';
  osVersion: string;          // e.g. '33' or '17.0'
  deviceModel: string;        // e.g. 'iPhone14,5'
  checks: {
    hasFrontCamera: boolean;    // Front camera available
    osVersionSupported: boolean; // Android 7+ / iOS 12+
    cpuArchSupported: boolean;   // arm64
    hasEnoughRAM: boolean;       // >= 2GB
    hasEnoughStorage: boolean;   // >= 100MB free
  };
  totalRAM: number;           // MB
  availableStorage: number;   // MB
  unsupportedReasons: string[]; // Failure reasons (empty if compatible)
}
```

## License Status Codes

| Code | Status | Description |
|------|--------|-------------|
| 0 | NOT_INITIALIZED | SDK has not been initialized yet |
| 1 | VALID | License is active and valid |
| 2 | EXPIRED | License has expired — contact EOV to renew |
| 3 | GRACE_PERIOD | Offline grace period (up to 7 days) — connect to sync |
| 4 | INVALID | License key is invalid |
| 5 | BLOCKED | License blocked due to quota — contact EOV |
| 6 | QUOTA_EXCEEDED |

## Troubleshooting

### iOS
- Ensure `NSCameraUsageDescription` is set in `Info.plist`
- Run `pod deintegrate && pod install` if pod install fails

### Android
- Ensure `facekit-release.aar` is in the correct `libs/` folder
- Run `./gradlew clean` and rebuild

## License

MIT License - EOV Solutions
