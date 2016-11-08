package game;

import phoenix.Batcher.BlendMode;
import phoenix.RenderTexture;
import phoenix.Texture;
import phoenix.Batcher;
import phoenix.Shader;
import luxe.Sprite;
import luxe.Vector;
import luxe.Color;

class PostProcess {
    var output: RenderTexture;
    var batch: Batcher;
    var view: Sprite;
    public var shader: Shader;

    public function new(shader :Shader) {
        output = new RenderTexture({ id: 'render-to-texture', width: Luxe.screen.w, height: Luxe.screen.h });
        batch = Luxe.renderer.create_batcher({ no_add: true });
        this.shader = shader;
        view = new Sprite({
            no_scene: true,
            centered: false,
            pos: new Vector(0,0),
            size: Luxe.screen.size,
            texture: output,
            shader: shader, //Luxe.renderer.shaders.textured.shader,
            batcher: batch
        });
    }

    public function toggle() {
        view.shader = (view.shader == shader ? Luxe.renderer.shaders.textured.shader : shader);
    }

    public function prerender() {
        Luxe.renderer.target = output;
        Luxe.renderer.clear(new Color(0,0,0,1));
    }

    public function postrender() {
        Luxe.renderer.target = null;
        Luxe.renderer.clear(new Color(1,0,0,1));
        Luxe.renderer.blend_mode(BlendMode.src_alpha, BlendMode.zero);
        batch.draw();
        Luxe.renderer.blend_mode();
    }
}
