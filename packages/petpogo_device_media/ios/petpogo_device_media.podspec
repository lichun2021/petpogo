Pod::Spec.new do |s|
  s.name = 'petpogo_device_media'
  s.version = '0.1.0'
  s.summary = 'Device PCM playback and local MP4 encoding.'
  s.description = 'PetPogo device stream native media support.'
  s.homepage = 'https://www.jxpetai.com'
  s.license = { :type => 'Proprietary' }
  s.author = { 'PetPogo' => 'dev@jxpetai.com' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
  s.frameworks = 'AVFoundation', 'AudioToolbox', 'UIKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
