load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TelegramUniversalVideoContent",
    module_name = "TelegramUniversalVideoContent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/RadialStatusNode:RadialStatusNode",
        "//submodules/AppBundle:AppBundle",
        "//submodules/Utils/RangeSet:RangeSet",
        "//submodules/TelegramVoip",
        "//submodules/ManagedFile",
        ":FairyTurtle_Level_1",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "FairyTurtle_Level_1",
    module_name = "FairyTurtle_Level_1",
    srcs = glob([
        "FairyTurtle_Level_1/**/*.swift",
    ]),
    copts = [
    ],
    deps = [
        ":FairyTurtle_Level_2",
    ],
    visibility = [
        "//visibility:public",
    ],
)

objc_library(
    name = "FairyTurtle_Level_2",
    enable_modules = True,
    module_name = "FairyTurtle_Level_2",
    srcs = glob([
        "FairyTurtle_Level_2/Sources/**/*.m",
        "FairyTurtle_Level_2/Sources/**/*.mm",
        "FairyTurtle_Level_2/Sources/**/*.h",
        "FairyTurtle_Level_2/Sources/**/*.c",
        "FairyTurtle_Level_2/Sources/**/*.cpp",
    ]),
    copts = [],
    hdrs = glob([
        "FairyTurtle_Level_2/PublicHeaders/*.h",
    ]),
    includes = [
        "FairyTurtle_Level_2/PublicHeaders",
    ],
    deps = [
        ":FairyTurtle_Level_3",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "FairyTurtle_Level_3",
    module_name = "FairyTurtle_Level_3",
    srcs = glob([
        "FairyTurtle_Level_3/**/*.swift",
    ]),
    copts = [
    ],
    deps = [
    ],
    visibility = [
        "//visibility:public",
    ],
)
