#!/usr/bin/env ruby
# Generates a minimal DealerOps.xcodeproj/project.pbxproj
# Run: ruby scripts/generate_xcodeproj.rb

require 'securerandom'

def uuid
  SecureRandom.hex(12).upcase
end

# Collect all Swift files for the app target (exclude Tests)
swift_files = Dir.glob("{App,Models,Persistence,Repositories,Services}/**/*.swift").sort
resource_files = ["Resources/LaunchScreen.storyboard", "Resources/Info.plist"]

# Generate UUIDs for each file
file_refs = {}
build_files = {}
swift_files.each do |f|
  file_refs[f] = uuid
  build_files[f] = uuid
end
resource_refs = {}
resource_build = {}
resource_files.each do |f|
  resource_refs[f] = uuid
  resource_build[f] = uuid
end

# Group UUIDs
root_group = uuid
app_group = uuid
models_group = uuid
persistence_group = uuid
repos_group = uuid
services_group = uuid
resources_group = uuid
products_group = uuid
frameworks_group = uuid

# Target and project UUIDs
project_id = uuid
app_target = uuid
product_ref = uuid
build_config_list_project = uuid
build_config_list_target = uuid
debug_config_project = uuid
release_config_project = uuid
debug_config_target = uuid
release_config_target = uuid
sources_phase = uuid
resources_phase = uuid
frameworks_phase = uuid

pbxproj = <<~PBX
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
#{swift_files.map { |f| "\t\t#{build_files[f]} /* #{File.basename(f)} */ = {isa = PBXBuildFile; fileRef = #{file_refs[f]}; };" }.join("\n")}
#{resource_files.select{|f| f.end_with?('.storyboard')}.map { |f| "\t\t#{resource_build[f]} /* #{File.basename(f)} */ = {isa = PBXBuildFile; fileRef = #{resource_refs[f]}; };" }.join("\n")}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
#{swift_files.map { |f| "\t\t#{file_refs[f]} /* #{File.basename(f)} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"#{f}\"; sourceTree = \"<group>\"; };" }.join("\n")}
#{resource_files.map { |f|
  ftype = f.end_with?('.plist') ? 'text.plist.xml' : 'file.storyboard'
  "\t\t#{resource_refs[f]} /* #{File.basename(f)} */ = {isa = PBXFileReference; lastKnownFileType = #{ftype}; path = \"#{f}\"; sourceTree = \"<group>\"; };"
}.join("\n")}
		#{product_ref} /* DealerOps.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = DealerOps.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
		#{root_group} = {
			isa = PBXGroup;
			children = (
#{swift_files.map { |f| "\t\t\t\t#{file_refs[f]}," }.join("\n")}
#{resource_files.map { |f| "\t\t\t\t#{resource_refs[f]}," }.join("\n")}
				#{products_group},
			);
			sourceTree = "<group>";
		};
		#{products_group} /* Products */ = {
			isa = PBXGroup;
			children = (
				#{product_ref},
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		#{app_target} /* DealerOps */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = #{build_config_list_target};
			buildPhases = (
				#{sources_phase},
				#{resources_phase},
				#{frameworks_phase},
			);
			buildRules = ();
			dependencies = ();
			name = DealerOps;
			productName = DealerOps;
			productReference = #{product_ref};
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		#{project_id} /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
			};
			buildConfigurationList = #{build_config_list_project};
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (en, Base);
			mainGroup = #{root_group};
			productRefGroup = #{products_group};
			projectDirPath = "";
			projectRoot = "";
			targets = (#{app_target});
		};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
		#{sources_phase} = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
#{swift_files.map { |f| "\t\t\t\t#{build_files[f]}," }.join("\n")}
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXResourcesBuildPhase section */
		#{resources_phase} = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
#{resource_files.select{|f| f.end_with?('.storyboard')}.map { |f| "\t\t\t\t#{resource_build[f]}," }.join("\n")}
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXFrameworksBuildPhase section */
		#{frameworks_phase} = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = ();
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin XCBuildConfiguration section */
		#{debug_config_project} /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)");
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		#{release_config_project} /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_OPTIMIZATION_LEVEL = s;
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		#{debug_config_target} /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Resources/DealerOps.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Resources/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.eaglepoint.dealerops;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		#{release_config_target} /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Resources/DealerOps.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Resources/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.eaglepoint.dealerops;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		#{build_config_list_project} = {
			isa = XCConfigurationList;
			buildConfigurations = (#{debug_config_project}, #{release_config_project});
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		#{build_config_list_target} = {
			isa = XCConfigurationList;
			buildConfigurations = (#{debug_config_target}, #{release_config_target});
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

	};
	rootObject = #{project_id};
}
PBX

File.write("DealerOps.xcodeproj/project.pbxproj", pbxproj)
puts "Generated DealerOps.xcodeproj/project.pbxproj with #{swift_files.length} source files"
