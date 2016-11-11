
package game.entities;

import luxe.Vector;
import luxe.Visual;
import luxe.Color;

typedef NodeOptions = {
    > luxe.options.SpriteOptions,
    value :String
}

class Node extends Visual {
    public function new(options :NodeOptions) {
        super(options);

        new luxe.Text({
            text: options.value,
            color: new Color(0, 0, 0),
            align: center,
            align_vertical: center,
            point_size: 16,
            parent: this
        });
    }
}
