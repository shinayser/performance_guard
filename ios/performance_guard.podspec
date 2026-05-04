Pod::Spec.new do |s|
  s.name             = 'performance_guard'
  s.version          = '1.0.0'
  s.summary          = 'Flutter plugin for detecting ANRs and performance issues'
  s.description      = <<-DESC
A production-grade Flutter plugin that detects app freezes, ANRs, UI thread blocking,
and performance issues in real-time on both Android and iOS.
                       DESC
  s.homepage         = 'https://github.com/example/performance_guard'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Example' => 'example@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  # iOS 13+ required: iOS 12 support was dropped in Xcode 16+.
  # iOS 13 also adds arm64 simulator support needed for Apple Silicon Macs (iOS 26+ simulators).
  s.platform = :ios, '13.0'

  # Only exclude legacy i386 (32-bit) simulator slice — do NOT exclude arm64,
  # which is required for Apple Silicon iOS 26+ simulators.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
