
package game.entities;

import luxe.Entity;
import luxe.Vector;
import luxe.Visual;
import luxe.Sprite;
import luxe.Color;
import luxe.Text;
import phoenix.Texture;

typedef ItemOptions = {
    item :String,
    texture :Texture,
    index :Int,
    ?inverted :Bool
}

class ItemBox extends Entity {
    public var item :String;
    public var text :Text;
    public var index :Int;

    var pos_vector :Vector;
    var bg :Visual;
    var icon :Sprite;

    public function new(options :ItemOptions) {
        super();
        this.item = options.item;
        this.index = options.index;

        pos_vector = switch (options.index) {
            case 0: new Vector(-105, -120);
            case 1: new Vector(   5, -120);
            case 2: new Vector(-105,  20);
            case 3: new Vector(   5,  20);
            case _: throw 'error';
        }

        var bgColor = new Color(0, 0, 0, 0.9);
        var fgColor = new Color(1, 0.3, 1); //.rgb(0xF012BE)
        if (options.inverted != null && options.inverted) {
            var tmpColor = bgColor.clone();
            bgColor = fgColor.clone();
            fgColor = tmpColor;
        }

        bg = new Visual({
            // pos: placement,
            size: new Vector(100, 100),
            color: bgColor,
            depth: 2,
            parent: this
        });

        text = new Text({
            text: options.item,
            pos: (options.index < 2 ? new Vector(50, 15) : new Vector(50, 85)),
            color: fgColor,
            align: center,
            align_vertical: center,
            point_size: 22,
            depth: 2,
            parent: bg
        });

        icon = new Sprite({
            pos: (options.index < 2 ? new Vector(50, 60) : new Vector(50, 40)),
            color: fgColor,
            texture: options.texture,
            scale: new Vector(0.2, 0.2),
            depth: 2,
            parent: bg
        });
    }

    public function visible(enabled :Bool) {
        bg.visible = enabled;
        text.visible = enabled;
        icon.visible = enabled;
    }

    public function reset_position() {
        bg.pos = new Vector(pos.x - 50, pos.y - 50);
    }

    override public function update(dt :Float) {
        bg.pos.lerp(pos_vector, 5 * dt);
    }
}
