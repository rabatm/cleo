#!/usr/bin/env python3
"""Genere RunCatPlus.xcodeproj (pbxproj + scheme) pour les sources listées.

Reutilisable : ajoutez un fichier Swift a SOURCES puis relancez ce script.
"""
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.join(ROOT, "RunCatPlus.xcodeproj")
TARGET_NAME = "RunCatPlus"
BUNDLE_ID = "com.maretin.runcatplus"

SOURCES = [
    "RunCatPlus/main.swift",
    "RunCatPlus/RunCatPlusApp.swift",
    "RunCatPlus/StatusBarController.swift",
    "RunCatPlus/Providers/CPUProvider.swift",
    "RunCatPlus/Providers/MemoryProvider.swift",
    "RunCatPlus/Providers/QuotaProvider.swift",
    "RunCatPlus/Providers/ClaudeProvider.swift",
    "RunCatPlus/Providers/KimiProvider.swift",
    "RunCatPlus/Views/CatPainter.swift",
    "RunCatPlus/Views/CatSprite.swift",
    "RunCatPlus/Views/QuotaRingView.swift",
    "RunCatPlus/Views/MenuContentView.swift",
]

RESOURCES = sorted(
    os.path.join("RunCatPlus/CatFrames", f)
    for f in os.listdir(os.path.join(ROOT, "RunCatPlus/CatFrames"))
    if f.startswith("frame") and f.endswith(".png")
)

_counter = [0]
def uid():
    _counter[0] += 1
    return f"C{_counter[0]:023X}"

PROJECT_ID, TARGET_ID, PRODUCT_REF = uid(), uid(), uid()
MAIN_GROUP, APP_GROUP, PROVIDERS_GROUP, VIEWS_GROUP, CATFRAMES_GROUP = uid(), uid(), uid(), uid(), uid()
SRC_PHASE, FW_PHASE, RES_PHASE = uid(), uid(), uid()
PROJ_CONF_LIST, TGT_CONF_LIST = uid(), uid()
PROJ_DEBUG, PROJ_RELEASE, TGT_DEBUG, TGT_RELEASE = uid(), uid(), uid(), uid()

def group_of(path):
    if "/Providers/" in path:
        return PROVIDERS_GROUP
    if "/Views/" in path:
        return VIEWS_GROUP
    return None

FILE_REFS, BUILD_FILES, NAMES = {}, {}, {}
for s in SOURCES:
    FILE_REFS[s] = uid()
    BUILD_FILES[s] = uid()
    NAMES[FILE_REFS[s]] = os.path.basename(s)
RES_BUILD_FILES = {}
for r in RESOURCES:
    FILE_REFS[r] = uid()
    RES_BUILD_FILES[r] = uid()
    NAMES[FILE_REFS[r]] = os.path.basename(r)
NAMES[PRODUCT_REF] = f"{TARGET_NAME}.app"
NAMES[PROVIDERS_GROUP] = "Providers"
NAMES[VIEWS_GROUP] = "Views"
NAMES[CATFRAMES_GROUP] = "CatFrames"
NAMES[APP_GROUP] = TARGET_NAME

def build_settings(project, config):
    lines = [
        "ALWAYS_SEARCH_USER_PATHS = NO;",
        "CLANG_ANALYZER_NONNULL = YES;",
        "CLANG_ENABLE_MODULES = YES;",
        "CLANG_ENABLE_OBJC_ARC = YES;",
        "CLANG_WARN_BOOL_CONVERSION = YES;",
        "CLANG_WARN_CONSTANT_CONVERSION = YES;",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;",
        "CLANG_WARN_EMPTY_BODY = YES;",
        "CLANG_WARN_ENUM_CONVERSION = YES;",
        "CLANG_WARN_INFINITE_RECURSION = YES;",
        "CLANG_WARN_INT_CONVERSION = YES;",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;",
        "CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;",
        "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;",
        "CLANG_WARN_STRICT_PROTOTYPES = YES;",
        "CLANG_WARN_SUSPICIOUS_MOVE = YES;",
        "CLANG_WARN_UNREACHABLE_CODE = YES;",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;",
        "COPY_PHASE_STRIP = NO;",
        "ENABLE_STRICT_OBJC_MSGSEND = YES;",
        "GCC_C_LANGUAGE_STANDARD = gnu11;",
        "GCC_NO_COMMON_BLOCKS = YES;",
        "GCC_WARN_64_TO_32_BIT_CONVERSION = YES;",
        "GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;",
        "GCC_WARN_UNDECLARED_SELECTOR = YES;",
        "GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;",
        "GCC_WARN_UNUSED_FUNCTION = YES;",
        "GCC_WARN_UNUSED_VARIABLE = YES;",
        "MACOSX_DEPLOYMENT_TARGET = 14.0;",
        "SDKROOT = macosx;",
        "SWIFT_VERSION = 5.0;",
    ]
    if not project:
        lines += [
            'CODE_SIGN_IDENTITY = "-";',
            "CODE_SIGN_STYLE = Manual;",
            "COMBINE_HIDPI_IMAGES = YES;",
            "CURRENT_PROJECT_VERSION = 1;",
            'DEVELOPMENT_TEAM = "";',
            "GENERATE_INFOPLIST_FILE = YES;",
            "INFOPLIST_KEY_CFBundleDisplayName = RunCatPlus;",
            "INFOPLIST_KEY_LSUIElement = YES;",
            'INFOPLIST_KEY_NSHumanReadableCopyright = "Copyright 2026.";',
            'LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks");',
            "MARKETING_VERSION = 0.1;",
            f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};",
            'PRODUCT_NAME = "$(TARGET_NAME)";',
            'PROVISIONING_PROFILE_SPECIFIER = "";',
        ]
    if config == "Debug":
        lines += [
            "DEBUG_INFORMATION_FORMAT = dwarf;",
            "ENABLE_TESTABILITY = YES;",
            'GCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)");',
            "GCC_OPTIMIZATION_LEVEL = 0;",
            "MTL_ENABLE_DEBUG_INFO = YES;",
            'SWIFT_OPTIMIZATION_LEVEL = "-Onone";',
        ]
    else:
        lines += [
            'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";',
            "ENABLE_NS_ASSERTIONS = NO;",
            "MTL_ENABLE_DEBUG_INFO = NO;",
        ]
    return lines

def conf_block(obj_id, name, project):
    body = "\n".join(f"\t\t\t{s}" for s in build_settings(project, name))
    return (f"\t\t{obj_id} /* {name} */ = {{\n"
            f"\t\t\tisa = XCBuildConfiguration;\n"
            f"\t\t\tbuildSettings = {{\n{body}\n\t\t\t}};\n"
            f"\t\t\tname = {name};\n\t\t}};")

out = []
out.append("// !$*UTF8*$!")
out.append("{")
out.append("\tarchiveVersion = 1;")
out.append("\tclasses = {")
out.append("\t};")
out.append("\tobjectVersion = 56;")
out.append("\tobjects = {")

# ---- PBXBuildFile ----
out.append("\n/* Begin PBXBuildFile section */")
for s in SOURCES:
    b = os.path.basename(s)
    out.append(f"\t\t{BUILD_FILES[s]} /* {b} in Sources */ = {{isa = PBXBuildFile; fileRef = {FILE_REFS[s]} /* {b} */; }};")
for r in RESOURCES:
    b = os.path.basename(r)
    out.append(f"\t\t{RES_BUILD_FILES[r]} /* {b} in Resources */ = {{isa = PBXBuildFile; fileRef = {FILE_REFS[r]} /* {b} */; }};")
out.append("/* End PBXBuildFile section */")

# ---- PBXFileReference ----
out.append("\n/* Begin PBXFileReference section */")
out.append(f'\t\t{PRODUCT_REF} /* {TARGET_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {TARGET_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
for s in SOURCES:
    b = os.path.basename(s)
    out.append(f'\t\t{FILE_REFS[s]} /* {b} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{b}"; sourceTree = "<group>"; }};')
for r in RESOURCES:
    b = os.path.basename(r)
    out.append(f'\t\t{FILE_REFS[r]} /* {b} */ = {{isa = PBXFileReference; lastKnownFileType = image.png; path = "{b}"; sourceTree = "<group>"; }};')
out.append("/* End PBXFileReference section */")

# ---- PBXFrameworksBuildPhase ----
out.append("\n/* Begin PBXFrameworksBuildPhase section */")
out.append(f"\t\t{FW_PHASE} /* Frameworks */ = {{")
out.append("\t\t\tisa = PBXFrameworksBuildPhase;")
out.append("\t\t\tbuildActionMask = 2147483647;")
out.append("\t\t\tfiles = (")
out.append("\t\t\t);")
out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
out.append("\t\t};")
out.append("/* End PBXFrameworksBuildPhase section */")

# ---- PBXGroup ----
out.append("\n/* Begin PBXGroup section */")

def group_block(gid, children, path=None):
    lines = [f"\t\t{gid} = {{", "\t\t\tisa = PBXGroup;", "\t\t\tchildren = ("]
    for c in children:
        lines.append(f"\t\t\t\t{c} /* {NAMES[c]} */,")
    lines.append("\t\t\t);")
    if path:
        lines.append(f'\t\t\tpath = "{path}";')
    lines.append('\t\t\tsourceTree = "<group>";')
    lines.append("\t\t};")
    return "\n".join(lines)

provider_children = [FILE_REFS[s] for s in SOURCES if group_of(s) == PROVIDERS_GROUP]
view_children = [FILE_REFS[s] for s in SOURCES if group_of(s) == VIEWS_GROUP]
app_children = [FILE_REFS[s] for s in SOURCES if group_of(s) is None]
app_children += [PROVIDERS_GROUP, VIEWS_GROUP, CATFRAMES_GROUP]
main_children = [PRODUCT_REF, APP_GROUP]
catframes_children = [FILE_REFS[r] for r in RESOURCES]

out.append(group_block(PROVIDERS_GROUP, provider_children, "Providers"))
out.append(group_block(VIEWS_GROUP, view_children, "Views"))
out.append(group_block(CATFRAMES_GROUP, catframes_children, "CatFrames"))
out.append(group_block(APP_GROUP, app_children, TARGET_NAME))
out.append(group_block(MAIN_GROUP, main_children))
out.append("/* End PBXGroup section */")

# ---- PBXNativeTarget ----
out.append("\n/* Begin PBXNativeTarget section */")
out.append(f"\t\t{TARGET_ID} /* {TARGET_NAME} */ = {{")
out.append("\t\t\tisa = PBXNativeTarget;")
out.append("\t\t\tbuildConfigurationList = " + TGT_CONF_LIST + f" /* Build configuration list for PBXNativeTarget \"{TARGET_NAME}\" */;")
out.append("\t\t\tbuildPhases = (")
out.append(f"\t\t\t\t{SRC_PHASE} /* Sources */,")
out.append(f"\t\t\t\t{FW_PHASE} /* Frameworks */,")
out.append(f"\t\t\t\t{RES_PHASE} /* Resources */,")
out.append("\t\t\t);")
out.append("\t\t\tbuildRules = (")
out.append("\t\t\t);")
out.append("\t\t\tdependencies = (")
out.append("\t\t\t);")
out.append(f"\t\t\tname = {TARGET_NAME};")
out.append(f"\t\t\tproductName = {TARGET_NAME};")
out.append(f"\t\t\tproductReference = {PRODUCT_REF} /* {TARGET_NAME}.app */;")
out.append('\t\t\tproductType = "com.apple.product-type.application";')
out.append("\t\t};")
out.append("/* End PBXNativeTarget section */")

# ---- PBXProject ----
out.append("\n/* Begin PBXProject section */")
out.append(f"\t\t{PROJECT_ID} /* Project object */ = {{")
out.append("\t\t\tisa = PBXProject;")
out.append("\t\t\tattributes = {")
out.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
out.append("\t\t\t\tLastSwiftUpdateCheck = 1500;")
out.append("\t\t\t\tLastUpgradeCheck = 1500;")
out.append("\t\t\t\tTargetAttributes = {")
out.append(f"\t\t\t\t\t{TARGET_ID} = {{")
out.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
out.append("\t\t\t\t\t\tProvisioningStyle = Manual;")
out.append("\t\t\t\t\t};")
out.append("\t\t\t\t};")
out.append("\t\t\t};")
out.append(f"\t\t\tbuildConfigurationList = {PROJ_CONF_LIST} /* Build configuration list for PBXProject \"{TARGET_NAME}\" */;")
out.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
out.append("\t\t\tdevelopmentRegion = en;")
out.append("\t\t\thasScannedForEncodings = 0;")
out.append("\t\t\tknownRegions = (")
out.append("\t\t\t\ten,")
out.append("\t\t\t\tBase,")
out.append("\t\t\t);")
out.append(f"\t\t\tmainGroup = {MAIN_GROUP};")
out.append(f"\t\t\tproductRefGroup = {MAIN_GROUP};")
out.append('\t\t\tprojectDirPath = "";')
out.append('\t\t\tprojectRoot = "";')
out.append("\t\t\ttargets = (")
out.append(f"\t\t\t\t{TARGET_ID} /* {TARGET_NAME} */,")
out.append("\t\t\t);")
out.append("\t\t};")
out.append("/* End PBXProject section */")

# ---- PBXResourcesBuildPhase ----
out.append("\n/* Begin PBXResourcesBuildPhase section */")
out.append(f"\t\t{RES_PHASE} /* Resources */ = {{")
out.append("\t\t\tisa = PBXResourcesBuildPhase;")
out.append("\t\t\tbuildActionMask = 2147483647;")
out.append("\t\t\tfiles = (")
for r in RESOURCES:
    b = os.path.basename(r)
    out.append(f"\t\t\t\t{RES_BUILD_FILES[r]} /* {b} in Resources */,")
out.append("\t\t\t);")
out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
out.append("\t\t};")
out.append("/* End PBXResourcesBuildPhase section */")

# ---- PBXSourcesBuildPhase ----
out.append("\n/* Begin PBXSourcesBuildPhase section */")
out.append(f"\t\t{SRC_PHASE} /* Sources */ = {{")
out.append("\t\t\tisa = PBXSourcesBuildPhase;")
out.append("\t\t\tbuildActionMask = 2147483647;")
out.append("\t\t\tfiles = (")
for s in SOURCES:
    b = os.path.basename(s)
    out.append(f"\t\t\t\t{BUILD_FILES[s]} /* {b} in Sources */,")
out.append("\t\t\t);")
out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
out.append("\t\t};")
out.append("/* End PBXSourcesBuildPhase section */")

# ---- XCBuildConfiguration ----
out.append("\n/* Begin XCBuildConfiguration section */")
out.append(conf_block(PROJ_DEBUG, "Debug", True))
out.append(conf_block(PROJ_RELEASE, "Release", True))
out.append(conf_block(TGT_DEBUG, "Debug", False))
out.append(conf_block(TGT_RELEASE, "Release", False))
out.append("/* End XCBuildConfiguration section */")

# ---- XCConfigurationList ----
out.append("\n/* Begin XCConfigurationList section */")
out.append(f"\t\t{PROJ_CONF_LIST} /* Build configuration list for PBXProject \"{TARGET_NAME}\" */ = {{")
out.append("\t\t\tisa = XCConfigurationList;")
out.append("\t\t\tbuildConfigurations = (")
out.append(f"\t\t\t\t{PROJ_DEBUG} /* Debug */,")
out.append(f"\t\t\t\t{PROJ_RELEASE} /* Release */,")
out.append("\t\t\t);")
out.append("\t\t\tdefaultConfigurationIsVisible = 0;")
out.append("\t\t\tdefaultConfigurationName = Release;")
out.append("\t\t};")
out.append(f"\t\t{TGT_CONF_LIST} /* Build configuration list for PBXNativeTarget \"{TARGET_NAME}\" */ = {{")
out.append("\t\t\tisa = XCConfigurationList;")
out.append("\t\t\tbuildConfigurations = (")
out.append(f"\t\t\t\t{TGT_DEBUG} /* Debug */,")
out.append(f"\t\t\t\t{TGT_RELEASE} /* Release */,")
out.append("\t\t\t);")
out.append("\t\t\tdefaultConfigurationIsVisible = 0;")
out.append("\t\t\tdefaultConfigurationName = Release;")
out.append("\t\t};")
out.append("/* End XCConfigurationList section */")

out.append("\t};")
out.append(f'\trootObject = {PROJECT_ID} /* Project object */;')
out.append("}")

os.makedirs(PROJ, exist_ok=True)
os.makedirs(os.path.join(PROJ, "project.xcworkspace"), exist_ok=True)
os.makedirs(os.path.join(PROJ, "xcshareddata", "xcschemes"), exist_ok=True)

with open(os.path.join(PROJ, "project.pbxproj"), "w") as f:
    f.write("\n".join(out) + "\n")

with open(os.path.join(PROJ, "project.xcworkspace", "contents.xcworkspacedata"), "w") as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<Workspace version="1.0">\n'
            '   <FileRef location="self:">\n   </FileRef>\n'
            '</Workspace>\n')

scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES" buildArchitectures="Automatic">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{TARGET_ID}" BuildableName="{TARGET_NAME}.app" BlueprintName="{TARGET_NAME}" ReferencedContainer="container:RunCatPlus.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES" shouldAutocreateTestPlan="YES">
   </TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{TARGET_ID}" BuildableName="{TARGET_NAME}.app" BlueprintName="{TARGET_NAME}" ReferencedContainer="container:RunCatPlus.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{TARGET_ID}" BuildableName="{TARGET_NAME}.app" BlueprintName="{TARGET_NAME}" ReferencedContainer="container:RunCatPlus.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES">
   </ArchiveAction>
</Scheme>
'''
with open(os.path.join(PROJ, "xcshareddata", "xcschemes", f"{TARGET_NAME}.xcscheme"), "w") as f:
    f.write(scheme)

print("OK ->", PROJ)
