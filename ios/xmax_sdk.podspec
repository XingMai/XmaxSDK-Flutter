Pod::Spec.new do |s|
  s.name = 'xmax_sdk'
  s.version = '1.0.2'
  s.summary = 'XmaxSDK native logging for Flutter.'
  s.description = 'Routes enabled XmaxSDK Flutter logs to the iOS unified logging system.'
  s.homepage = 'https://github.com/XingMai/XmaxSDK-Flutter'
  s.license = { :type => 'MIT', :file => '../LICENSE' }
  s.author = { 'Xmax AI' => 'sdk@xmax.ai' }
  s.source = { :path => '.' }
  s.source_files = 'xmax_sdk/Sources/xmax_sdk/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
