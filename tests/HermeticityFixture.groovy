// Copyright 2025-present Alberto Cavalcante. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// Fixture for tests/hermeticity_test.bzl: the smallest Groovy source
// that produces a non-empty compile action so the analysistest can
// introspect mnemonic, env, and arg-shape.

package tests

class HermeticityFixture {
    static String marker() {
        "hermeticity-fixture"
    }
}
