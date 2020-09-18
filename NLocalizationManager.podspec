Pod::Spec.new do |spec|

  spec.name         = "NLocalizationManager"
  spec.version      = "3.1.2"
  spec.summary      = "A manager for handling localization in your application."
  spec.description  = <<-DESC
  Handles localization logic for your application, including smart language
  choosing and other features.
                   DESC

  spec.homepage     = "https://nodes-ios.github.io/TranslationManager/"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Nodes - iOS" => "ios@nodes.dk" }
  spec.source       = { :git => "https://github.com/nodes-ios/TranslationManager.git", :tag => "#{spec.version}" }

  # ――― Deployment ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  spec.ios.deployment_target        = "10.3"
  spec.osx.deployment_target        = "10.11"
  spec.watchos.deployment_target    = "2.0"
  spec.tvos.deployment_target       = "10.2"

  spec.swift_version = '5.0'

  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  spec.source_files  = "NLocalizationManager/Classes/**/*.swift"
  spec.user_target_xcconfig = { 'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES' }
  spec.pod_target_xcconfig = { 'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES' }

end
