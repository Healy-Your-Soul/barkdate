require 'xcodeproj'
project_path = "Runner.xcodeproj"
project = Xcodeproj::Project.open(project_path)
project.targets.each do |target|
  if target.name == "Runner"
    target.build_configurations.each do |config|
      if config.name == "Release" || config.name == "Profile"
        config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = "match AppStore com.edwardlich.barkdate"
        config.build_settings['CODE_SIGN_IDENTITY'] = "Apple Distribution"
        config.build_settings['CODE_SIGN_STYLE'] = "Manual"
      end
    end
  end
end
project.save
