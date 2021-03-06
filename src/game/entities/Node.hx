
package game.entities;

import luxe.Vector;
import luxe.Visual;
import luxe.Sprite;
import luxe.Color;
import luxe.Text;

// typedef GraphNode = core.models.Graph.Node<String>;

typedef NodeOptions = {
    > luxe.options.SpriteOptions,
    key :String,
    value :String,
    detection :Float,
    capture_time :Float,
    ?enforced :Bool,
    // is_locked :Bool,
    // unlocks :GraphNode
}

class Node extends Visual {
    public var icon :Sprite;
    public var key :String;
    public var value :String;
    public var detection :Float;
    public var capture_time :Float;
    public var text :Text;
    public var enforced :Bool;
    public var honeypot :Sprite;

    // public var description :Text;
    // public var is_locked :Bool;
    // public var unlocks :GraphNode;

    public function new(options :NodeOptions) {
        super(options);

        this.key = options.key;
        this.value = options.value;
        this.detection = options.detection;
        this.capture_time = options.capture_time;
        this.enforced = (options.enforced != null ? options.enforced : false);
        // this.is_locked = options.is_locked;
        // this.unlocks = options.unlocks;

        if (texture != null) {
            icon = new Sprite({
                texture: texture,
                scale: new Vector(0.3, 0.3),
                color: new Color(1 - color.r / 2, 1 - color.g / 2, 1 - color.b / 2),
                depth: options.depth,
                parent: this
            });
        }

        var bar = new Visual({
            pos: (texture != null ? new Vector(-40, 30) : new Vector(-40, -35/2)),
            color: new Color(0, 0, 0),
            size: new Vector(80, 35),
            parent: this,
            depth: options.depth + 2
        });

        text = new Text({
            text: options.key,
            pos: new Vector(40, 15),
            color: new Color(1, 1, 1),
            align: center,
            align_vertical: center,
            point_size: 36,
            depth: options.depth + 3,
            parent: bar
        });
        // description = new Text({
        //     pos: new Vector(0, 25),
        //     text: options.value,
        //     color: new Color(0, 0, 0),
        //     align: center,
        //     align_vertical: center,
        //     point_size: 24,
        //     depth: options.depth,
        //     parent: this
        // });
    }

    public function set_capture_text(str :String) {
        if (str != '') {
            text.text = str;
            // description.visible = false;
        } else {
            text.text = key;
            // description.visible = true;
        }
    }

    public function nuked(is_nuked :Bool) {
        this.text.point_size = (is_nuked ? 22 : 36);
        set_capture_text(is_nuked ? 'NUKED' : '');
        this.color.rgb(is_nuked ? 0xAAAAAA : 0x2ECC40);
        this.color.a = (is_nuked ? 0.3 : 1.0);
        if (icon != null) {
            if (is_nuked) {
                icon.color.rgb(is_nuked ? 0xAAAAAA : 0x2ECC40);
            } else {
                icon.color = new Color(1 - color.r / 2, 1 - color.g / 2, 1 - color.b / 2);
            }
            icon.color.a = (is_nuked ? 0.3 : 1.0);
        }
    }
}
