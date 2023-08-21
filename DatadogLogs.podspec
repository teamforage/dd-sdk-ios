Pod::Spec.new do |s|
  s.name         = "DatadogLogsFork"
  s.version      = "2.1.0"
  s.summary      = "Forage's fork of the Datadog Logs Module."
  
  s.homepage     = "https://www.datadoghq.com"
  s.social_media_url   = "https://twitter.com/datadoghq"

  s.license            = { :type => "Apache", :file => 'LICENSE' }
  s.authors            = { 
    "Maciek Grzybowski" => "maciek.grzybowski@datadoghq.com",
    "Maciej Burda" => "maciej.burda@datadoghq.com",
    "Maxime Epain" => "maxime.epain@datadoghq.com"
  }

  s.swift_version = '5.5'
  s.ios.deployment_target = '11.0'
  s.tvos.deployment_target = '11.0'

  s.source = { :git => "https://github.com/teamforage/dd-sdk-ios-fork.git", :tag => s.version.to_s }
  
  s.source_files = ["DatadogLogs/Sources/**/*.swift"]

  s.dependency 'DatadogInternalFork', s.version.to_s

end
