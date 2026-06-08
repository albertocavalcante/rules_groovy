package example.protocol

import spock.lang.Specification

class PositionSpec extends Specification {

    def "orders positions by line then character"() {
        expect:
        left.isBefore(right) == result

        where:
        left               | right              || result
        new Position(1, 0) | new Position(2, 0) || true
        new Position(1, 2) | new Position(1, 3) || true
        new Position(2, 0) | new Position(1, 9) || false
    }
}
