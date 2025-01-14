"""Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//spa/private:toolchains_repo.bzl", "PLATFORMS", "toolchains_repo")
load("//spa/private:versions.bzl", "TOOL_VERSIONS")

# WARNING: any changes in this function may be BREAKING CHANGES for users
# because we'll fetch a dependency which may be different from one that
# they were previously fetching later in their WORKSPACE setup, and now
# ours took precedence. Such breakages are challenging for users, so any
# changes in this function should be marked as BREAKING in the commit message
# and released only in semver majors.
def rules_spa_dependencies():
    """A function exposed to the consumer to use so that they can install the rules we depend on"""

    # The minimal version of bazel_skylib we require
    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "c6966ec828da198c5d9adbaa94c05e3a1c7f21bd012a0b29ba8ddbccb2c93b0d",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
        ],
    )

    # The minimal version of rules_nodejs we need
    maybe(
        http_archive,
        name = "build_bazel_rules_nodejs",
        sha256 = "cfc289523cf1594598215901154a6c2515e8bf3671fd708264a6f6aefe02bf39",
        urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/4.4.6/rules_nodejs-4.4.6.tar.gz"],
    )

    # The minimal version of rules_swc that we need
    maybe(
        http_archive,
        name = "aspect_rules_swc",
        sha256 = "67d6020374627f60c6c1e5d5e1690fcdc4fa39952de8a727d3aabe265ca843be",
        strip_prefix = "rules_swc-0.1.0",
        url = "https://github.com/aspect-build/rules_swc/archive/v0.1.0.tar.gz",
    )

    # Rules Docker requirements
    maybe(
        # Rules Go is needed by Rules Docker
        http_archive,
        name = "io_bazel_rules_go",
        sha256 = "2b1641428dff9018f9e85c0384f03ec6c10660d935b750e3fa1492a281a53b0f",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.29.0/rules_go-v0.29.0.zip",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.29.0/rules_go-v0.29.0.zip",
        ],
    )
    maybe(
        http_archive,
        name = "bazel_gazelle",
        sha256 = "de69a09dc70417580aabf20a28619bb3ef60d038470c7cf8442fafcf627c21cb",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.24.0/bazel-gazelle-v0.24.0.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.24.0/bazel-gazelle-v0.24.0.tar.gz",
        ],
    )
    maybe(
        http_archive,
        name = "io_bazel_rules_docker",
        sha256 = "92779d3445e7bdc79b961030b996cb0c91820ade7ffa7edca69273f404b085d5",
        strip_prefix = "rules_docker-0.20.0",
        urls = ["https://github.com/bazelbuild/rules_docker/releases/download/v0.20.0/rules_docker-v0.20.0.tar.gz"],
    )

    # Required to offer local dev with ibazel
    maybe(
        git_repository,
        name = "com_github_ash2k_bazel_tools",
        commit = "4daedde3ec61a03db841c8a9ca68288972e25a82",
        remote = "https://github.com/ash2k/bazel-tools.git",
    )

########
# Remaining content of the file is only used to support toolchains.
########
_DOC = "Fetch external tools needed for spa toolchain"
_ATTRS = {
    "spa_version": attr.string(mandatory = True, values = TOOL_VERSIONS.keys()),
    "platform": attr.string(mandatory = True, values = PLATFORMS.keys()),
}

def _spa_repo_impl(repository_ctx):
    url = "https://github.com/someorg/someproject/releases/download/v{0}/spa-{1}.zip".format(
        repository_ctx.attr.spa_version,
        repository_ctx.attr.platform,
    )
    repository_ctx.download_and_extract(
        url = url,
        integrity = TOOL_VERSIONS[repository_ctx.attr.spa_version][repository_ctx.attr.platform],
    )
    build_content = """#Generated by spa/repositories.bzl
load("@com_aghassi_rules_spa//spa:toolchain.bzl", "spa_toolchain")
spa_toolchain(name = "spa_toolchain", target_tool = select({
        "@bazel_tools//src/conditions:host_windows": "spa_tool.exe",
        "//conditions:default": "spa_tool",
    }),
)
"""

    # Base BUILD file for this repository
    repository_ctx.file("BUILD.bazel", build_content)

spa_repositories = repository_rule(
    _spa_repo_impl,
    doc = _DOC,
    attrs = _ATTRS,
)

# Wrapper macro around everything above, this is the primary API
def spa_register_toolchains(name, **kwargs):
    """Convenience macro for users which does typical setup.

    - create a repository for each built-in platform like "spa_linux_amd64" -
      this repository is lazily fetched when node is needed for that platform.
    - TODO: create a convenience repository for the host platform like "spa_host"
    - create a repository exposing toolchains for each platform like "spa_platforms"
    - register a toolchain pointing at each platform
    Users can avoid this macro and do these steps themselves, if they want more control.
    Args:
        name: base name for all created repos, like "spa1_14"
        **kwargs: passed to each node_repositories call
    """
    for platform in PLATFORMS.keys():
        spa_repositories(
            name = name + "_" + platform,
            platform = platform,
            **kwargs
        )
        native.register_toolchains("@%s_toolchains//:%s_toolchain" % (name, platform))

    toolchains_repo(
        name = name + "_toolchains",
        user_repository_name = name,
    )
