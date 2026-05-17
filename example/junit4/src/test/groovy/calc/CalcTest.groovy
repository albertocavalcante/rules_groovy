package calc

import org.junit.Test
import static org.junit.Assert.assertEquals

class CalcTest {

    @Test
    void addsTwoNumbers() {
        assertEquals(5, Calc.add(2, 3))
    }
}
