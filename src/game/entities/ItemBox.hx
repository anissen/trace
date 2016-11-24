
package game.entities;

import luxe.Vector;
import luxe.Visual;
import luxe.Sprite;
import luxe.Color;
import luxe.Text;

typedef ItemOptions = {
    origin: Vector,
    offset: Vector,
    item :String
}

class ItemBox extends luxe.Entity {
    public var item :String;
    public var text :Text;

    public function new(options :ItemOptions) {
        super({
            // origin: options.origin,
            // pos: options.offset,
            // color: new Color(0, 0, 0),
            // size: new Vector(80, 80),
            // depth: 2
        });

        this.item = options.item;

        // if (texture != null) {
        //     var icon = new Sprite({
        //         texture: texture,
        //         scale: new Vector(0.35, 0.35),
        //         color: new Color(1 - color.r / 2, 1 - color.g / 2, 1 - color.b / 2),
        //         depth: options.depth,
        //         parent: this
        //     });
        // }

        var left = new Visual({
            pos: new Vector(-105, -120),
            size: new Vector(100, 100),
            color: new Color(0, 0, 0),
            depth: 2,
            parent: this
        });

        var right = new Visual({
            pos: new Vector(5, -120),
            size: new Vector(100, 100),
            color: new Color(0, 0, 0),
            depth: 2,
            parent: this
        });

        text = new Text({
            text: options.item,
            pos: new Vector(50, 15),
            color: new Color(1, 0, 1),
            align: center,
            align_vertical: center,
            point_size: 22,
            depth: 2,
            parent: left
        });

        new Sprite({
            pos: new Vector(50, 60),
            color: new Color(1, 0, 1),
            texture: Luxe.resources.texture('assets/images/trojan-horse.png'),
            scale: new Vector(0.2, 0.2),
            depth: 2,
            parent: left
        });
    }
}
