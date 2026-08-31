import os
import uuid

def uid():
    return uuid.uuid4().hex[:24].upper()

project_name = "MoneyCity"
bundle_id = "com.moneycity.app"
root_dir = os.path.dirname(os.path.abspath(__file__))
source_dir = os.path.join(root_dir, "MoneyCity")

# Gather all source files and resources
swift_files = []
resource_files = []
xcassets_catalogs = []
xcprivacy_files = []
_seen_xcassets = set()

for root, dirs, files in os.walk(source_dir):
    # Skip into xcassets internally – treat whole bundle as one resource
    dirs[:] = [d for d in dirs if not d.endswith('.xcassets') and not d.endswith('.appiconset') and not d.endswith('.colorset')]
    for d in os.listdir(root):
        full = os.path.join(root, d)
        if d.endswith('.xcassets') and os.path.isdir(full) and full not in _seen_xcassets:
            _seen_xcassets.add(full)
            rel_path = os.path.relpath(full, root_dir)
            xcassets_catalogs.append((d, rel_path))
    for f in sorted(files):
        if f.startswith('.'):
            continue
        rel_path = os.path.relpath(os.path.join(root, f), root_dir)
        if f.endswith('.swift'):
            swift_files.append((f, rel_path))
        elif f.endswith('.xcprivacy'):
            xcprivacy_files.append((f, rel_path))
        elif f.endswith('.html') or f.endswith('.js') or f.endswith('.png') or f.endswith('.jpg'):
            resource_files.append((f, rel_path))

print(f"Found {len(swift_files)} Swift files, {len(resource_files)} Resource files, {len(xcassets_catalogs)} Asset Catalogs, {len(xcprivacy_files)} Privacy files.")

# Generate UUIDs
proj_id = uid()
main_group_id = uid()
products_group_id = uid()
product_id = uid()
target_id = uid()
sources_build_phase_id = uid()
resources_build_phase_id = uid()
frameworks_build_phase_id = uid()
debug_config_id = uid()
release_config_id = uid()
proj_debug_config_id = uid()
proj_release_config_id = uid()
config_list_target_id = uid()
config_list_proj_id = uid()

# File references and build files
file_refs = []
build_files = []

# Groups hierarchy
# Root -> MoneyCity -> (Models, Views, Services, Intents, Resources, MoneyCityApp.swift)
groups_dict = {}

def get_group_id(path):
    if path not in groups_dict:
        groups_dict[path] = (uid(), os.path.basename(path), [])
    return groups_dict[path][0]

for name, rel_path in swift_files:
    f_ref = uid()
    b_file = uid()
    file_refs.append((f_ref, name, rel_path, "sourcecode.swift"))
    build_files.append((b_file, f_ref, "Sources"))
    
    # Add to group
    parent_rel = os.path.dirname(rel_path)
    if parent_rel not in groups_dict:
        groups_dict[parent_rel] = (uid(), os.path.basename(parent_rel), [])
    groups_dict[parent_rel][2].append(f_ref)

for name, rel_path in resource_files:
    f_ref = uid()
    b_file = uid()
    ftype = "text.html" if name.endswith('.html') else ("sourcecode.javascript" if name.endswith('.js') else "file")
    file_refs.append((f_ref, name, rel_path, ftype))
    build_files.append((b_file, f_ref, "Resources"))
    
    parent_rel = os.path.dirname(rel_path)
    if parent_rel not in groups_dict:
        groups_dict[parent_rel] = (uid(), os.path.basename(parent_rel), [])
    groups_dict[parent_rel][2].append(f_ref)

# Asset catalogs go in as a single folder-like reference (wrapper.asset-catalog)
for name, rel_path in xcassets_catalogs:
    f_ref = uid()
    b_file = uid()
    file_refs.append((f_ref, name, rel_path, "wrapper.asset-catalog"))
    build_files.append((b_file, f_ref, "Resources"))
    parent_rel = os.path.dirname(rel_path)
    if parent_rel not in groups_dict:
        groups_dict[parent_rel] = (uid(), os.path.basename(parent_rel), [])
    groups_dict[parent_rel][2].append(f_ref)

# Privacy manifest
for name, rel_path in xcprivacy_files:
    f_ref = uid()
    b_file = uid()
    file_refs.append((f_ref, name, rel_path, "text.xml"))
    build_files.append((b_file, f_ref, "Resources"))
    parent_rel = os.path.dirname(rel_path)
    if parent_rel not in groups_dict:
        groups_dict[parent_rel] = (uid(), os.path.basename(parent_rel), [])
    groups_dict[parent_rel][2].append(f_ref)

# Build pbxproj content
pbx = []
pbx.append("// !$*UTF8*$!")
pbx.append("{")
pbx.append("\tarchiveVersion = 1;")
pbx.append("\tclasses = {")
pbx.append("\t};")
pbx.append("\tobjectVersion = 56;")
pbx.append("\tobjects = {")

# PBXBuildFile
pbx.append("\n/* Begin PBXBuildFile section */")
for b_file, f_ref, ptype in build_files:
    pbx.append(f"\t\t{b_file} /* {ptype} in {project_name} */ = {{isa = PBXBuildFile; fileRef = {f_ref}; }};")
pbx.append("/* End PBXBuildFile section */")

# PBXFileReference
pbx.append("\n/* Begin PBXFileReference section */")
pbx.append(f"\t\t{product_id} /* {project_name}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {project_name}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
for f_ref, name, rel_path, ftype in file_refs:
    pbx.append(f"\t\t{f_ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; name = \"{name}\"; path = \"{rel_path}\"; sourceTree = \"<group>\"; }};")
pbx.append("/* End PBXFileReference section */")

# PBXFrameworksBuildPhase
pbx.append("\n/* Begin PBXFrameworksBuildPhase section */")
pbx.append(f"\t\t{frameworks_build_phase_id} /* Frameworks */ = {{")
pbx.append("\t\t\tisa = PBXFrameworksBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")
pbx.append("/* End PBXFrameworksBuildPhase section */")

# PBXGroup
pbx.append("\n/* Begin PBXGroup section */")
# Main group
main_children = [f"{products_group_id} /* Products */"]
for f_ref, name, rel_path, _ in file_refs:
    main_children.append(f"{f_ref} /* {name} */")

pbx.append(f"\t\t{main_group_id} = {{")
pbx.append("\t\t\tisa = PBXGroup;")
pbx.append("\t\t\tchildren = (")
for c in main_children:
    pbx.append(f"\t\t\t\t{c},")
pbx.append("\t\t\t);")
pbx.append("\t\t\tsourceTree = \"<group>\";")
pbx.append("\t\t};")

pbx.append(f"\t\t{products_group_id} /* Products */ = {{")
pbx.append("\t\t\tisa = PBXGroup;")
pbx.append("\t\t\tchildren = (")
pbx.append(f"\t\t\t\t{product_id} /* {project_name}.app */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tname = Products;")
pbx.append("\t\t\tsourceTree = \"<group>\";")
pbx.append("\t\t};")
pbx.append("/* End PBXGroup section */")

# PBXNativeTarget
pbx.append("\n/* Begin PBXNativeTarget section */")
pbx.append(f"\t\t{target_id} /* {project_name} */ = {{")
pbx.append("\t\t\tisa = PBXNativeTarget;")
pbx.append(f"\t\t\tbuildConfigurationList = {config_list_target_id} /* Build configuration list for PBXNativeTarget \"{project_name}\" */;")
pbx.append("\t\t\tbuildPhases = (")
pbx.append(f"\t\t\t\t{sources_build_phase_id} /* Sources */,")
pbx.append(f"\t\t\t\t{frameworks_build_phase_id} /* Frameworks */,")
pbx.append(f"\t\t\t\t{resources_build_phase_id} /* Resources */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tbuildRules = (")
pbx.append("\t\t\t);")
pbx.append("\t\t\tdependencies = (")
pbx.append("\t\t\t);")
pbx.append(f"\t\t\tname = {project_name};")
pbx.append(f"\t\t\tproductName = {project_name};")
pbx.append(f"\t\t\tproductReference = {product_id} /* {project_name}.app */;")
pbx.append("\t\t\tproductType = \"com.apple.product-type.application\";")
pbx.append("\t\t};")
pbx.append("/* End PBXNativeTarget section */")

# PBXProject
pbx.append("\n/* Begin PBXProject section */")
pbx.append(f"\t\t{proj_id} /* Project object */ = {{")
pbx.append("\t\t\tisa = PBXProject;")
pbx.append("\t\t\tattributes = {")
pbx.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
pbx.append("\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;")
pbx.append("\t\t\t\tLastSwiftUpdateCheck = 1600;")
pbx.append("\t\t\t\tLastUpgradeCheck = 1600;")
pbx.append("\t\t\t\tTargetAttributes = {")
pbx.append(f"\t\t\t\t\t{target_id} = {{")
pbx.append(f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
pbx.append("\t\t\t\t\t};")
pbx.append("\t\t\t\t};")
pbx.append("\t\t\t};")
pbx.append(f"\t\t\tbuildConfigurationList = {config_list_proj_id} /* Build configuration list for PBXProject \"{project_name}\" */;")
pbx.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
pbx.append("\t\t\tdevelopmentRegion = en;")
pbx.append("\t\t\thasScannedForEncodings = 0;")
pbx.append("\t\t\tknownRegions = (")
pbx.append("\t\t\t\ten,")
pbx.append("\t\t\t\tBase,")
pbx.append("\t\t\t);")
pbx.append(f"\t\t\tmainGroup = {main_group_id};")
pbx.append(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
pbx.append("\t\t\tprojectDirPath = \"\";")
pbx.append("\t\t\tprojectRoot = \"\";")
pbx.append("\t\t\ttargets = (")
pbx.append(f"\t\t\t\t{target_id} /* {project_name} */,")
pbx.append("\t\t\t);")
pbx.append("\t\t};")
pbx.append("/* End PBXProject section */")

# PBXResourcesBuildPhase
pbx.append("\n/* Begin PBXResourcesBuildPhase section */")
pbx.append(f"\t\t{resources_build_phase_id} /* Resources */ = {{")
pbx.append("\t\t\tisa = PBXResourcesBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
for b_file, _, ptype in build_files:
    if ptype == "Resources":
        pbx.append(f"\t\t\t\t{b_file} /* {ptype} */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")
pbx.append("/* End PBXResourcesBuildPhase section */")

# PBXSourcesBuildPhase
pbx.append("\n/* Begin PBXSourcesBuildPhase section */")
pbx.append(f"\t\t{sources_build_phase_id} /* Sources */ = {{")
pbx.append("\t\t\tisa = PBXSourcesBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
for b_file, _, ptype in build_files:
    if ptype == "Sources":
        pbx.append(f"\t\t\t\t{b_file} /* {ptype} */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")
pbx.append("/* End PBXSourcesBuildPhase section */")

# XCBuildConfiguration
pbx.append("\n/* Begin XCBuildConfiguration section */")
pbx.append(f"\t\t{proj_debug_config_id} /* Debug */ = {{")
pbx.append("\t\t\tisa = XCBuildConfiguration;")
pbx.append("\t\t\tbuildSettings = {")
pbx.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
pbx.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
pbx.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
pbx.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
pbx.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
pbx.append("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
pbx.append("\t\t\t\tENABLE_TESTABILITY = YES;")
pbx.append("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
pbx.append("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
pbx.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
pbx.append("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (")
pbx.append("\t\t\t\t\t\"DEBUG=1\",")
pbx.append("\t\t\t\t\t\"$(inherited)\",")
pbx.append("\t\t\t\t);")
pbx.append("\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;")
pbx.append("\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;")
pbx.append("\t\t\t\tGCC_WARN_UNDEFINED_VARIABLES = YES;")
pbx.append("\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;")
pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
pbx.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
pbx.append("\t\t\t\tMTL_FAST_MATH = YES;")
pbx.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
pbx.append("\t\t\t\tSDKROOT = iphoneos;")
pbx.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
pbx.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
pbx.append("\t\t\t\tSWIFT_VERSION = 5.0;")
pbx.append("\t\t\t};")
pbx.append(f"\t\t\tname = Debug;")
pbx.append("\t\t};")

pbx.append(f"\t\t{proj_release_config_id} /* Release */ = {{")
pbx.append("\t\t\tisa = XCBuildConfiguration;")
pbx.append("\t\t\tbuildSettings = {")
pbx.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
pbx.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
pbx.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
pbx.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
pbx.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
pbx.append("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
pbx.append("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
pbx.append("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
pbx.append("\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;")
pbx.append("\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;")
pbx.append("\t\t\t\tGCC_WARN_UNDEFINED_VARIABLES = YES;")
pbx.append("\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;")
pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
pbx.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
pbx.append("\t\t\t\tMTL_FAST_MATH = YES;")
pbx.append("\t\t\t\tSDKROOT = iphoneos;")
pbx.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
pbx.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
pbx.append("\t\t\t\tSWIFT_VERSION = 5.0;")
pbx.append("\t\t\t\tVALIDATE_PRODUCT = YES;")
pbx.append("\t\t\t};")
pbx.append(f"\t\t\tname = Release;")
pbx.append("\t\t};")

# Target build configs
pbx.append(f"\t\t{debug_config_id} /* Debug */ = {{")
pbx.append("\t\t\tisa = XCBuildConfiguration;")
pbx.append("\t\t\tbuildSettings = {")
pbx.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
pbx.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
pbx.append("\t\t\t\tCODE_SIGN_IDENTITY = \"Apple Development\";")
pbx.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
pbx.append("\t\t\t\tENABLE_PREVIEWS = YES;")
pbx.append("\t\t\t\tENABLE_DEBUG_DYLIB = YES;")
pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
pbx.append(f"\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"SPENT\";")
pbx.append("\t\t\t\tINFOPLIST_KEY_LSRequiresIPhoneOS = YES;")
pbx.append("\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;")
pbx.append("\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;")
pbx.append("\t\t\t\tINFOPLIST_KEY_CFBundleURLTypes = ( { CFBundleURLName = \"com.moneycity.app\"; CFBundleURLSchemes = ( spentapp, moneycity ); } );")
pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
pbx.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
pbx.append("\t\t\t\t\t\"$(inherited)\",")
pbx.append("\t\t\t\t\t\"@executable_path/Frameworks\",")
pbx.append("\t\t\t\t);")
pbx.append("\t\t\t\tMARKETING_VERSION = 1.0;")
pbx.append(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"{bundle_id}\";")
pbx.append(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
pbx.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
pbx.append("\t\t\t\tSWIFT_VERSION = 5.0;")
pbx.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1\";")
pbx.append("\t\t\t};")
pbx.append(f"\t\t\tname = Debug;")
pbx.append("\t\t};")

pbx.append(f"\t\t{release_config_id} /* Release */ = {{")
pbx.append("\t\t\tisa = XCBuildConfiguration;")
pbx.append("\t\t\tbuildSettings = {")
pbx.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
pbx.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
pbx.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
pbx.append("\t\t\t\tCODE_SIGN_IDENTITY = \"Apple Development\";")
pbx.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
pbx.append("\t\t\t\tENABLE_PREVIEWS = YES;")
pbx.append("\t\t\t\tENABLE_DEBUG_DYLIB = YES;")
pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
pbx.append(f"\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"SPENT\";")
pbx.append("\t\t\t\tINFOPLIST_KEY_LSRequiresIPhoneOS = YES;")
pbx.append("\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;")
pbx.append("\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;")
pbx.append("\t\t\t\tINFOPLIST_KEY_CFBundleURLTypes = ( { CFBundleURLName = \"com.moneycity.app\"; CFBundleURLSchemes = ( spentapp, moneycity ); } );")
pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
pbx.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
pbx.append("\t\t\t\t\t\"$(inherited)\",")
pbx.append("\t\t\t\t\t\"@executable_path/Frameworks\",")
pbx.append("\t\t\t\t);")
pbx.append("\t\t\t\tMARKETING_VERSION = 1.0;")
pbx.append(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"{bundle_id}\";")
pbx.append(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
pbx.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
pbx.append("\t\t\t\tSWIFT_VERSION = 5.0;")
pbx.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1\";")
pbx.append("\t\t\t};")
pbx.append(f"\t\t\tname = Release;")
pbx.append("\t\t};")
pbx.append("/* End XCBuildConfiguration section */")

# XCConfigurationList
pbx.append("\n/* Begin XCConfigurationList section */")
pbx.append(f"\t\t{config_list_proj_id} /* Build configuration list for PBXProject \"{project_name}\" */ = {{")
pbx.append("\t\t\tisa = XCConfigurationList;")
pbx.append("\t\t\tbuildConfigurations = (")
pbx.append(f"\t\t\t\t{proj_debug_config_id} /* Debug */,")
pbx.append(f"\t\t\t\t{proj_release_config_id} /* Release */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tdefaultConfigurationIsVisible = 0;")
pbx.append("\t\t\tdefaultConfigurationName = Release;")
pbx.append("\t\t};")

pbx.append(f"\t\t{config_list_target_id} /* Build configuration list for PBXNativeTarget \"{project_name}\" */ = {{")
pbx.append("\t\t\tisa = XCConfigurationList;")
pbx.append("\t\t\tbuildConfigurations = (")
pbx.append(f"\t\t\t\t{debug_config_id} /* Debug */,")
pbx.append(f"\t\t\t\t{release_config_id} /* Release */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tdefaultConfigurationIsVisible = 0;")
pbx.append("\t\t\tdefaultConfigurationName = Release;")
pbx.append("\t\t};")
pbx.append("/* End XCConfigurationList section */")

pbx.append("\t};")
pbx.append(f"\trootObject = {proj_id} /* Project object */;")
pbx.append("}")

proj_dir = os.path.join(root_dir, f"{project_name}.xcodeproj")
os.makedirs(proj_dir, exist_ok=True)
pbx_path = os.path.join(proj_dir, "project.pbxproj")

with open(pbx_path, "w", encoding="utf-8") as f:
    f.write("\n".join(pbx) + "\n")

print(f"Successfully generated {pbx_path}")
