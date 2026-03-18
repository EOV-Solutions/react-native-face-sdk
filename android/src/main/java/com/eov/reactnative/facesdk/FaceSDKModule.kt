package com.eov.reactnative.facesdk

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.modules.core.PermissionAwareActivity
import com.facebook.react.modules.core.PermissionListener

import com.eov.facesdk.FaceSDK
import com.eov.facekit.ui.MultiStepRegisterActivity
import com.eov.facekit.ui.LiveRecognitionActivity

/**
 * React Native Module for Face SDK
 * Bridges JavaScript calls to Android Face SDK
 */
@ReactModule(name = FaceSDKModule.NAME)
class FaceSDKModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext),
    ActivityEventListener,
    PermissionListener {

    companion object {
        const val NAME = "FaceSDK"
        private const val TAG = "FaceSDKModule"
        private const val REQUEST_REGISTRATION = 2001
        private const val REQUEST_RECOGNITION = 2002
        private const val REQUEST_CAMERA_PERMISSION = 2003
    }

    private var registrationPromise: Promise? = null
    private var recognitionPromise: Promise? = null
    private var permissionPromise: Promise? = null

    init {
        reactContext.addActivityEventListener(this)
    }

    override fun getName(): String = NAME

    // ============ License & Initialization ============

    @ReactMethod
    fun initialize(options: ReadableMap, promise: Promise) {
        val licenseKey = options.getString("licenseKey")
        if (licenseKey.isNullOrEmpty()) {
            promise.reject("E_INVALID_PARAMS", "licenseKey is required")
            return
        }

        val faceId = options.getString("faceId")
        val userName = options.getString("userName")
        val orgId = options.getString("orgId")

        // Set userName before license activation (it will be saved with the license)
        if (!userName.isNullOrEmpty()) {
            FaceSDK.setUserName(userName)
        }

        try {
            FaceSDK.initializeLicense(
                reactApplicationContext,
                licenseKey,
                faceId,
                object : FaceSDK.LicenseCallback {
                    override fun onSuccess() {
                        // Initialize SDK after license
                        FaceSDK.initialize(reactApplicationContext, object : FaceSDK.InitCallback {
                            override fun onSuccess() {
                                // Set organization if provided
                                if (!orgId.isNullOrEmpty()) {
                                    FaceSDK.getInstance().setOrganization(orgId)
                                }
                                
                                promise.resolve(Arguments.createMap().apply {
                                    putBoolean("success", true)
                                    putString("message", "SDK initialized successfully")
                                })
                            }

                            override fun onError(error: com.eov.facesdk.SDKException) {
                                promise.reject("E_INIT_FAILED", error.message)
                            }
                        })
                    }

                    override fun onError(errorMessage: String) {
                        promise.reject("E_LICENSE_FAILED", errorMessage)
                    }
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Initialize failed", e)
            promise.reject("E_INIT_FAILED", e.message)
        }
    }

    @ReactMethod
    fun isLicenseValid(promise: Promise) {
        try {
            val valid = FaceSDK.isLicenseValid()
            val status = FaceSDK.getLicenseStatus()
            val message = FaceSDK.getStatusMessage(status)

            promise.resolve(Arguments.createMap().apply {
                putBoolean("valid", valid)
                putInt("status", status)
                putString("message", message)
            })
        } catch (e: Exception) {
            promise.reject("E_LICENSE_CHECK_FAILED", e.message)
        }
    }

    @ReactMethod
    fun getLicenseStatus(promise: Promise) {
        try {
            promise.resolve(FaceSDK.getLicenseStatus())
        } catch (e: Exception) {
            promise.reject("E_LICENSE_STATUS_FAILED", e.message)
        }
    }

    // ============ Terminate & Cleanup ============

    /**
     * Terminate the SDK and release all resources (AI models, sessions, etc.)
     * Call this when your app exits or when you want to free up memory.
     */
    @ReactMethod
    fun terminate(promise: Promise) {
        try {
            FaceSDK.getInstance().terminate()
            promise.resolve(Arguments.createMap().apply {
                putBoolean("success", true)
                putString("message", "SDK terminated successfully")
            })
        } catch (e: Exception) {
            Log.e(TAG, "Terminate failed", e)
            promise.reject("E_TERMINATE_FAILED", e.message)
        }
    }

    /**
     * Check if SDK is initialized
     */
    @ReactMethod
    fun isInitialized(promise: Promise) {
        try {
            promise.resolve(FaceSDK.getInstance().isInitialized())
        } catch (e: Exception) {
            promise.reject("E_CHECK_FAILED", e.message)
        }
    }

    // ============ Registration ============

    @ReactMethod
    fun startRegistration(options: ReadableMap, promise: Promise) {
        val activity = reactApplicationContext.currentActivity
        if (activity == null) {
            promise.reject("E_NO_ACTIVITY", "Activity is null")
            return
        }

        if (!hasPermission()) {
            promise.reject("E_PERMISSION", "Camera permission not granted")
            return
        }

        registrationPromise = promise

        try {
            val intent = Intent(activity, MultiStepRegisterActivity::class.java)
            
            if (options.hasKey("userName")) {
                intent.putExtra(MultiStepRegisterActivity.EXTRA_USER_NAME, options.getString("userName"))
            }
            if (options.hasKey("orgId")) {
                intent.putExtra(MultiStepRegisterActivity.EXTRA_ORG_ID, options.getString("orgId"))
            }
            if (options.hasKey("skipNameDialog")) {
                intent.putExtra(MultiStepRegisterActivity.EXTRA_SKIP_NAME_DIALOG, options.getBoolean("skipNameDialog"))
            }

            activity.startActivityForResult(intent, REQUEST_REGISTRATION)
        } catch (e: Exception) {
            Log.e(TAG, "Error launching registration", e)
            registrationPromise = null
            promise.reject("E_LAUNCH_FAILED", "Failed to launch registration: ${e.message}")
        }
    }

    @ReactMethod
    fun isUserEnrolled(userId: String, promise: Promise) {
        try {
            promise.resolve(FaceSDK.getInstance().isUserEnrolled(userId))
        } catch (e: Exception) {
            promise.reject("E_CHECK_FAILED", e.message)
        }
    }

    @ReactMethod
    fun deleteUser(userId: String, promise: Promise) {
        try {
            promise.resolve(FaceSDK.getInstance().deleteUser(userId))
        } catch (e: Exception) {
            promise.reject("E_DELETE_FAILED", e.message)
        }
    }

    // ============ Refresh Embeddings ============

    @ReactMethod
    fun refreshEmbeddings(faceId: String, promise: Promise) {
        try {
            FaceSDK.refreshEmbeddings(
                reactApplicationContext,
                faceId,
                object : FaceSDK.RefreshCallback {
                    override fun onSuccess(deletedCount: Int, userId: String, userName: String) {
                        promise.resolve(Arguments.createMap().apply {
                            putBoolean("success", true)
                            putInt("deletedCount", deletedCount)
                            putString("userId", userId)
                            putString("userName", userName)
                            putString("message", "Embeddings refreshed successfully")
                        })
                    }

                    override fun onError(errorMessage: String) {
                        promise.reject("E_REFRESH_FAILED", errorMessage)
                    }
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "refreshEmbeddings failed", e)
            promise.reject("E_REFRESH_FAILED", e.message)
        }
    }

    // ============ Recognition ============

    @ReactMethod
    fun startRecognition(options: ReadableMap, promise: Promise) {
        val activity = reactApplicationContext.currentActivity
        if (activity == null) {
            promise.reject("E_NO_ACTIVITY", "Activity is null")
            return
        }

        if (!hasPermission()) {
            promise.reject("E_PERMISSION", "Camera permission not granted")
            return
        }

        recognitionPromise = promise

        try {
            val intent = Intent(activity, LiveRecognitionActivity::class.java)
            
            if (options.hasKey("orgId")) {
                intent.putExtra(LiveRecognitionActivity.EXTRA_ORG_ID, options.getString("orgId"))
            }
            if (options.hasKey("timeoutSeconds")) {
                intent.putExtra(LiveRecognitionActivity.EXTRA_TIMEOUT_SECONDS, options.getInt("timeoutSeconds"))
            }

            activity.startActivityForResult(intent, REQUEST_RECOGNITION)
        } catch (e: Exception) {
            Log.e(TAG, "Error launching recognition", e)
            recognitionPromise = null
            promise.reject("E_LAUNCH_FAILED", "Failed to launch recognition: ${e.message}")
        }
    }

    // ============ Permissions ============

    @ReactMethod
    fun checkPermission(promise: Promise) {
        promise.resolve(Arguments.createMap().apply {
            putBoolean("granted", hasPermission())
            putString("status", if (hasPermission()) "granted" else "denied")
        })
    }

    @ReactMethod
    fun requestPermission(promise: Promise) {
        if (hasPermission()) {
            promise.resolve(Arguments.createMap().apply {
                putBoolean("granted", true)
                putString("status", "granted")
            })
            return
        }

        val activity = reactApplicationContext.currentActivity
        if (activity == null) {
            promise.reject("E_NO_ACTIVITY", "Activity is null")
            return
        }

        permissionPromise = promise

        if (activity is PermissionAwareActivity) {
            activity.requestPermissions(
                arrayOf(Manifest.permission.CAMERA),
                REQUEST_CAMERA_PERMISSION,
                this
            )
        } else {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.CAMERA),
                REQUEST_CAMERA_PERMISSION
            )
        }
    }

    // ============ Internal Helpers ============

    private fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            reactApplicationContext,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    // ============ Device Compatibility ============

    @ReactMethod
    fun checkDeviceCompatibility(promise: Promise) {
        try {
            val context = reactApplicationContext
            val unsupportedReasons = mutableListOf<String>()

            // 1. Check front camera
            val hasFrontCamera = checkFrontCamera(context)
            if (!hasFrontCamera) unsupportedReasons.add("No front-facing camera detected")

            // 2. Check OS version (Android 7.0 / API 24+)
            val osVersion = Build.VERSION.SDK_INT.toString()
            val osVersionSupported = Build.VERSION.SDK_INT >= 24
            if (!osVersionSupported) unsupportedReasons.add("Android API ${Build.VERSION.SDK_INT} is below minimum (24 / Android 7.0)")

            // 3. Check CPU architecture (arm64-v8a required for AI models)
            val supportedAbis = Build.SUPPORTED_ABIS?.toList() ?: emptyList()
            val cpuArchSupported = supportedAbis.any { it.contains("arm64") }
            if (!cpuArchSupported) unsupportedReasons.add("CPU architecture ${supportedAbis.joinToString()} does not include arm64-v8a")

            // 4. Check RAM (>= 2GB)
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memInfo)
            val totalRAMMB = (memInfo.totalMem / (1024 * 1024)).toInt()
            val hasEnoughRAM = totalRAMMB >= 2048
            if (!hasEnoughRAM) unsupportedReasons.add("Insufficient RAM: ${totalRAMMB}MB (minimum 2048MB)")

            // 5. Check available storage (>= 100MB)
            val stat = StatFs(Environment.getDataDirectory().path)
            val availableStorageMB = (stat.availableBlocksLong * stat.blockSizeLong / (1024 * 1024)).toInt()
            val hasEnoughStorage = availableStorageMB >= 100
            if (!hasEnoughStorage) unsupportedReasons.add("Insufficient storage: ${availableStorageMB}MB available (minimum 100MB)")

            // Device model
            val deviceModel = "${Build.MANUFACTURER} ${Build.MODEL}"

            // Overall compatibility
            val compatible = hasFrontCamera && osVersionSupported && cpuArchSupported && hasEnoughRAM && hasEnoughStorage

            val checks = Arguments.createMap().apply {
                putBoolean("hasFrontCamera", hasFrontCamera)
                putBoolean("osVersionSupported", osVersionSupported)
                putBoolean("cpuArchSupported", cpuArchSupported)
                putBoolean("hasEnoughRAM", hasEnoughRAM)
                putBoolean("hasEnoughStorage", hasEnoughStorage)
            }

            val reasons = Arguments.createArray()
            unsupportedReasons.forEach { reasons.pushString(it) }

            val message = if (compatible) {
                "Device is compatible with Face SDK"
            } else {
                "Device is NOT compatible: ${unsupportedReasons.joinToString("; ")}"
            }

            promise.resolve(Arguments.createMap().apply {
                putBoolean("compatible", compatible)
                putString("message", message)
                putString("platform", "android")
                putString("osVersion", osVersion)
                putString("deviceModel", deviceModel)
                putMap("checks", checks)
                putInt("totalRAM", totalRAMMB)
                putInt("availableStorage", availableStorageMB)
                putArray("unsupportedReasons", reasons)
            })
        } catch (e: Exception) {
            Log.e(TAG, "checkDeviceCompatibility failed", e)
            promise.reject("E_COMPATIBILITY_CHECK_FAILED", e.message)
        }
    }

    private fun checkFrontCamera(context: Context): Boolean {
        return try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            for (cameraId in cameraManager.cameraIdList) {
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                if (facing == CameraCharacteristics.LENS_FACING_FRONT) {
                    return true
                }
            }
            false
        } catch (e: Exception) {
            Log.w(TAG, "Error checking front camera", e)
            false
        }
    }

    // PermissionListener implementation
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == REQUEST_CAMERA_PERMISSION) {
            val granted = grantResults.isNotEmpty() && 
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            
            permissionPromise?.resolve(Arguments.createMap().apply {
                putBoolean("granted", granted)
                putString("status", if (granted) "granted" else "denied")
            })
            permissionPromise = null
            return true
        }
        return false
    }

    // ActivityEventListener implementation
    override fun onActivityResult(activity: Activity, requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            REQUEST_REGISTRATION -> handleRegistrationResult(resultCode, data)
            REQUEST_RECOGNITION -> handleRecognitionResult(resultCode, data)
        }
    }

    override fun onNewIntent(intent: Intent) {
        // Not used
    }

    private fun handleRegistrationResult(resultCode: Int, data: Intent?) {
        val promise = registrationPromise ?: return
        registrationPromise = null

        if (resultCode == Activity.RESULT_OK && data != null) {
            val success = data.getBooleanExtra(MultiStepRegisterActivity.EXTRA_RESULT_SUCCESS, false)
            val userId = data.getStringExtra(MultiStepRegisterActivity.EXTRA_RESULT_USER_ID)
            val userName = data.getStringExtra(MultiStepRegisterActivity.EXTRA_RESULT_USER_NAME)
            val orgId = data.getStringExtra(MultiStepRegisterActivity.EXTRA_RESULT_ORG_ID)
            val featureCount = data.getIntExtra(MultiStepRegisterActivity.EXTRA_RESULT_FEATURE_COUNT, 0)

            promise.resolve(Arguments.createMap().apply {
                putBoolean("success", success)
                userId?.let { putString("userId", it) }
                userName?.let { putString("userName", it) }
                orgId?.let { putString("orgId", it) }
                putInt("featureCount", featureCount)
            })
        } else {
            promise.resolve(Arguments.createMap().apply {
                putBoolean("success", false)
                putString("error", "Registration cancelled")
            })
        }
    }

    private fun handleRecognitionResult(resultCode: Int, data: Intent?) {
        val promise = recognitionPromise ?: return
        recognitionPromise = null

        if (resultCode == Activity.RESULT_OK && data != null) {
            // Use correct EXTRA_* keys from LiveRecognitionActivity
            val userId = data.getStringExtra(LiveRecognitionActivity.EXTRA_USER_ID)
            val userName = data.getStringExtra(LiveRecognitionActivity.EXTRA_USER_NAME)
            val confidence = data.getFloatExtra(LiveRecognitionActivity.EXTRA_CONFIDENCE, 0f)
            val isLive = data.getBooleanExtra(LiveRecognitionActivity.EXTRA_IS_LIVE, false)
            val isRecognized = data.getBooleanExtra(LiveRecognitionActivity.EXTRA_IS_RECOGNIZED, false)
            val imagePath = data.getStringExtra(LiveRecognitionActivity.EXTRA_IMAGE_PATH)

            promise.resolve(Arguments.createMap().apply {
                putBoolean("success", true)
                putBoolean("isLive", isLive)
                putBoolean("isRecognized", isRecognized)
                userId?.let { putString("userId", it) }
                userName?.let { putString("userName", it) }
                putDouble("confidence", confidence.toDouble())
                imagePath?.let { putString("imagePath", it) }
            })
        } else {
            promise.resolve(Arguments.createMap().apply {
                putBoolean("success", false)
                putBoolean("isLive", false)
                putBoolean("isRecognized", false)
                putString("error", "Recognition cancelled or timeout")
            })
        }
    }
}
