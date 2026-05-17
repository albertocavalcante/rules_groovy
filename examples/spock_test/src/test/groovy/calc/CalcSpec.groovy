package calc

import spock.lang.Specification

class CalcSpec extends Specification {

    def "multiplies two numbers"() {
        expect:
        Calc.multiply(a, b) == result

        where:
        a | b || result
        2 | 3 || 6
        4 | 5 || 20
        0 | 9 || 0
    }
}
