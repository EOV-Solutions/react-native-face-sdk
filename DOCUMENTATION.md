# 📱 React Native Face SDK - Tài liệu hướng dẫn sử dụng

> **Version:** 1.0.0  
> **Cập nhật:** Tháng 2, 2026  
> **Hỗ trợ:** iOS 12.0+ | Android 7.0+ (API 24)

---

## 📋 Mục lục

1. [Tổng quan](#1-tổng-quan)
2. [Tính năng chính](#2-tính-năng-chính)
3. [Yêu cầu hệ thống](#3-yêu-cầu-hệ-thống)
4. [Cài đặt](#4-cài-đặt)
5. [Hướng dẫn sử dụng](#5-hướng-dẫn-sử-dụng)
6. [API Reference](#6-api-reference)
7. [Luồng hoạt động](#7-luồng-hoạt-động)
8. [Mã lỗi & Xử lý](#8-mã-lỗi--xử-lý)
9. [FAQ](#9-faq)

---

## 1. Tổng quan

**React Native Face SDK** là module nhận diện khuôn mặt cho ứng dụng React Native, cung cấp các chức năng:
- Đăng ký khuôn mặt (Face Enrollment)
- Nhận diện khuôn mặt (Face Recognition)
- Phát hiện người thật/giả mạo (Liveness Detection)
- Quản lý license và đồng bộ dữ liệu với server

SDK được phát triển bởi **EOV Solutions**, sử dụng công nghệ AI tiên tiến với độ chính xác cao.

---

## 2. Tính năng chính

### 🔐 Quản lý License
| Tính năng | Mô tả |
|-----------|-------|
| Kích hoạt license | Xác thực license key với server |
| Offline mode | Hoạt động offline trong 7 ngày (grace period) |
| Auto-sync | Tự động đồng bộ trạng thái license |

### 👤 Đăng ký khuôn mặt (Face Registration)
| Tính năng | Mô tả |
|-----------|-------|
| Multi-pose capture | Chụp 5 góc: Thẳng, Trái, Phải, Trên, Dưới |
| Liveness detection | Phát hiện người thật trong quá trình đăng ký |
| Server sync | Tự động upload dữ liệu lên server |
| Embedding extraction | Trích xuất vector đặc trưng khuôn mặt (512 chiều) |

### 🔍 Nhận diện khuôn mặt (Face Recognition)
| Tính năng | Mô tả |
|-----------|-------|
| Real-time detection | Nhận diện theo thời gian thực |
| Anti-spoofing | Chống giả mạo (ảnh, video, mặt nạ) |
| 3-pose liveness | Yêu cầu 3 góc ngẫu nhiên để xác nhận người thật |
| Confidence score | Trả về điểm tin cậy (0-100%) |

### ☁️ Đồng bộ dữ liệu
| Tính năng | Mô tả |
|-----------|-------|
| Auto-download | Tự động tải embedding từ server khi khởi tạo |
| Batch upload | Upload nhiều ảnh trong 1 request |
| On-premise support | Hỗ trợ server riêng của khách hàng |

---

## 3. Yêu cầu hệ thống

### Platform
| Platform | Minimum Version | Recommended |
|----------|-----------------|-------------|
| iOS | 12.0+ | 15.0+ |
| Android | API 24 (Android 7.0) | API 29+ |
| React Native | 0.60+ | 0.72+ |

### Thiết bị
- Camera trước (Front camera) với độ phân giải tối thiểu 720p
- RAM tối thiểu 2GB (khuyến nghị 4GB+)
- Storage: ~100MB cho AI models

---

## 4. Cài đặt

### 4.1 Cài đặt package

```bash
npm install react-native-face-sdk
# hoặc
yarn add react-native-face-sdk
```

### 4.2 iOS Setup

**Bước 1:** Thêm vào `Podfile`:
```ruby
pod 'react-native-face-sdk', :path => '../node_modules/react-native-face-sdk'
```

**Bước 2:** Cài đặt pods:
```bash
cd ios && pod install
```

**Bước 3:** Thêm quyền camera vào `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Ứng dụng cần truy cập camera để đăng ký và nhận diện khuôn mặt</string>
```

### 4.3 Android Setup

**Bước 1:** Copy file `facekit-release.aar` vào `android/libs/`

**Bước 2:** Thêm quyền trong `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

---

## 5. Hướng dẫn sử dụng

### 5.1 Import SDK

```typescript
import FaceSDK from 'react-native-face-sdk';
```

### 5.2 Khởi tạo SDK (Bắt buộc)

```typescript
const initSDK = async () => {
  try {
    const result = await FaceSDK.initialize({
      licenseKey: 'YOUR_LICENSE_KEY',  // License key từ EOV
      faceId: 'user-12345',            // ID định danh người dùng
      userName: 'Nguyễn Văn A',        // Tên hiển thị
    });

    if (result.success) {
      console.log('✅ SDK khởi tạo thành công');
      console.log('📦 Organization ID:', result.orgId);
    } else {
      console.error('❌ Lỗi:', result.error);
    }
  } catch (error) {
    console.error('❌ Exception:', error);
  }
};
```

### 5.3 Đăng ký khuôn mặt

```typescript
const registerFace = async () => {
  // Kiểm tra quyền camera trước
  const permission = await FaceSDK.checkCameraPermission();
  if (!permission.granted) {
    const request = await FaceSDK.requestCameraPermission();
    if (!request.granted) {
      Alert.alert('Lỗi', 'Cần cấp quyền camera để đăng ký khuôn mặt');
      return;
    }
  }

  // Bắt đầu đăng ký
  const result = await FaceSDK.startRegistration({
    skipNameDialog: true,  // Bỏ qua dialog nhập tên
  });

  if (result.success) {
    console.log('✅ Đăng ký thành công');
    console.log('👤 User ID:', result.userId);
    console.log('📤 Đã sync server:', result.serverSynced);
  } else {
    console.error('❌ Đăng ký thất bại:', result.error);
  }
};
```

**Giao diện đăng ký:**
- Hiển thị camera với khung oval hướng dẫn
- Chỉ dẫn bằng text + giọng nói (TTS)
- Progress indicator hiển thị số bước đã hoàn thành (1/5 → 5/5)
- Thứ tự: Nhìn thẳng → Quay trái → Quay phải → Ngửa lên → Cúi xuống

### 5.4 Nhận diện khuôn mặt

```typescript
const recognizeFace = async () => {
  const result = await FaceSDK.startRecognition({
    timeoutSeconds: 30,  // Timeout sau 30 giây
  });

  if (result.success) {
    if (result.isRecognized) {
      console.log('✅ Nhận diện thành công');
      console.log('👤 User:', result.userName);
      console.log('📊 Độ tin cậy:', (result.confidence * 100).toFixed(1) + '%');
      console.log('🔒 Người thật:', result.isLive ? 'Có' : 'Không');
    } else {
      console.log('⚠️ Không nhận diện được - Có thể chưa đăng ký');
    }
  } else {
    console.error('❌ Lỗi nhận diện:', result.error);
  }
};
```

**Giao diện nhận diện:**
- Hiển thị camera với khung oval
- Yêu cầu 3 góc ngẫu nhiên để xác nhận người thật
- Hiển thị kết quả nhận diện kèm tên và ảnh đại diện

### 5.5 Kiểm tra trạng thái

```typescript
// Kiểm tra license còn hiệu lực
const checkLicense = async () => {
  const result = await FaceSDK.isLicenseValid();
  console.log('License valid:', result.valid);
  console.log('Status:', result.status);
};

// Kiểm tra user đã đăng ký chưa
const checkUser = async (userId: string) => {
  const enrolled = await FaceSDK.isUserEnrolled(userId);
  console.log('User enrolled:', enrolled);
};

// Kiểm tra SDK đã khởi tạo chưa
const checkInit = async () => {
  const initialized = await FaceSDK.isInitialized();
  console.log('SDK initialized:', initialized);
};
```

### 5.6 Giải phóng tài nguyên

```typescript
// Khi thoát app hoặc muốn giải phóng bộ nhớ
const cleanup = async () => {
  const result = await FaceSDK.terminate();
  if (result.success) {
    console.log('✅ Đã giải phóng tài nguyên SDK');
  }
};
```

---

## 6. API Reference

### 6.1 Methods

| Method | Params | Return | Mô tả |
|--------|--------|--------|-------|
| `initialize` | `InitializeOptions` | `InitializeResult` | Khởi tạo SDK với license key |
| `isLicenseValid` | - | `LicenseResult` | Kiểm tra license còn hiệu lực |
| `getLicenseInfo` | - | `LicenseInfo` | Lấy thông tin chi tiết license |
| `getLicenseStatus` | - | `number` | Lấy mã trạng thái license |
| `startRegistration` | `RegistrationOptions?` | `RegistrationResult` | Bắt đầu đăng ký khuôn mặt |
| `isUserEnrolled` | `userId: string` | `boolean` | Kiểm tra user đã đăng ký |
| `deleteUser` | `userId: string` | `boolean` | Xóa user khỏi database |
| `startRecognition` | `RecognitionOptions?` | `RecognitionResult` | Bắt đầu nhận diện khuôn mặt |
| `checkCameraPermission` | - | `PermissionResult` | Kiểm tra quyền camera |
| `requestCameraPermission` | - | `PermissionResult` | Yêu cầu quyền camera |
| `terminate` | - | `{success, message}` | Giải phóng tài nguyên SDK |
| `isInitialized` | - | `boolean` | Kiểm tra SDK đã khởi tạo |

### 6.2 Types

#### InitializeOptions
```typescript
interface InitializeOptions {
  licenseKey: string;   // License key (bắt buộc)
  faceId?: string;      // ID user (dùng cho đăng ký)
  userName?: string;    // Tên hiển thị
}
```

#### RegistrationOptions
```typescript
interface RegistrationOptions {
  userId?: string;         // Override userId
  userName?: string;       // Override userName
  skipNameDialog?: boolean; // Bỏ qua dialog nhập tên
}
```

#### RecognitionOptions
```typescript
interface RecognitionOptions {
  timeoutSeconds?: number; // Timeout (mặc định: 30s)
}
```

#### RecognitionResult
```typescript
interface RecognitionResult {
  success: boolean;      // Thành công/thất bại
  isLive: boolean;       // Là người thật
  isRecognized: boolean; // Đã nhận diện được
  userId?: string;       // ID user nếu nhận diện được
  userName?: string;     // Tên user
  confidence?: number;   // Độ tin cậy (0-1)
  imagePath?: string;    // Đường dẫn ảnh captured
  error?: string;        // Thông báo lỗi
}
```

---

## 7. Luồng hoạt động

### 7.1 Luồng đăng ký (Registration Flow)

```
┌─────────────────────────────────────────────────────────────┐
│                    REGISTRATION FLOW                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. initialize()          → Khởi tạo SDK, xác thực license │
│         ↓                                                   │
│  2. checkCameraPermission() → Kiểm tra quyền camera        │
│         ↓                                                   │
│  3. startRegistration()   → Mở camera, bắt đầu đăng ký     │
│         ↓                                                   │
│  4. Capture 5 poses:                                        │
│     ├── Pose 1: Nhìn thẳng (FRONT)                         │
│     ├── Pose 2: Quay trái (LEFT)                           │
│     ├── Pose 3: Quay phải (RIGHT)                          │
│     ├── Pose 4: Ngửa lên (UP)                              │
│     └── Pose 5: Cúi xuống (DOWN)                           │
│         ↓                                                   │
│  5. Extract embeddings    → Trích xuất 5 vector đặc trưng  │
│         ↓                                                   │
│  6. Save to local DB      → Lưu vào SQLite local           │
│         ↓                                                   │
│  7. Sync to server        → Upload lên cloud/on-premise    │
│         ↓                                                   │
│  8. Return result         → Trả về kết quả đăng ký         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 Luồng nhận diện (Recognition Flow)

```
┌─────────────────────────────────────────────────────────────┐
│                   RECOGNITION FLOW                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. startRecognition()    → Mở camera nhận diện            │
│         ↓                                                   │
│  2. Liveness check:       → Yêu cầu 3 góc ngẫu nhiên       │
│     ├── Random pose 1                                       │
│     ├── Random pose 2                                       │
│     └── Random pose 3                                       │
│         ↓                                                   │
│  3. Extract embedding     → Trích xuất vector từ khuôn mặt │
│         ↓                                                   │
│  4. Compare with DB       → So sánh với tất cả embeddings  │
│         ↓                                                   │
│  5. Calculate similarity  → Tính cosine similarity         │
│         ↓                                                   │
│  6. Threshold check       → Kiểm tra ngưỡng (>= 0.5)       │
│         ↓                                                   │
│  7. Return result         → Trả về user + confidence       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. Mã lỗi & Xử lý

### License Status Codes

| Code | Status | Mô tả | Xử lý |
|------|--------|-------|-------|
| 0 | NOT_INITIALIZED | SDK chưa khởi tạo | Gọi `initialize()` |
| 1 | VALID | License hợp lệ | OK |
| 2 | EXPIRED | License hết hạn | Liên hệ EOV gia hạn |
| 3 | GRACE_PERIOD | Đang trong grace period (offline) | Kết nối internet để sync |
| 4 | BLOCKED | Bị khóa do quota | Liên hệ EOV |

### Common Errors

| Error | Nguyên nhân | Giải pháp |
|-------|-------------|-----------|
| `License key invalid` | License key sai | Kiểm tra lại license key |
| `Camera permission denied` | Chưa cấp quyền camera | Gọi `requestCameraPermission()` |
| `No face detected` | Không phát hiện khuôn mặt | Đảm bảo ánh sáng đủ, khuôn mặt trong khung |
| `Liveness check failed` | Không qua kiểm tra người thật | Thực hiện lại, tuân theo hướng dẫn |
| `Network error` | Lỗi kết nối mạng | Kiểm tra internet, SDK sẽ dùng offline mode |

---

## 9. FAQ

### Q: SDK có hoạt động offline không?
**A:** Có. Sau khi khởi tạo thành công lần đầu, SDK có thể hoạt động offline trong 7 ngày (grace period). Embeddings được lưu local và sync khi có mạng.

### Q: Độ chính xác nhận diện là bao nhiêu?
**A:** SDK sử dụng model InspireFace với độ chính xác >99.5% trên benchmark LFW. Trong thực tế đạt >98% với điều kiện ánh sáng tốt.

### Q: Dữ liệu khuôn mặt được lưu ở đâu?
**A:** 
- **Local:** SQLite database trên thiết bị
- **Cloud:** Server của EOV (SAAS_CLOUD mode) hoặc server riêng của khách hàng (ON_PREMISE mode)

### Q: Có hỗ trợ server on-premise không?
**A:** Có. Khi cấu hình license key với mode ON_PREMISE, SDK sẽ gửi dữ liệu đến server của khách hàng thay vì cloud của EOV.

### Q: Cần bao nhiêu ảnh để đăng ký?
**A:** SDK yêu cầu 5 ảnh ở 5 góc khác nhau (thẳng, trái, phải, trên, dưới) để đảm bảo độ chính xác cao khi nhận diện.

### Q: Nhận diện có cần kết nối mạng không?
**A:** Không. Nhận diện hoàn toàn offline bằng cách so sánh với database local. Chỉ cần mạng khi đăng ký để sync lên server.

---

## 📞 Hỗ trợ

- **Email:** support@eovsolutions.com
- **Website:** https://eovsolutions.com
- **Documentation:** https://docs.eovsolutions.com/face-sdk

---

*© 2026 EOV Solutions. All rights reserved.*
