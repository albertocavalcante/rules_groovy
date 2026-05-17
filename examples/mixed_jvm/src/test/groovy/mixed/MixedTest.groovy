package mixed

import org.junit.jupiter.api.Test
import static org.junit.jupiter.api.Assertions.assertEquals

class MixedTest {

    @Test
    void groovyCallsJava() {
        // Caller.groovy → Helper.java cross-language invocation.
        assertEquals("helper-result", Caller.callHelper())
    }
}
