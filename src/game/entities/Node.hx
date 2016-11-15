
package game.entities;

import luxe.Vector;
import luxe.Visual;
import luxe.Color;
import luxe.Text;

typedef NodeOptions = {
    > luxe.options.SpriteOptions,
    value :String,
    key :String
}

class Node extends Visual {
    public var key :String;
    public var value :String;
    public var text :Text;
    public var description :Text;

    public function new(options :NodeOptions) {
        super(options);

        this.key = options.key;

        text = new Text({
            text: options.key, // + '\n' + options.value,
            color: new Color(0, 0, 0),
            align: center,
            align_vertical: center,
            point_size: 36,
            depth: options.depth,
            parent: this
        });
        description = new Text({
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

    public function set_capture_text(str :String) {
        if (str != '') {
            text.text = str;
            description.visible = false;
        } else {
            text.text = key;
            description.visible = true;
        }
    }
}
