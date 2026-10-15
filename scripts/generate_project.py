#!/usr/bin/env python3
"""Generate the dependency-free native Xcode application target deterministically."""
from pathlib import Path
import hashlib
ROOT = Path(__file__).resolve().parent.parent

def uid(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()

def main():
    paths = sorted(str(p.relative_to(ROOT)) for folder in ['Sources/MonitorKit', 'Sources/MyToolBox'] for p in (ROOT / folder).rglob('*.swift'))
    objects = []
    def obj(name, body):
        objects.append(f'{uid(name)} = {{ {body} }};')
        return uid(name)
    files, builds = [], []
    for path in paths:
        file = obj(path, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = SOURCE_ROOT;')
        files.append(file)
        builds.append(obj('build:'+path, f'isa = PBXBuildFile; fileRef = {file};'))
    manifest = obj('privacy', 'isa = PBXFileReference; lastKnownFileType = text.xml; path = Resources/PrivacyInfo.xcprivacy; sourceTree = SOURCE_ROOT;')
    manifest_build = obj('privacyBuild', f'isa = PBXBuildFile; fileRef = {manifest};')
    license_ref = obj('statsLicense', 'isa = PBXFileReference; lastKnownFileType = text; path = Resources/Stats-LICENSE.txt; sourceTree = SOURCE_ROOT;')
    license_build = obj('statsLicenseBuild', f'isa = PBXBuildFile; fileRef = {license_ref};')
    files.append(license_ref)
    icon_ref = obj('appIcon', 'isa = PBXFileReference; lastKnownFileType = image.icns; path = Resources/MyToolBox.icns; sourceTree = SOURCE_ROOT;')
    icon_build = obj('appIconBuild', f'isa = PBXBuildFile; fileRef = {icon_ref};')
    files.append(icon_ref)
    holiday_ref = obj('holidays', 'isa = PBXFileReference; lastKnownFileType = text.json; path = Resources/JapaneseHolidays.json; sourceTree = SOURCE_ROOT;')
    holiday_build = obj('holidaysBuild', f'isa = PBXBuildFile; fileRef = {holiday_ref};')
    files.append(holiday_ref)
    product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = MyToolBox.app; sourceTree = BUILT_PRODUCTS_DIR;')
    products = obj('products', f'isa = PBXGroup; name = Products; children = ({product},); sourceTree = "<group>";')
    group = obj('group', f'isa = PBXGroup; children = ({",".join(files + [manifest, products])},); sourceTree = "<group>";')
    sources = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
    resources = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({manifest_build},{license_build},{icon_build},{holiday_build},); runOnlyForDeploymentPostprocessing = 0;')
    configs = []
    for name in ['Debug', 'Release']:
        opt = '-Onone' if name == 'Debug' else '-O'
        configs.append(obj(name, f'''isa = XCBuildConfiguration; name = {name}; buildSettings = {{
            PRODUCT_NAME = MyToolBox; PRODUCT_BUNDLE_IDENTIFIER = local.MyToolBox;
            MACOSX_DEPLOYMENT_TARGET = 14.0; SDKROOT = macosx; ARCHS = arm64;
            ALWAYS_SEARCH_USER_PATHS = NO; SWIFT_VERSION = 5.0; SWIFT_OPTIMIZATION_LEVEL = "{opt}";
            GENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = Resources/Info.plist; INFOPLIST_KEY_LSUIElement = YES;
            INFOPLIST_KEY_CFBundleDisplayName = MyToolBox;
            CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 0.1.0;
            CODE_SIGN_ENTITLEMENTS = Resources/MyToolBox.entitlements; CODE_SIGN_IDENTITY = "-"; CODE_SIGN_STYLE = Manual;
            ENABLE_APP_SANDBOX = NO; ENABLE_HARDENED_RUNTIME = YES;
            OTHER_LDFLAGS = "$(inherited) -lsqlite3";
            LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";
        }};'''))
    configlist = obj('configlist', f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {configlist}; buildPhases = ({sources},{resources},); buildRules = (); dependencies = (); name = MyToolBox; productName = MyToolBox; productReference = {product}; productType = "com.apple.product-type.application";')
    project = obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; }}; buildConfigurationList = {configlist}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,ja); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
    directory = ROOT / 'MyToolBox.xcodeproj'; directory.mkdir(exist_ok=True)
    (directory / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {project}; }}\n')
    schemes = directory / 'xcshareddata/xcschemes'; schemes.mkdir(parents=True, exist_ok=True)
    ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="MyToolBox.app" BlueprintName="MyToolBox" ReferencedContainer="container:MyToolBox.xcodeproj"/>'
    (schemes / 'MyToolBox.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
if __name__ == '__main__': main()
