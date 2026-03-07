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
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain an i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
