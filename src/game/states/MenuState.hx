
package game.states;

import luxe.Input.MouseEvent;
import luxe.States.State;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Text;
import luxe.Color;

using Lambda;

class MenuState extends State {
    static public var StateId :String = 'MenuState';

    public function new() {
        super({ name: StateId });
    }

    override function onenter(data :Dynamic) {
        Luxe.camera.center = new luxe.Vector();
        Main.bloom = 0.4;
        Main.shift = 0.0;
        Luxe.renderer.clear_color.tween(1, { r: 25/255, g: 35/255, b: 55/255 });
        new Text({
            pos: new Vector(),
            text: (data != null ? data : 'trace'),
            point_size: 72,
            align: center,
            align_vertical: center
        });
    }

    override function onleave(data) {
        Luxe.scene.empty();
    }

    override public function onmouseup(event :luxe.Input.MouseEvent) {
        Main.states.set(WorldState.StateId);
    }

    override public function onkeyup(event :luxe.Input.KeyEvent) {
        Main.states.set(WorldState.StateId);
    }
}
