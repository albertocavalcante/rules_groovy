package lib

import org.junit.Test
import static org.junit.Assert.assertEquals

// Plain JUnit 4 test that compiles and runs cleanly on the Groovy
// 2.5 / 3.0 / 4.0 toolchains registered in `MODULE.bazel`. Avoids
// Spock so the toolchain's Spock pin (tied to one Groovy major) does
// not break the other two SDKs, and avoids JUnit 5 because each
// Groovy SDK distribution bundles its own (older) copy of the JUnit
// Platform jars that clash with the toolchain's pinned 1.14.4. JUnit
// 4 (junit-4.13.2) is bundled identically by all three SDKs and
// matches the toolchain. See ISSUE-071.
class LibTest {

    @Test
    void greetsByName() {
        assertEquals("Hello, world!", Lib.hello("world"))
    }
}
