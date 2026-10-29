#!/usr/bin/env python3
"""
Regenerates SmartCalculator.xcodeproj/project.pbxproj from the files on disk.

You normally do NOT need this: the project file is already included. Run it only if you add or
remove Swift files outside Xcode and want the project to pick them up:

    python3 tools/generate_xcodeproj.py

(Inside Xcode, adding files through File > Add Files / New File updates the project for you.)
"""
import hashlib
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_DIR = "SmartCalculator"
TEST_DIR = "SmartCalculatorTests"
PROJECT = "SmartCalculator.xcodeproj"
BUNDLE_ID = "com.example.SmartCalculator"
DEPLOYMENT_TARGET = "16.0"


def oid(key):
    return hashlib.md5(key.encode()).hexdigest()[:24].upper()


def swift_files(directory):
    found = []
    for base, _, files in os.walk(os.path.join(ROOT, directory)):
        for name in files:
            if name.endswith(".swift"):
                rel = os.path.relpath(os.path.join(base, name), ROOT)
                found.append(rel.replace(os.sep, "/"))
    return sorted(found)


def q(value):
    """Quote a pbxproj string when needed."""
    safe = all(c.isalnum() or c in "._/" for c in value) and value != ""
    return value if safe else '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'


class Group:
    def __init__(self, name, path):
        self.name, self.path = name, path
        self.children = []   # Group or file refs (strings of paths)
        self.id = oid("group:" + path)


def build_tree(directory, files, extra=()):
    root = Group(directory, directory)
    groups = {directory: root}
    for rel in list(files) + list(extra):
        parts = rel.split("/")
        parent = root
        for i in range(1, len(parts) - 1):
            key = "/".join(parts[: i + 1])
            if key not in groups:
                g = Group(parts[i], key)
                groups[key] = g
                parent.children.append(g)
            parent = groups[key]
        parent.children.append(rel)
    return root


def main():
    app_swift = swift_files(APP_DIR)
    test_swift = swift_files(TEST_DIR)
    extras = [f"{APP_DIR}/Assets.xcassets", f"{APP_DIR}/Info.plist"]

    app_tree = build_tree(APP_DIR, app_swift, extras)
    test_tree = build_tree(TEST_DIR, test_swift)

    objects = []          # list of (id, comment, body)
    def add(i, comment, body):
        objects.append((i, comment, body))

    def file_type(path):
        if path.endswith(".swift"): return "sourcecode.swift"
        if path.endswith(".xcassets"): return "folder.assetcatalog"
        if path.endswith(".plist"): return "text.plist.xml"
        return "text"

    file_ids, build_ids = {}, {}
    def file_ref(path, tag):
        fid = oid("file:" + path)
        file_ids[path] = fid
        name = os.path.basename(path)
        add(fid, name, f"isa = PBXFileReference; lastKnownFileType = {file_type(path)}; path = {q(name)}; sourceTree = \"<group>\";")
        return fid

    sources_app, sources_test, resources_app = [], [], []

    def emit_group(group, tag):
        child_ids = []
        for child in sorted(group.children, key=lambda c: (isinstance(c, str), c.name if isinstance(c, Group) else c)):
            if isinstance(child, Group):
                child_ids.append((child.id, child.name))
                emit_group(child, tag)
            else:
                fid = file_ref(child, tag)
                child_ids.append((fid, os.path.basename(child)))
                if child.endswith(".swift"):
                    bid = oid("build:" + child)
                    build_ids[child] = bid
                    add(bid, f"{os.path.basename(child)} in Sources",
                        f"isa = PBXBuildFile; fileRef = {fid} /* {os.path.basename(child)} */;")
                    (sources_app if tag == "app" else sources_test).append((bid, os.path.basename(child)))
                elif child.endswith(".xcassets"):
                    bid = oid("build:" + child)
                    add(bid, "Assets.xcassets in Resources",
                        f"isa = PBXBuildFile; fileRef = {fid} /* Assets.xcassets */;")
                    resources_app.append((bid, "Assets.xcassets"))
        children = "".join(f"\n\t\t\t\t{i} /* {n} */," for i, n in child_ids)
        name_line = "" if group.path == group.name and "/" not in group.path else ""
        add(group.id, group.name,
            f"isa = PBXGroup; children = ({children}\n\t\t\t); path = {q(os.path.basename(group.path))}; sourceTree = \"<group>\";")

    emit_group(app_tree, "app")
    emit_group(test_tree, "test")

    app_product = oid("product:app")
    test_product = oid("product:test")
    add(app_product, "SmartCalculator.app",
        'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SmartCalculator.app; sourceTree = BUILT_PRODUCTS_DIR;')
    add(test_product, "SmartCalculatorTests.xctest",
        'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = SmartCalculatorTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')

    products = oid("group:products")
    add(products, "Products",
        f"isa = PBXGroup; children = (\n\t\t\t\t{app_product} /* SmartCalculator.app */,\n\t\t\t\t{test_product} /* SmartCalculatorTests.xctest */,\n\t\t\t); name = Products; sourceTree = \"<group>\";")
    main_group = oid("group:main")
    add(main_group, "",
        f"isa = PBXGroup; children = (\n\t\t\t\t{app_tree.id} /* SmartCalculator */,\n\t\t\t\t{test_tree.id} /* SmartCalculatorTests */,\n\t\t\t\t{products} /* Products */,\n\t\t\t); sourceTree = \"<group>\";")

    # Build phases
    app_sources, app_frameworks, app_resources = oid("phase:app:src"), oid("phase:app:fw"), oid("phase:app:res")
    test_sources, test_frameworks, test_resources = oid("phase:test:src"), oid("phase:test:fw"), oid("phase:test:res")

    def phase(i, isa, comment, files):
        listing = "".join(f"\n\t\t\t\t{b} /* {n} in {comment} */," for b, n in files)
        add(i, comment, f"isa = {isa}; buildActionMask = 2147483647; files = ({listing}\n\t\t\t); runOnlyForDeploymentPostprocessing = 0;")

    phase(app_sources, "PBXSourcesBuildPhase", "Sources", sources_app)
    phase(app_frameworks, "PBXFrameworksBuildPhase", "Frameworks", [])
    phase(app_resources, "PBXResourcesBuildPhase", "Resources", resources_app)
    phase(test_sources, "PBXSourcesBuildPhase", "Sources", sources_test)
    phase(test_frameworks, "PBXFrameworksBuildPhase", "Frameworks", [])
    phase(test_resources, "PBXResourcesBuildPhase", "Resources", [])

    # Configurations
    def settings(d):
        lines = []
        for k in sorted(d):
            v = d[k]
            if isinstance(v, list):
                inner = "".join(f"\n\t\t\t\t\t{q(x)}," for x in v)
                lines.append(f"\t\t\t\t{k} = ({inner}\n\t\t\t\t);")
            else:
                lines.append(f"\t\t\t\t{k} = {q(str(v))};")
        return "\n".join(lines)

    project_common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": "5.0",
    }
    proj_debug = dict(project_common, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    })
    proj_release = dict(project_common, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_NS_ASSERTIONS": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": "-O",
        "VALIDATE_PRODUCT": "YES",
    })
    app_common = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_FILE": f"{APP_DIR}/Info.plist",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1",
    }
    test_common = {
        "BUNDLE_LOADER": "$(TEST_HOST)",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID + "Tests",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_EMIT_LOC_STRINGS": "NO",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1",
        "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/SmartCalculator.app/SmartCalculator",
    }

    def config(key, name, d):
        i = oid("config:" + key + name)
        add(i, name, f"isa = XCBuildConfiguration; buildSettings = {{\n{settings(d)}\n\t\t\t}}; name = {name};")
        return i

    def config_list(key, comment, dbg, rel):
        i = oid("configlist:" + key)
        add(i, comment,
            f"isa = XCConfigurationList; buildConfigurations = (\n\t\t\t\t{dbg} /* Debug */,\n\t\t\t\t{rel} /* Release */,\n\t\t\t); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
        return i

    proj_list = config_list("project", 'Build configuration list for PBXProject "SmartCalculator"',
                            config("project", "Debug", proj_debug), config("project", "Release", proj_release))
    app_list = config_list("app", 'Build configuration list for PBXNativeTarget "SmartCalculator"',
                           config("app", "Debug", app_common), config("app", "Release", app_common))
    test_list = config_list("test", 'Build configuration list for PBXNativeTarget "SmartCalculatorTests"',
                            config("test", "Debug", test_common), config("test", "Release", test_common))

    app_target, test_target, project = oid("target:app"), oid("target:test"), oid("project")
    add(app_target, "SmartCalculator",
        f"isa = PBXNativeTarget; buildConfigurationList = {app_list} /* Build configuration list for PBXNativeTarget \"SmartCalculator\" */; buildPhases = (\n\t\t\t\t{app_sources} /* Sources */,\n\t\t\t\t{app_frameworks} /* Frameworks */,\n\t\t\t\t{app_resources} /* Resources */,\n\t\t\t); buildRules = (\n\t\t\t); dependencies = (\n\t\t\t); name = SmartCalculator; productName = SmartCalculator; productReference = {app_product} /* SmartCalculator.app */; productType = \"com.apple.product-type.application\";")

    proxy, dep = oid("proxy"), oid("dependency")
    add(proxy, "PBXContainerItemProxy",
        f"isa = PBXContainerItemProxy; containerPortal = {project} /* Project object */; proxyType = 1; remoteGlobalIDString = {app_target}; remoteInfo = SmartCalculator;")
    add(dep, "PBXTargetDependency",
        f"isa = PBXTargetDependency; target = {app_target} /* SmartCalculator */; targetProxy = {proxy} /* PBXContainerItemProxy */;")
    add(test_target, "SmartCalculatorTests",
        f"isa = PBXNativeTarget; buildConfigurationList = {test_list} /* Build configuration list for PBXNativeTarget \"SmartCalculatorTests\" */; buildPhases = (\n\t\t\t\t{test_sources} /* Sources */,\n\t\t\t\t{test_frameworks} /* Frameworks */,\n\t\t\t\t{test_resources} /* Resources */,\n\t\t\t); buildRules = (\n\t\t\t); dependencies = (\n\t\t\t\t{dep} /* PBXTargetDependency */,\n\t\t\t); name = SmartCalculatorTests; productName = SmartCalculatorTests; productReference = {test_product} /* SmartCalculatorTests.xctest */; productType = \"com.apple.product-type.bundle.unit-test\";")

    add(project, "Project object",
        f"isa = PBXProject; attributes = {{\n\t\t\t\tBuildIndependentTargetsInParallel = 1;\n\t\t\t\tLastSwiftUpdateCheck = 1500;\n\t\t\t\tLastUpgradeCheck = 1500;\n\t\t\t\tTargetAttributes = {{\n\t\t\t\t\t{app_target} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n\t\t\t\t\t}};\n\t\t\t\t\t{test_target} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n\t\t\t\t\t\tTestTargetID = {app_target};\n\t\t\t\t\t}};\n\t\t\t\t}};\n\t\t\t}}; buildConfigurationList = {proj_list} /* Build configuration list for PBXProject \"SmartCalculator\" */; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t); mainGroup = {main_group}; productRefGroup = {products} /* Products */; projectDirPath = \"\"; projectRoot = \"\"; targets = (\n\t\t\t\t{app_target} /* SmartCalculator */,\n\t\t\t\t{test_target} /* SmartCalculatorTests */,\n\t\t\t);")

    # Serialise grouped by isa, as Xcode does
    def isa_of(body):
        return body.split("isa = ")[1].split(";")[0]
    order = ["PBXBuildFile", "PBXContainerItemProxy", "PBXFileReference", "PBXFrameworksBuildPhase",
             "PBXGroup", "PBXNativeTarget", "PBXProject", "PBXResourcesBuildPhase", "PBXSourcesBuildPhase",
             "PBXTargetDependency", "XCBuildConfiguration", "XCConfigurationList"]
    out = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};", "\tobjectVersion = 56;", "\tobjects = {", ""]
    for isa in order:
        items = [o for o in objects if isa_of(o[2]) == isa]
        if not items:
            continue
        out.append(f"/* Begin {isa} section */")
        for i, comment, body in sorted(items, key=lambda o: o[0]):
            label = f" /* {comment} */" if comment else ""
            if isa in ("PBXBuildFile", "PBXFileReference"):
                out.append(f"\t\t{i}{label} = {{{body}}};")
            else:
                out.append(f"\t\t{i}{label} = {{\n\t\t\t{body}\n\t\t}};")
        out.append(f"/* End {isa} section */\n")
    out += ["\t};", f"\trootObject = {project} /* Project object */;", "}", ""]

    proj_dir = os.path.join(ROOT, PROJECT)
    os.makedirs(os.path.join(proj_dir, "xcshareddata", "xcschemes"), exist_ok=True)
    with open(os.path.join(proj_dir, "project.pbxproj"), "w") as f:
        f.write("\n".join(out))

    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1500" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{app_target}" BuildableName = "SmartCalculator.app" BlueprintName = "SmartCalculator" ReferencedContainer = "container:SmartCalculator.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{test_target}" BuildableName = "SmartCalculatorTests.xctest" BlueprintName = "SmartCalculatorTests" ReferencedContainer = "container:SmartCalculator.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{app_target}" BuildableName = "SmartCalculator.app" BlueprintName = "SmartCalculator" ReferencedContainer = "container:SmartCalculator.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{app_target}" BuildableName = "SmartCalculator.app" BlueprintName = "SmartCalculator" ReferencedContainer = "container:SmartCalculator.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
    with open(os.path.join(proj_dir, "xcshareddata", "xcschemes", "SmartCalculator.xcscheme"), "w") as f:
        f.write(scheme)
    print(f"Wrote {PROJECT}: {len(app_swift)} app sources, {len(test_swift)} test sources")


if __name__ == "__main__":
    main()
