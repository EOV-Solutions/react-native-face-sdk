require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name         = "react-native-face-sdk"
  s.version      = package['version']
  s.summary      = package['description']
  s.homepage     = package['homepage']
  s.license      = package['license']
  s.authors      = { "EOV Solutions" => "dev@eov.vn" }
  s.platforms    = { :ios => "12.0" }
  s.source       = { :git => "https://github.com/EOV-Solutions/react-native-face-sdk.git", :tag => "v#{s.version}" }
  
  s.source_files = "ios/**/*.{h,m,mm,swift}"
  s.requires_arc = true
  
  # React Native dependency
  install_modules_dependencies(s)
  
  # FaceSDK XCFramework (built from iOS-SDK-Face)
  s.vendored_frameworks = "ios/Frameworks/FaceSDK.xcframework"
  
  # Exclude C++ headers from public headers (they are implementation detail)
  s.public_header_files = "ios/**/*.h"
  s.private_header_files = "ios/Frameworks/**/*.h"
  
  # System frameworks required by FaceSDK
  s.frameworks = "AVFoundation", "CoreML", "Vision", "UIKit", "Foundation", "Accelerate", "Metal", "MetalKit", "CoreMedia", "CoreVideo"
  s.libraries = "c++", "sqlite3"
  
  # Build settings for C++ compatibility
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'HEADER_SEARCH_PATHS' => '"$(inherited)" "$(PODS_TARGET_SRCROOT)/ios/Frameworks/FaceSDK.xcframework/ios-arm64/FaceSDK.framework/Headers"'
  }
  
  # Swift version
  s.swift_version = "5.0"
end
