Pod::Spec.new do |s|
  s.name         = "DatadogSessionReplay"
  s.module_name  = "DatadogSessionReplay"
  s.version      = "1.13.0"
  s.summary      = "Official Datadog Session Replay SDK for iOS."
  
  s.homepage     = "https://www.datadoghq.com"
  s.social_media_url   = "https://twitter.com/datadoghq"

  s.license            = { :type => "Apache", :file => 'LICENSE' }
  s.authors            = { 
    "Maciek Grzybowski" => "maciek.grzybowski@datadoghq.com",
    "Maciej Burda" => "maciej.burda@datadoghq.com",
    "Maxime Epain" => "maxime.epain@datadoghq.com"
  }

  s.swift_version      = '5.1'
  s.ios.deployment_target = '11.0'
  s.tvos.deployment_target = '11.0'

  s.source = { :git => 'https://github.com/DataDog/dd-sdk-ios.git', :tag => s.version.to_s }
  s.static_framework = true

  s.source_files = "session-replay/Sources/DatadogSessionReplay/**/*.swift"
  s.dependency 'DatadogSDK', '1.13.0'
end
