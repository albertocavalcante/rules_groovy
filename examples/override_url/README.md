# override_url

A `groovy.toolchain` override that swaps the download URL for a
registry-known version (4.0.32) while letting the registry supply
`integrity`, `strip_prefix`, and `lib_jar`. The override pattern is
how downstream consumers point at a corporate mirror without
patching `rules_groovy`.

```python
groovy.toolchain(
    version = "4.0.32",
    urls = ["https://archive.corp.example.com/groovy/4.0.32/groovy-binary-4.0.32.zip"],
)
```

This example uses Apache's own archive URL so the `bazel build` runs
end-to-end without a real mirror. Substituting any other URL that
serves the same zip would work identically (integrity verification is
the gate).

```sh
bazel build //...
```

Sibling demo `examples/custom_version/` covers the second override
shape: a version NOT in the registry, where the consumer supplies all
four fields.
