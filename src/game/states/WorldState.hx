
package game.states;

import luxe.Input.MouseEvent;
import luxe.States.State;
import luxe.Vector;
import luxe.Sprite;
import luxe.tween.Actuate;
import phoenix.Batcher;
import luxe.Scene;
import luxe.Color;
import snow.api.Promise;

import core.physics.*;

using Lambda;

class WorldState extends State {
    static public var StateId :String = 'WorldState';

    var overlay_batcher :phoenix.Batcher;
    var overlay_filter :Sprite;

    var s :ParticleSystem;

    var current :core.models.Graph.Node<String>;
    var nodes :Map<core.models.Graph.Node<String>, Particle>;
    var graph :core.models.Graph<String>;

    // var link_keys :Map<Spring, Int>;
    var available_keys :Array<String>;

    var capture_time :Float;
    var capture_node :core.models.Graph.Node<String>;
    var captured_nodes :Array<core.models.Graph.Node<String>>;

    var node_entities :Map<core.models.Graph.Node<String>, game.entities.Node>;

    #if with_shader
    var circuits_sprite :Sprite;
    var circuits_shader :phoenix.Shader;
    #end

    public function new() {
        super({ name: StateId });
        current = null;
    }

    override function init() {
        overlay_batcher = Luxe.renderer.create_batcher({
            name: 'overlay',
            layer: 100
        });
        overlay_batcher.on(prerender, function(b :Batcher) {
            Luxe.renderer.blend_mode(BlendMode.src_alpha, BlendMode.one);
        });
        overlay_batcher.on(postrender, function(b :Batcher) {
            Luxe.renderer.blend_mode();
        });

        #if with_shader
        circuits_shader = Luxe.resources.shader('circuits');
        circuits_shader.set_vector2('resolution', Luxe.screen.size);
        circuits_sprite = new Sprite({
            pos: Luxe.camera.center,
            size: Luxe.screen.size,
            shader: circuits_shader,
            depth: -1000
        });
        #end

        nodes = new Map();
        node_entities = new Map();
        // link_keys = new Map();
        // var key_list = 'ABCDEFGHIJKLMNOPQRSTUVXYZ';
        available_keys = 'ABCDEFGHIJKLMNOPQRSTUVXYZ'.split(''); //[ for (c in key_list.split()) c ];

        capture_node = null;
        capture_time = 0;
        captured_nodes = [];

        // test
        graph = core.models.Graph.Test2.get_graph();

        setup_particles();

        var start_node = graph.get_node('start');
        select_node(start_node);
    }

    function add_linked_nodes(n :core.models.Graph.Node<String>) {
        var delay = 0;
        for (l in graph.get_links_for_node(n)) {
            if (nodes.exists(l)) continue;

            haxe.Timer.delay(function() {
                var p = add_node();
                node_entities[l] = create_node_entity(p, l);
                nodes[l] = p;
                add_edge(p, nodes[n]);
            }, delay);
            delay += 500;
        }
    }

    function create_node_entity(p :Particle, n :core.models.Graph.Node<String>) {
        return new game.entities.Node({
            geometry: Luxe.draw.ngon({
                x: p.position.x,
                y: p.position.y,
                r: (n == current ? NODE_SIZE * 1.2 : NODE_SIZE),
                sides: 6,
                angle: 30,
                color: (n == current ? new Color(1, 0.2, 0, 1) : new Color(1, 0, 1, 1)),
                solid: true
            }),
            value: n.to_string(),
            key: available_keys.splice(Math.floor(available_keys.length * Math.random()), 1)[0]
        });
    }

    function setup_particles() {
        s = new ParticleSystem(new Vector3D(0, 0, 0), 0.1);
        // Runge-Kutta, the default integrator is stable and snappy,
         // but slows down quickly as you add particles.
         // 500 particles = 7 fps on my machine

         // Try this to see how Euler is faster, but borderline unstable.
         // 500 particles = 24 fps on my machine
        //  s.setIntegrator( ParticleSystem.MODIFIED_EULER );

         // Now try this to see make it more damped, but stable.
        //  s.setDrag( 0.2 );

         initialize();
    }

    var NODE_SIZE :Float = 50;
    var EDGE_LENGTH :Float = 200;
    var EDGE_STRENGTH :Float = 2;
    var SPACER_STRENGTH :Float = 20000;

    function addSpacersToNode(p :Particle, r :Particle) {
        for (q in s.particles) {
            if (p != q && p != r) {
                s.makeAttraction( p, q, -SPACER_STRENGTH, 20 );
            }
        }
    }

    function makeEdgeBetween(a :Particle, b :Particle) {
        s.makeSpring(a, b, EDGE_STRENGTH, EDGE_STRENGTH, EDGE_LENGTH);
        // var key = available_keys.splice(Math.floor(available_keys.length * Math.random()), 1)[0];
        // link_keys[spring] = key.charAt(0);
    }

    function initialize() {
        s.clear();
    }

    function add_node() {
        return s.makeParticle();
    }

    function add_edge(p :Particle, q :Particle) {
        addSpacersToNode(p, q);
        makeEdgeBetween(p, q);
        p.position = new Vector3D(q.position.x -1 + 2 * Math.random(), q.position.y -1 + 2 * Math.random(), 0);
    }

    override function onenter(_) {
        Luxe.camera.zoom = 0.1;
        luxe.tween.Actuate.tween(Luxe.camera, 0.5, { zoom: 1 });

        // overlay_filter = new Sprite({
        //     pos: Luxe.screen.mid.clone(),
        //     texture: Luxe.resources.texture('assets/images/overlay_filter.png'),
        //     size: Luxe.screen.size.clone(),
        //     batcher: overlay_batcher
        // });
        // overlay_filter.color.a = 0.5;
    }

    override function onleave(_) {
        Luxe.scene.empty();
    }

    override function onrender() {
        for (i in 0 ... s.numberOfSprings()) {
            var e :Spring = s.getSpring(i);
            var a :Particle = e.getOneEnd();
            var b :Particle = e.getTheOtherEnd();

            Luxe.draw.line({
                p0: new Vector(a.position.x, a.position.y),
                p1: new Vector(b.position.x, b.position.y),
                // color: new Color().rgb(0x00DD11),
                immediate: true
            });
        }

        if (capture_node != null) {
            var p = nodes[capture_node];
            Luxe.draw.ngon({
                x: p.position.x,
                y: p.position.y,
                r: NODE_SIZE + (NODE_SIZE * capture_time),
                sides: 6,
                angle: 30,
                color: new Color(1, 0.2, 0, 1),
                solid: false,
                immediate: true
            });
        }

        for (n in node_entities.keys()) {
            var p = nodes[n];
            var entity = node_entities[n];
            entity.pos.x = p.position.x;
            entity.pos.y = p.position.y;
        }
    }

    function get_world_pos(pos :Vector) :Vector {
        var r = Luxe.camera.view.screen_point_to_ray(pos);
        var result = Luxe.utils.geometry.intersect_ray_plane(r.origin, r.dir, new Vector(0, 0, 1), new Vector());
        result.z = 0;
        return result;
    }

    // override function onmousemove(event :MouseEvent) {
    //     for (n in node_entities.keys()) {
    //         var entity = node_entities[n];
    //         var hit = Luxe.utils.geometry.point_in_geometry(get_world_pos(event.pos), entity.geometry);
    //         entity.color.r = (hit ? 0 : 1);
    //     }
    // }
    //
    // override function onmousedown(event :MouseEvent) {
    //     for (n in node_entities.keys()) {
    //         var entity = node_entities[n];
    //         var hit = Luxe.utils.geometry.point_in_geometry(get_world_pos(event.pos), entity.geometry);
    //         if (hit) {
    //             for (node in node_entities.keys()) {
    //                 if (node_entities[node] == entity) {
    //                     select_node(node);
    //                     return;
    //                 }
    //             }
    //             return;
    //         }
    //     }
    // }

    override function onkeydown(event :luxe.Input.KeyEvent) {
        if (capture_node != null) {
            // to avoid retriggering the capture
            if (event.keycode == node_entities[capture_node].key.toLowerCase().charCodeAt(0)) return;
        }
        for (n in graph.get_links_for_node(current)) {
            if (event.keycode == node_entities[n].key.toLowerCase().charCodeAt(0)) {
                var already_captured = (captured_nodes.indexOf(n) >= 0);
                capture_time = (already_captured ? 0.3 : 2);
                capture_node = n;
                return;
            }
        }
    }

    override function onkeyup(event :luxe.Input.KeyEvent) {
        capture_node = null;
    }

    function select_node(node :core.models.Graph.Node<String>) {
        if (captured_nodes.indexOf(node) < 0) captured_nodes.push(node);

        current = node;
        if (!nodes.exists(node)) {
            nodes[node] = add_node();
        }
        var p = nodes[current];
        if (!node_entities.exists(node)) {
            node_entities[node] = create_node_entity(p, node);
        }
        for (node in captured_nodes) {
            node_entities[node].color.rgb(0x2ECC40); // .rgb(0x44FF44);
        }
        node_entities[current].color.rgb(0xF012BE); // .rgb(0xDD00FF);
        add_linked_nodes(node);
        Luxe.camera.focus(new Vector(p.position.x, p.position.y), 0.3);
    }

    override function update(dt :Float) {
        s.tick(dt * 10); // Hack to multiply dt

        #if with_shader
        circuits_sprite.pos = Luxe.camera.center.clone();
        if (circuits_shader != null) circuits_shader.set_float('time', (Luxe.core.tick_start + dt) * 0.005);
        #end

        if (capture_node != null && capture_node != current) {
            capture_time -= dt;
            if (capture_time <= 0) {
                select_node(capture_node);
                capture_node = null;
            }
        }
    }
}
