package calc

import org.junit.jupiter.api.Test
import static org.junit.jupiter.api.Assertions.assertEquals

class CalcTest {

    @Test
    void addsTwoNumbers() {
        assertEquals(5, Calc.add(2, 3))
    }
}
