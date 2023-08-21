Pod::Spec.new do |s|
  s.name         = "TestUtilitiesFork"
  s.version      = "2.1.0"
  s.summary      = "Datadog Testing Utilities. This module is for internal testing and should not be published."
  
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

  s.source = { :git => "https://github.com/teamforage/dd-sdk-ios-fork.git", :tag => s.version.to_s }

  s.pod_target_xcconfig = {
    'ENABLE_TESTING_SEARCH_PATHS'=>'YES'
  }

  s.framework = 'XCTest'
  
  s.source_files = [
    "TestUtilities/Helpers/**/*.swift",
    "TestUtilities/Mocks/**/*.swift"
  ]

  s.dependency 'DatadogInternalFork'

end
