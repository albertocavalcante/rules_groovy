package example.protocol

class Position {
    final int line
    final int character

    Position(int line, int character) {
        this.line = line
        this.character = character
    }

    boolean isBefore(Position other) {
        line < other.line || (line == other.line && character < other.character)
    }
}
