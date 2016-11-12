
package game.entities;

import luxe.Vector;
import luxe.Visual;
import luxe.Color;

typedef NodeOptions = {
    > luxe.options.SpriteOptions,
    value :String,
    key :String
}

class Node extends Visual {
    public var key :String;

    public function new(options :NodeOptions) {
        super(options);

        this.key = options.key;

        new luxe.Text({
            text: options.key, // + '\n' + options.value,
            color: new Color(0, 0, 0),
            align: center,
            align_vertical: center,
            point_size: 36,
            depth: options.depth,
            parent: this
        });
        new luxe.Text({
            pos: new Vector(0, 25),
            text: options.value,
            color: new Color(0, 0, 0),
            align: center,
            align_vertical: center,
            point_size: 24,
            depth: options.depth,
            parent: this
        });
    }
}
