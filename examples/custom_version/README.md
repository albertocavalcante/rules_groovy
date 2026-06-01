# custom_version

A `groovy.toolchain` tag for a Groovy version that is NOT pinned in
`rules_groovy`'s built-in registry (`groovy/private/versions.bzl`).
When the version is unknown, the consumer must pin all four download
fields: `urls`, `integrity`, `strip_prefix`, `lib_jar`. The extension
fails loudly if any of them is missing.

```python
groovy.toolchain(
    version = "4.0.24",
    urls = ["https://archive.apache.org/dist/groovy/4.0.24/distribution/apache-groovy-binary-4.0.24.zip"],
    integrity = "sha256-2/82g1VovsInGHb3C/zKbeuA4bF5RTzKk0pQLqMBu4A=",
    strip_prefix = "groovy-4.0.24",
    lib_jar = "lib/groovy-4.0.24.jar",
)
```

```sh
bazel build //...
```

If you omit any of the four fields for an unregistered version, the
extension emits:

```
Groovy 4.0.24 not in registry. Pin all of urls, integrity, strip_prefix,
lib_jar on this groovy.toolchain tag, or add the version to
groovy/private/versions.bzl. Known versions: ["2.5.23", "3.0.25", "4.0.32"].
(missing on this tag: ["integrity"])
```

Sibling demo `examples/override_url/` covers the other override
shape: a registry-known version with only a custom URL list.
