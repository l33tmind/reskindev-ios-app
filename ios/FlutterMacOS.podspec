Pod::Spec.new do |s|
  s.name             = 'FlutterMacOS'
  s.version          = '1.0.0'
  s.summary          = 'Mock'
  s.homepage         = 'https://flutter.dev'
  s.license          = { :type => 'BSD' }
  s.author           = { 'Flutter Dev' => 'flutter-dev@googlegroups.com' }
  s.source           = { :git => 'https://github.com/flutter/engine', :tag => s.version.to_s }
  s.osx.deployment_target = '10.15'
  s.ios.deployment_target = '13.0'
  s.vendored_frameworks = 'path/to/nothing'
end
