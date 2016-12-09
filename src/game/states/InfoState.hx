
package game.states;

import luxe.Input.MouseEvent;
import luxe.States.State;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Sprite;
import luxe.Color;
import luxe.Scene;

using Lambda;

class InfoState extends State {
    static public var StateId :String = 'InfoState';
    var callback :Void->Void;
    var scene :Scene;

    public function new() {
        super({ name: StateId });
        scene = new Scene();
    }

    // override function onenter(data :{ text :String, callback :Void->Void }) {
    //
    // }

    override function onleave(data) {
        Luxe.scene.empty();
    }

    // override public function onmouseup(event :luxe.Input.MouseEvent) {
    //     Main.states.set(PlayState.StateId);
    // }

    override public function onkeyup(event :luxe.Input.KeyEvent) {
        Main.states.set(PlayState.StateId);
    }
}
