# local_toolchain

Bring-your-own Groovy SDK: `groovy.local_toolchain` points at an
on-disk installation instead of downloading the SDK from Apache.
No URL, no integrity hash, no network at toolchain-resolve time.
Closes the air-gap path: combined with `--repository_cache` and
`--distdir` for any remaining transitive Bazel deps, this is what
a fully-offline build looks like.

```python
groovy.local_toolchain(
    name = "groovy_local",
    sdk_path = "/opt/groovy-4.0.32",
    version = "4.0.32",
    lib_jar = "lib/groovy-4.0.32.jar",
)
```

The repository rule symlinks `sdk_path` as `groovy-<version>/` inside
the generated repo so the `groovyc` launcher resolves the same way
it does for downloaded SDKs. If `<sdk_path>/<lib_jar>` does not exist
at resolve time, the extension fails with a path-specific error.

```sh
bazel build //...
```

## Running this example

CI pre-installs Groovy 4.0.32 at `/opt/groovy-4.0.32` via a workflow
step gated on `matrix.example == 'local_toolchain'`. Local devs
running this example outside CI must either:

1. Install Groovy at the same path:
   ```sh
   curl -L -o /tmp/groovy.zip https://archive.apache.org/dist/groovy/4.0.32/distribution/apache-groovy-binary-4.0.32.zip
   sudo unzip -q /tmp/groovy.zip -d /opt/
   ```
2. Or edit `sdk_path` in `MODULE.bazel` to point at your existing
   installation. Common paths:
   - macOS Homebrew: `/opt/homebrew/Cellar/groovy/<version>/libexec`
   - SDKMAN!: `~/.sdkman/candidates/groovy/<version>`
   - Manual install: wherever you unzipped the binary distribution

`lib_jar` is the path to the runtime jar **relative to** `sdk_path`.
Apache's binary distribution layout is `lib/groovy-<version>.jar`;
some package managers re-flatten this.
