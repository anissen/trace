import luxe.States;
import luxe.Input.KeyEvent;
import luxe.Input.Key;

import game.PostProcess;
import game.states.*;

import pgr.dconsole.DC;

class Main extends luxe.Game {
    static public var states :States;
    var fullscreen :Bool = false;
    var postprocess :PostProcess;

    override function config(config :luxe.GameConfig) {
        config.render.antialiasing = 4;

        config.preload.shaders.push({ id: 'postprocess', frag_id: 'assets/shaders/postprocess2.glsl', vert_id: 'default' });

        return config;
    }

    override function ready() {
        // Optional, set a consistent scale camera mode for the entire game
		// this is a luxe's wip feature
		Luxe.camera.size = new luxe.Vector(960, 640);
		// Luxe.camera.size_mode = luxe.Camera.SizeMode.cover;
		Luxe.camera.center = new luxe.Vector();

        luxe.tween.Actuate.defaultEase = luxe.tween.easing.Quad.easeInOut;

        Luxe.renderer.clear_color.set(25/255, 35/255, 55/255);

        var shader = Luxe.resources.shader('postprocess');
        shader.set_vector2('resolution', Luxe.screen.size);
        postprocess = new PostProcess(shader);
        postprocess.toggle(); // disable shader for now

        states = new States({ name: 'state_machine' });
        var worldstate = new WorldState();
        states.add(worldstate);
        states.set(WorldState.StateId);

        var theme :pgr.dconsole.DCThemes.Theme = {
    		CON_C 		: 0x353535,
    		CON_TXT_C 	: 0x00FF00,
    		CON_A		: .7,
    		CON_TXT_A	: 1,

    		PRM_C		: 0x454545,
    		PRM_TXT_C	: 0xFFFF00,

    		MON_C		: 0x000000,
    		MON_TXT_C	: 0xFF00FF,
    		MON_A		: .7,
    		MON_TXT_A	: .7,

    		LOG_WAR	: 0xFFFF00, // Warning messages color;
    		LOG_ERR	: 0xFF0000, // Error message color;
    		LOG_INF	: 0x00FFFF, // Info messages color;
    		LOG_CON	: 0x00FF00, // Confirmation messages color;
    	}

        DC.init(30, 'DOWN', theme);
        // DC.log("This text will be logged.");
        DC.registerFunction(function() { postprocess.toggle(); }, "toggle_shader");
        // DC.registerObject(this, "myobject");
        DC.registerObject(worldstate, "world");
        // DC.registerClass(Math, "Math");
    }

    // Scale camera's viewport accordingly when game is scaled, common and suitable for most games
	// override function onwindowsized(e: luxe.Screen.WindowEvent) {
    //     Luxe.camera.viewport = new luxe.Rectangle(0, 0, e.event.x, e.event.y);
    // }

    override function onprerender() {
        if (postprocess != null) postprocess.prerender();
    }

    override function update(dt :Float) {
        if (postprocess != null) postprocess.shader.set_float('time', Luxe.core.tick_start + dt);
    }

    override function onpostrender() {
        if (postprocess != null) postprocess.postrender();
    }

    override function onkeyup(e :KeyEvent) {
        if (e.keycode == Key.enter && e.mod.alt) {
            fullscreen = !fullscreen;
            Luxe.snow.runtime.window_fullscreen(fullscreen, true /* true-fullscreen */);
        } /* else if (e.keycode == Key.key_s) {
            // save state
            Luxe.io.string_save('save', 'blah test');
        } else if (e.keycode == Key.key_l) {
            // load saved state
            trace('loaded state: ' + Luxe.io.string_load('save'));
        } else if (e.keycode == Key.key_p) {
            postprocess.toggle();
        } else if (e.keycode == Key.key_m) {
            states.set(WorldState.StateId);
        }
        */
    }
}
