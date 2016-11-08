
package core.tools;

class ArrayTools {
    static public inline function random<T>(array :Array<T>, ?random :Int->Int) :T {
        return array[(random != null ? random(array.length) : Std.random(array.length))];
    }

    static public inline function empty<T>(array :Array<T>) :Bool {
        return (array.length == 0);
    }

    static public function shuffle<T>(array :Array<T>, ?random :Int->Int) :Array<T> {
        var indexes = [ for (i in 0 ... array.length) i ];
        var random_func = (random != null ? random : Std.random);
        var result = [];
        while (indexes.length > 0) {
            var pos = random_func(indexes.length);
            var index = indexes[pos];
            indexes.splice(pos, 1);
            result.push(array[index]);
        }
        return result;
    }
}
