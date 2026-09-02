import os
import uuid

def uid():
    return uuid.uuid4().hex[:24].upper()

project_name = "MoneyCity"
bundle_id = "com.moneycity.app"
widget_bundle_id = "com.moneycity.app.spent-fast"
root_dir = os.path.dirname(os.path.abspath(__file__))
source_dir = os.path.join(root_dir, "MoneyCity")
widget_dir = os.path.join(root_dir, "spent fast")

# 1. Gather Main App source files and resources
swift_files = []
resource_files = []
xcassets_catalogs = []
xcprivacy_files = []
_seen_xcassets = set()

for root, dirs, files in os.walk(source_dir):
    dirs[:] = [d for d in dirs if not d.endswith(".xcassets") and not d.endswith(".appiconset") and not d.endswith(".colorset")]
    for d in os.listdir(root):
        full = os.path.join(root, d)
        if d.endswith(".xcassets") and os.path.isdir(full) and full not in _seen_xcassets:
            _seen_xcassets.add(full)
            rel_path = os.path.relpath(full, root_dir)
            xcassets_catalogs.append((d, rel_path))
    for f in sorted(files):
        if f.startswith("."):
            continue
        rel_path = os.path.relpath(os.path.join(root, f), root_dir)
        if f.endswith(".swift"):
            swift_files.append((f, rel_path))
        elif f.endswith(".xcprivacy"):
            xcprivacy_files.append((f, rel_path))
        elif f.endswith(".html") or f.endswith(".js") or f.endswith(".png") or f.endswith(".jpg"):
            resource_files.append((f, rel_path))

# 2. Gather Widget Extension source files and resources
widget_swift_files = []
widget_resource_files = []
widget_xcassets_catalogs = []

for root, dirs, files in os.walk(widget_dir):
    dirs[:] = [d for d in dirs if not d.endswith(".xcassets") and not d.endswith(".appiconset") and not d.endswith(".colorset")]
    for d in os.listdir(root):
        full = os.path.join(root, d)
        if d.endswith(".xcassets") and os.path.isdir(full) and full not in _seen_xcassets:
            _seen_xcassets.add(full)
            rel_path = os.path.relpath(full, root_dir)
            widget_xcassets_catalogs.append((d, rel_path))
    for f in sorted(files):
        if f.startswith("."):
            continue
        rel_path = os.path.relpath(os.path.join(root, f), root_dir)
        if f.endswith(".swift"):
            widget_swift_files.append((f, rel_path))
        elif f.endswith(".plist"):
            widget_resource_files.append((f, rel_path))

print(f"Main App: {len(swift_files)} Swift, {len(resource_files)} Resources, {len(xcassets_catalogs)} Assets")
print(f"Widget: {len(widget_swift_files)} Swift, {len(widget_xcassets_catalogs)} Assets")

# IDs
proj_id = uid()
main_group_id = uid()
products_group_id = uid()

# Main App Target IDs
product_id = uid()
target_id = uid()
sources_build_phase_id = uid()
resources_build_phase_id = uid()
frameworks_build_phase_id = uid()
embed_extensions_phase_id = uid()
debug_config_id = uid()
release_config_id = uid()
config_list_target_id = uid()

# Widget Target IDs
widget_product_id = uid()
widget_target_id = uid()
widget_sources_build_phase_id = uid()
widget_resources_build_phase_id = uid()
widget_frameworks_build_phase_id = uid()
widget_debug_config_id = uid()
widget_release_config_id = uid()
widget_config_list_target_id = uid()
widget_container_proxy_id = uid()
widget_target_dependency_id = uid()
appex_build_file_id = uid()

# Project Config IDs
proj_debug_config_id = uid()
proj_release_config_id = uid()
config_list_proj_id = uid()

file_refs = []
build_files = []
groups_dict = {}

# Main App Files
for name, rel_path in swift_files:
    f_ref = uid()
    b_file = uid()
    file_refs.append((f_ref, name, rel_path, "sourcecode.swift"))
    build_files.append((b_file, f_ref, "Sources", "MoneyCity"))
    parent_rel = os.path.dirname(rel_path)
    if parent_rel not in groups_dict:
        groups_dict[parent_rel] = (uid(), os.path.basename(parent_rel), [])
    groups_dict[parent_rel][2].append(f_ref)

for name, rel_path in resource_files:
    f_ref = uid()
    b_file = uid()
    ftype = "text.html" if name.endswith(".html") else ("sourcecode.javascript" if name.endswith(".js") else "file")
    file_refs.append((f_ref, name, rel_path, ftype))
    build_files.append((b_file, f_ref, "Resources", "MoneyCity"))
    parent_rel = os.path.dirname(rel_path)
    if parent_rel not in groups_dict:
        groups_dict[parent_rel] = (uid(), os.path.basename(parent_rel), [])
    groups_dict[parent_rel][2].append(f_ref)

for name, rel_path in xcassets_catalogs:
    f_ref = uid()
    b_file = uid()
    file_refs.append((f_ref, name, rel_path, "wrapper.asset-catalog"))
    build_files.append((b_file, f_ref, "Resources", "MoneyCity"))
    parent_rel = os.path.dirname(rel_path)
    if parent_rel not in groups_dict:
        groups_dict[parent_rel] = (uid(), os.path.basename(parent_rel), [])
    groups_dict[parent_rel][2].append(f_ref)

for name, rel_path in xcprivacy_files:
    f_ref = uid()
    b_file = uid()
    file_refs.append((f_ref, name, rel_path, "text.xml"))
    build_files.append((b_file, f_ref, "Resources", "MoneyCity"))
    parent_rel = os.path.dirname(rel_path)
    if parent_rel not in groups_dict:
        groups_dict[parent_rel] = (uid(), os.path.basename(parent_rel), [])
    groups_dict[parent_rel][2].append(f_ref)

# Widget Files
for name, rel_path in widget_swift_files:
    f_ref = uid()
    b_file = uid()
    file_refs.append((f_ref, name, rel_path, "sourcecode.swift"))
    build_files.append((b_file, f_ref, "WidgetSources", "spent fastExtension"))
    parent_rel = os.path.dirname(rel_path)
    if parent_rel not in groups_dict:
        groups_dict[parent_rel] = (uid(), os.path.basename(parent_rel), [])
    groups_dict[parent_rel][2].append(f_ref)

for name, rel_path in widget_xcassets_catalogs:
    f_ref = uid()
    b_file = uid()
    file_refs.append((f_ref, name, rel_path, "wrapper.asset-catalog"))
    build_files.append((b_file, f_ref, "WidgetResources", "spent fastExtension"))
    parent_rel = os.path.dirname(rel_path)
    if parent_rel not in groups_dict:
        groups_dict[parent_rel] = (uid(), os.path.basename(parent_rel), [])
    groups_dict[parent_rel][2].append(f_ref)

# Build PBXProj
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
pbx.append(f"\t\t{appex_build_file_id} /* spent fastExtension.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {widget_product_id} /* spent fastExtension.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
for b_file, f_ref, ptype, tgt in build_files:
    pbx.append(f"\t\t{b_file} /* {ptype} in {tgt} */ = {{isa = PBXBuildFile; fileRef = {f_ref}; }};")
pbx.append("/* End PBXBuildFile section */")

# PBXContainerItemProxy
pbx.append("\n/* Begin PBXContainerItemProxy section */")
pbx.append(f"\t\t{widget_container_proxy_id} /* PBXContainerItemProxy */ = {{")
pbx.append("\t\t\tisa = PBXContainerItemProxy;")
pbx.append(f"\t\t\tcontainerPortal = {proj_id} /* Project object */;")
pbx.append("\t\t\tproxyType = 1;")
pbx.append(f"\t\t\tremoteGlobalIDString = {widget_target_id};")
pbx.append("\t\t\tremoteInfo = \"spent fastExtension\";")
pbx.append("\t\t};")
pbx.append("/* End PBXContainerItemProxy section */")

# PBXCopyFilesBuildPhase
pbx.append("\n/* Begin PBXCopyFilesBuildPhase section */")
pbx.append(f"\t\t{embed_extensions_phase_id} /* Embed Foundation Extensions */ = {{")
pbx.append("\t\t\tisa = PBXCopyFilesBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tdstPath = \"\";")
pbx.append("\t\t\tdstSubfolderSpec = 13;")
pbx.append("\t\t\tfiles = (")
pbx.append(f"\t\t\t\t{appex_build_file_id} /* spent fastExtension.appex in Embed Foundation Extensions */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tname = \"Embed Foundation Extensions\";")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")
pbx.append("/* End PBXCopyFilesBuildPhase section */")

# PBXFileReference
pbx.append("\n/* Begin PBXFileReference section */")
pbx.append(f"\t\t{product_id} /* {project_name}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {project_name}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
pbx.append(f"\t\t{widget_product_id} /* spent fastExtension.appex */ = {{isa = PBXFileReference; explicitFileType = wrapper.app-extension; includeInIndex = 0; path = \"spent fastExtension.appex\"; sourceTree = BUILT_PRODUCTS_DIR; }};")
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
pbx.append(f"\t\t{widget_frameworks_build_phase_id} /* Frameworks */ = {{")
pbx.append("\t\t\tisa = PBXFrameworksBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")
pbx.append("/* End PBXFrameworksBuildPhase section */")

# PBXGroup
pbx.append("\n/* Begin PBXGroup section */")
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
pbx.append(f"\t\t\t\t{widget_product_id} /* spent fastExtension.appex */,")
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
pbx.append(f"\t\t\t\t{embed_extensions_phase_id} /* Embed Foundation Extensions */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tbuildRules = (")
pbx.append("\t\t\t);")
pbx.append("\t\t\tdependencies = (")
pbx.append(f"\t\t\t\t{widget_target_dependency_id} /* PBXTargetDependency */,")
pbx.append("\t\t\t);")
pbx.append(f"\t\t\tname = {project_name};")
pbx.append(f"\t\t\tproductName = {project_name};")
pbx.append(f"\t\t\tproductReference = {product_id} /* {project_name}.app */;")
pbx.append("\t\t\tproductType = \"com.apple.product-type.application\";")
pbx.append("\t\t};")

pbx.append(f"\t\t{widget_target_id} /* spent fastExtension */ = {{")
pbx.append("\t\t\tisa = PBXNativeTarget;")
pbx.append(f"\t\t\tbuildConfigurationList = {widget_config_list_target_id} /* Build configuration list for PBXNativeTarget \"spent fastExtension\" */;")
pbx.append("\t\t\tbuildPhases = (")
pbx.append(f"\t\t\t\t{widget_sources_build_phase_id} /* Sources */,")
pbx.append(f"\t\t\t\t{widget_frameworks_build_phase_id} /* Frameworks */,")
pbx.append(f"\t\t\t\t{widget_resources_build_phase_id} /* Resources */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tbuildRules = (")
pbx.append("\t\t\t);")
pbx.append("\t\t\tdependencies = (")
pbx.append("\t\t\t);")
pbx.append("\t\t\tname = \"spent fastExtension\";")
pbx.append("\t\t\tproductName = \"spent fastExtension\";")
pbx.append(f"\t\t\tproductReference = {widget_product_id} /* spent fastExtension.appex */;")
pbx.append("\t\t\tproductType = \"com.apple.product-type.app-extension\";")
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
pbx.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
pbx.append("\t\t\t\t\t};")
pbx.append(f"\t\t\t\t\t{widget_target_id} = {{")
pbx.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
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
pbx.append(f"\t\t\t\t{widget_target_id} /* spent fastExtension */,")
pbx.append("\t\t\t);")
pbx.append("\t\t};")
pbx.append("/* End PBXProject section */")

# PBXResourcesBuildPhase
pbx.append("\n/* Begin PBXResourcesBuildPhase section */")
pbx.append(f"\t\t{resources_build_phase_id} /* Resources */ = {{")
pbx.append("\t\t\tisa = PBXResourcesBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
for b_file, _, ptype, tgt in build_files:
    if ptype == "Resources" and tgt == "MoneyCity":
        pbx.append(f"\t\t\t\t{b_file} /* {ptype} */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")

pbx.append(f"\t\t{widget_resources_build_phase_id} /* Resources */ = {{")
pbx.append("\t\t\tisa = PBXResourcesBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
for b_file, _, ptype, tgt in build_files:
    if ptype == "WidgetResources" and tgt == "spent fastExtension":
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
for b_file, _, ptype, tgt in build_files:
    if ptype == "Sources" and tgt == "MoneyCity":
        pbx.append(f"\t\t\t\t{b_file} /* {ptype} */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")

pbx.append(f"\t\t{widget_sources_build_phase_id} /* Sources */ = {{")
pbx.append("\t\t\tisa = PBXSourcesBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
for b_file, _, ptype, tgt in build_files:
    if ptype == "WidgetSources" and tgt == "spent fastExtension":
        pbx.append(f"\t\t\t\t{b_file} /* {ptype} */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")
pbx.append("/* End PBXSourcesBuildPhase section */")

# PBXTargetDependency
pbx.append("\n/* Begin PBXTargetDependency section */")
pbx.append(f"\t\t{widget_target_dependency_id} /* PBXTargetDependency */ = {{")
pbx.append("\t\t\tisa = PBXTargetDependency;")
pbx.append(f"\t\t\ttarget = {widget_target_id} /* spent fastExtension */;")
pbx.append(f"\t\t\ttargetProxy = {widget_container_proxy_id} /* PBXContainerItemProxy */;")
pbx.append("\t\t};")
pbx.append("/* End PBXTargetDependency section */")

# XCBuildConfiguration
pbx.append("\n/* Begin XCBuildConfiguration section */")
pbx.append(f"\t\t{proj_debug_config_id} /* Debug */ = {{")
pbx.append("\t\t\tisa = XCBuildConfiguration;")
pbx.append("\t\t\tbuildSettings = {")
pbx.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;");
pbx.append("				APP_SHORTCUTS_ENABLE_FLEXIBLE_MATCHING = NO;")
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
pbx.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;");
pbx.append("				APP_SHORTCUTS_ENABLE_FLEXIBLE_MATCHING = NO;")
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

# Target build configs (Main App)
pbx.append(f"\t\t{debug_config_id} /* Debug */ = {{")
pbx.append("\t\t\tisa = XCBuildConfiguration;")
pbx.append("\t\t\tbuildSettings = {")
pbx.append("\t\t\t\tAPP_SHORTCUTS_ENABLE_FLEXIBLE_MATCHING = NO;");
pbx.append("				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
pbx.append("\t\t\t\tAPP_SHORTCUTS_ENABLE_FLEXIBLE_MATCHING = NO;");
pbx.append("				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
pbx.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
pbx.append("\t\t\t\tCODE_SIGN_IDENTITY = \"Apple Development\";")
pbx.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
pbx.append("\t\t\t\tDEVELOPMENT_TEAM = GGPYC8B9YV;")
pbx.append("\t\t\t\tENABLE_PREVIEWS = YES;")
pbx.append("\t\t\t\tENABLE_DEBUG_DYLIB = YES;")
pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
pbx.append(f"\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"SPENT\";")
pbx.append("\t\t\t\tINFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;")
pbx.append("\t\t\t\tINFOPLIST_KEY_LSRequiresIPhoneOS = YES;")
pbx.append("\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;")
pbx.append("\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;")
pbx.append(f"\t\t\t\tINFOPLIST_KEY_CFBundleURLTypes = \"{{\\n    CFBundleURLName = \\\"{bundle_id}\\\";\\n    CFBundleURLSchemes =     (\\n        spentapp,\\n        moneycity\\n    );\\n}}\";")
pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
pbx.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
pbx.append("\t\t\t\t\t\"$(inherited)\",")
pbx.append("\t\t\t\t\t\"@executable_path/Frameworks\",")
pbx.append("\t\t\t\t);")
pbx.append("\t\t\t\tMARKETING_VERSION = 1.0;")
pbx.append(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {bundle_id};")
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
pbx.append("\t\t\t\tAPP_SHORTCUTS_ENABLE_FLEXIBLE_MATCHING = NO;");
pbx.append("				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
pbx.append("\t\t\t\tAPP_SHORTCUTS_ENABLE_FLEXIBLE_MATCHING = NO;");
pbx.append("				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
pbx.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
pbx.append("\t\t\t\tCODE_SIGN_IDENTITY = \"Apple Development\";")
pbx.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
pbx.append("\t\t\t\tDEVELOPMENT_TEAM = GGPYC8B9YV;")
pbx.append("\t\t\t\tENABLE_PREVIEWS = YES;")
pbx.append("\t\t\t\tENABLE_DEBUG_DYLIB = YES;")
pbx.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
pbx.append(f"\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"SPENT\";")
pbx.append("\t\t\t\tINFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;")
pbx.append("\t\t\t\tINFOPLIST_KEY_LSRequiresIPhoneOS = YES;")
pbx.append("\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;")
pbx.append("\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;")
pbx.append(f"\t\t\t\tINFOPLIST_KEY_CFBundleURLTypes = \"{{\\n    CFBundleURLName = \\\"{bundle_id}\\\";\\n    CFBundleURLSchemes =     (\\n        spentapp,\\n        moneycity\\n    );\\n}}\";")
pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
pbx.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
pbx.append("\t\t\t\t\t\"$(inherited)\",")
pbx.append("\t\t\t\t\t\"@executable_path/Frameworks\",")
pbx.append("\t\t\t\t);")
pbx.append("\t\t\t\tMARKETING_VERSION = 1.0;")
pbx.append(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {bundle_id};")
pbx.append(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
pbx.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
pbx.append("\t\t\t\tSWIFT_VERSION = 5.0;")
pbx.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1\";")
pbx.append("\t\t\t};")
pbx.append(f"\t\t\tname = Release;")
pbx.append("\t\t};")

# Target build configs (Widget Extension)
pbx.append(f"\t\t{widget_debug_config_id} /* Debug */ = {{")
pbx.append("\t\t\tisa = XCBuildConfiguration;")
pbx.append("\t\t\tbuildSettings = {")
pbx.append("\t\t\t\tAPP_SHORTCUTS_ENABLE_FLEXIBLE_MATCHING = NO;");
pbx.append("				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
pbx.append("\t\t\t\tASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground;")
pbx.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
pbx.append("\t\t\t\tCODE_SIGN_IDENTITY = \"Apple Development\";")
pbx.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
pbx.append("\t\t\t\tDEVELOPMENT_TEAM = GGPYC8B9YV;")
pbx.append("\t\t\t\tENABLE_PREVIEWS = YES;")
pbx.append("\t\t\t\tENABLE_DEBUG_DYLIB = YES;")
pbx.append("				APPINTENTS_METADATAPROCESSOR_ENABLED = NO;");
pbx.append("				GENERATE_INFOPLIST_FILE = NO;");
pbx.append("				INFOPLIST_FILE = \"spent fast/Info.plist\";");
pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
pbx.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
pbx.append("\t\t\t\t\t\"$(inherited)\",")
pbx.append("\t\t\t\t\t\"@executable_path/Frameworks\",")
pbx.append("\t\t\t\t\t\"@executable_path/../../Frameworks\",")
pbx.append("\t\t\t\t);")
pbx.append("\t\t\t\tMARKETING_VERSION = 1.0;")
pbx.append(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"{widget_bundle_id}\";")
pbx.append(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
pbx.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
pbx.append("\t\t\t\tSWIFT_VERSION = 5.0;")
pbx.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1\";")
pbx.append("\t\t\t};")
pbx.append(f"\t\t\tname = Debug;")
pbx.append("\t\t};")

pbx.append(f"\t\t{widget_release_config_id} /* Release */ = {{")
pbx.append("\t\t\tisa = XCBuildConfiguration;")
pbx.append("\t\t\tbuildSettings = {")
pbx.append("\t\t\t\tAPP_SHORTCUTS_ENABLE_FLEXIBLE_MATCHING = NO;");
pbx.append("				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
pbx.append("\t\t\t\tASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground;")
pbx.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
pbx.append("\t\t\t\tCODE_SIGN_IDENTITY = \"Apple Development\";")
pbx.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
pbx.append("\t\t\t\tDEVELOPMENT_TEAM = GGPYC8B9YV;")
pbx.append("\t\t\t\tENABLE_PREVIEWS = YES;")
pbx.append("\t\t\t\tENABLE_DEBUG_DYLIB = YES;")
pbx.append("				APPINTENTS_METADATAPROCESSOR_ENABLED = NO;");
pbx.append("				GENERATE_INFOPLIST_FILE = NO;");
pbx.append("				INFOPLIST_FILE = \"spent fast/Info.plist\";");
pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
pbx.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
pbx.append("\t\t\t\t\t\"$(inherited)\",")
pbx.append("\t\t\t\t\t\"@executable_path/Frameworks\",")
pbx.append("\t\t\t\t\t\"@executable_path/../../Frameworks\",")
pbx.append("\t\t\t\t);")
pbx.append("\t\t\t\tMARKETING_VERSION = 1.0;")
pbx.append(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"{widget_bundle_id}\";")
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

pbx.append(f"\t\t{widget_config_list_target_id} /* Build configuration list for PBXNativeTarget \"spent fastExtension\" */ = {{")
pbx.append("\t\t\tisa = XCConfigurationList;")
pbx.append("\t\t\tbuildConfigurations = (")
pbx.append(f"\t\t\t\t{widget_debug_config_id} /* Debug */,")
pbx.append(f"\t\t\t\t{widget_release_config_id} /* Release */,")
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


# Generate Shared Schemes
schemes_dir = os.path.join(proj_dir, "xcshareddata", "xcschemes")
os.makedirs(schemes_dir, exist_ok=True)

moneycity_scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      buildArchitectures = "Automatic">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_id}"
               BuildableName = "{project_name}.app"
               BlueprintName = "{project_name}"
               ReferencedContainer = "container:{project_name}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{project_name}.app"
            BlueprintName = "{project_name}"
            ReferencedContainer = "container:{project_name}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{project_name}.app"
            BlueprintName = "{project_name}"
            ReferencedContainer = "container:{project_name}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""

with open(os.path.join(schemes_dir, f"{project_name}.xcscheme"), "w", encoding="utf-8") as f:
    f.write(moneycity_scheme)

print(f"Generated scheme {project_name}.xcscheme")

print(f"Successfully generated {pbx_path} with 2 targets (Main App + Widget Extension)!")
