
package game.states;

import luxe.Input.MouseEvent;
import luxe.States.State;
import luxe.Vector;
import luxe.Sprite;
import luxe.tween.Actuate;
import phoenix.Batcher;
import luxe.Scene;
import luxe.Color;
import luxe.Text;
import snow.api.Promise;
import game.entities.Notification;
import game.entities.ItemBox;

import core.physics.*;

using Lambda;

typedef GraphNode = core.models.Graph.Node<String>;

class WorldState extends State {
    static public var StateId :String = 'WorldState';

    var overlay_batcher :phoenix.Batcher;
    var overlay_filter :Sprite;

    var s :ParticleSystem;

    var nodes :Map<GraphNode, Particle>;
    var graph :core.models.Graph<String>;

    var available_keys :Array<String>;

    var current :GraphNode;
    var capture_time :Float;
    var capture_node :GraphNode;
    var captured_nodes :Array<GraphNode>;

    var enemy_in_game :Bool;
    var enemy_current :GraphNode;
    var enemy_capture_time :Float;
    var enemy_capture_node :GraphNode;
    var enemy_captured_nodes :Array<GraphNode>;

    var got_data :Bool;

    var node_entities :Map<GraphNode, game.entities.Node>;

    var countdownText :Text;
    var countdown :Float;

    var item_boxes :Array<ItemBox>;
    var capture_item_boxes :Array<ItemBox>;
    var max_item_boxes :Int = 2;

    #if with_shader
    var circuits_sprite :Sprite;
    var circuits_shader :phoenix.Shader;
    #end

    public function new() {
        super({ name: StateId });
    }

    override function init() {
        overlay_batcher = Luxe.renderer.create_batcher({
            name: 'overlay',
            layer: 1000
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

        available_keys = 'ABCDEFGHIJKLMNOPQRSTUVXYZ'.split('');

        current = null;
        capture_node = null;
        capture_time = 0;
        captured_nodes = [];

        got_data = false;

        enemy_in_game = false;
        enemy_current = null;
        enemy_capture_node = null;
        enemy_capture_time = 0;
        enemy_captured_nodes = [];

        countdownText = new Text({
            text: '--:--',
            pos: new Vector(Luxe.screen.mid.x, 50),
            point_size: 64,
            align: center,
            align_vertical: center,
            batcher: Luxe.renderer.create_batcher({
                name: 'ui',
                layer: 500
            })
        });

        // test
        graph = core.models.Graph.Factory.create_graph();

        setup_particles();

        item_boxes = [];
        item_boxes.push(new ItemBox({
            item: 'Trojan',
            texture: Luxe.resources.texture('assets/images/trojan-horse.png'),
            index: 0
        }));
        item_boxes.push(new ItemBox({
            item: 'Enforce',
            texture: Luxe.resources.texture('assets/images/shieldcomb.png'),
            index: 1
        }));

        capture_item_boxes = [];
        capture_item_boxes.push(new ItemBox({
            item: 'Scan',
            texture: Luxe.resources.texture('assets/images/radar-sweep.png'),
            inverted: true,
            index: 0
        }));

        var start_node = graph.get_node('start');
        select_node(start_node);

        countdown = 60;

        haxe.Timer.delay(function() {
            detected(start_node);
        }, Math.floor(countdown * 1000));
    }

    function add_linked_nodes(n :GraphNode) {
        var delay = 0;
        for (l in graph.get_edges_for_node(n)) {
            if (nodes.exists(l)) {
                var link_node = true;
                var p = nodes[l];
                var q = nodes[n];
                // check if there already is an edge between p and q
                for (spring in s.springs) {
                    if ((spring.getOneEnd() == p && spring.getTheOtherEnd() == q) || (spring.getOneEnd() == q && spring.getTheOtherEnd() == p)) {
                        link_node = false;
                        break;
                    }
                }
                if (link_node) add_edge(p, q);
            } else {
                haxe.Timer.delay(function() {
                    var p = add_node();
                    node_entities[l] = create_node_entity(p, l);
                    nodes[l] = p;
                    add_edge(p, nodes[n]);
                }, delay);
                delay += 500;
            }
        }
    }

    function create_node_entity(p :Particle, n :GraphNode) {
        var detection = 10;
        var capture_time = 1.5;
        var texture = null;
        switch (n.value) {
            case 'datastore':
                detection = 20;
                capture_time = 4;
                texture = Luxe.resources.texture('assets/images/database.png');
            case 'node':
                detection = 10;
                capture_time = 2;
                // texture = Luxe.resources.texture('assets/images/processor.png');
            case 'lock':
                texture = Luxe.resources.texture('assets/images/finger-print.png');
            case 'key':
                texture = Luxe.resources.texture('assets/images/id-card.png');
        }

        var entity = new game.entities.Node({
            geometry: Luxe.draw.ngon({
                x: p.position.x,
                y: p.position.y,
                r: NODE_SIZE,
                sides: 6,
                angle: 30,
                solid: true
            }),
            texture: texture,
            depth: 10,
            value: n.to_string(),
            key: available_keys.splice(Math.floor(available_keys.length * Math.random()), 1)[0],
            detection: detection,
            capture_time: capture_time
        });

        if (is_locked(n)) {
            entity.set_capture_text('?');
        }

        // Enforced
        if (n.value == 'gate') {
            new luxe.Visual({
                geometry: Luxe.draw.ngon({
                    r: NODE_SIZE * 1.25,
                    sides: 6,
                    angle: 30,
                    solid: false
                }),
                color: entity.color,
                parent: entity
            });
        }

        return entity;
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
        var spring = s.makeSpring(a, b, 0, EDGE_STRENGTH, EDGE_LENGTH);

        // tween spring strength from 0 to EDGE_STRENGTH over 0.5 seconds
        luxe.tween.Actuate.update(spring.setStrength, 0.5, [0], [EDGE_STRENGTH]);
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
        p.position = new Vector3D(q.position.x - 10 + 20 * Math.random(), q.position.y - 10 + 20 * Math.random(), 0);
    }

    override function onenter(_) {
        Luxe.camera.zoom = 0.1;
        luxe.tween.Actuate.tween(Luxe.camera, 0.5, { zoom: 1 });

        overlay_filter = new Sprite({
            centered: true,
            pos: Luxe.camera.pos.clone(),
            texture: Luxe.resources.texture('assets/images/overlay_filter.png'),
            size: Vector.Multiply(Luxe.screen.size.clone(), 1.2),
            batcher: overlay_batcher,
            depth: 1000
        });
        overlay_filter.color.a = 0.6;
    }

    override function onleave(_) {
        Luxe.scene.empty();
    }

    override function onrender() {
        overlay_filter.pos = Luxe.camera.view.center.clone();

        for (r in graph.get_edges()) {
            if (!node_entities.exists(r.a) || !node_entities.exists(r.b)) continue;

            var line = Luxe.draw.line({
                p0: node_entities[r.a].pos,
                p1: node_entities[r.b].pos,
                immediate: true,
                depth: 5
            });
            if (captured_nodes.indexOf(r.b) == -1 && is_locked(r.b)) {
                line.color = new Color(1, 0, 0, 0.5);
            }
            // for (key in graph.get_keys_for_node(r.b)) {
            //     if (!node_entities.exists(key)) continue;
            //     Luxe.draw.line({
            //         p0: node_entities[key].pos,
            //         p1: node_entities[r.b].pos,
            //         color0: new Color(0, 1, 0),
            //         color1: new Color(1, 1, 1),
            //         immediate: true,
            //         depth: 5
            //     });
            // }
        }

        for (itembox in item_boxes) {
            itembox.visible(false);
        }
        if (current != null) {
            var p = nodes[current];
            if (node_entities.exists(current)) {
                var current_entity_pos = node_entities[current].pos;
                for (itembox in item_boxes) {
                    itembox.visible(true);
                    itembox.pos = current_entity_pos.clone();
                }
            }
            Luxe.draw.ngon({
                x: p.position.x,
                y: p.position.y,
                r: NODE_SIZE * 1.2,
                sides: 6,
                angle: 30,
                color: new Color().rgb(0xF012BE),
                solid: true,
                immediate: true,
                depth: 6
            });
        }

        for (itembox in capture_item_boxes) {
            itembox.visible(false);
        }
        if (capture_node != null) {
            var p = nodes[capture_node];
            if (node_entities.exists(capture_node)) {
                var capture_entity_pos = node_entities[capture_node].pos;
                for (itembox in capture_item_boxes) {
                    itembox.visible(true);
                    itembox.pos = capture_entity_pos.clone();
                }
            }
            Luxe.draw.ngon({
                x: p.position.x,
                y: p.position.y,
                r: NODE_SIZE + (NODE_SIZE * capture_time),
                sides: 6,
                angle: 30,
                color: new Color().rgb(0xF012BE),
                solid: false,
                immediate: true,
                depth: 100
            });
        }

        if (enemy_current != null) {
            var p = nodes[enemy_current];
            if (p != null) {
                Luxe.draw.ngon({
                    x: p.position.x,
                    y: p.position.y,
                    r: NODE_SIZE * 1.2,
                    sides: 6,
                    angle: 30,
                    color: new Color().rgb(0xFF4136),
                    solid: true,
                    immediate: true,
                    depth: 6
                });
            }
        }

        if (enemy_capture_node != null) {
            var p = nodes[enemy_capture_node];
            if (p != null) {
                Luxe.draw.ngon({
                    x: p.position.x,
                    y: p.position.y,
                    r: NODE_SIZE + (NODE_SIZE * enemy_capture_time * 2),
                    sides: 6,
                    angle: 30 + 30 * enemy_capture_time,
                    color: new Color().rgb(0xFF4136),
                    solid: false,
                    immediate: true,
                    depth: 100
                });
            }
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

    function is_locked(n :GraphNode) {
        var required_keys = graph.get_keys_for_node(n);
        for (key in required_keys) {
            if (captured_nodes.indexOf(key) == -1) return true;
        }
        return false;
    }

    override function onkeydown(event :luxe.Input.KeyEvent) {
        if (capture_node != null) {
            // to avoid retriggering the capture
            if (event.keycode == node_entities[capture_node].key.toLowerCase().charCodeAt(0)) return;
        }
        for (n in graph.get_edges_for_node(current)) {
            if (enemy_in_game && (n == enemy_current)) continue; // cannot select enemy node
            if (!node_entities.exists(n)) continue; // if creation delay

            var entity = node_entities[n];
            if (event.keycode == entity.key.toLowerCase().charCodeAt(0)) {
                var already_captured = (captured_nodes.indexOf(n) >= 0);
                if (!already_captured && is_locked(n)) return;
                capture_time = (already_captured ? 0.2 : entity.capture_time);
                capture_node = n;
                return;
            }
        }
    }

    override function onkeyup(event :luxe.Input.KeyEvent) {
        if (capture_node == null) return;
        if (node_entities.exists(capture_node)) node_entities[capture_node].set_capture_text('');
        capture_node = null;
    }

    function select_node(node :GraphNode) {
        if (enemy_in_game && (node == enemy_current)) return; // cannot select enemy node

        if (captured_nodes.indexOf(node) < 0) captured_nodes.push(node);
        enemy_captured_nodes.remove(node);

        for (itembox in item_boxes) itembox.reset_position();

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
        var current_entity = node_entities[current];
        current_entity.color.rgb(0xF012BE); // .rgb(0xDD00FF);
        // current_entity.show_item('Trojan');
        add_linked_nodes(node);

        if (current.value == 'datastore') {
            got_data = true;
            Notification.Toast({
                text: 'DATA ACQUIRED\nRETURN TO EXTRACTION POINT',
                color: new Color(1, 0, 1),
                pos: new Vector(current_entity.pos.x, current_entity.pos.y - 120),
                duration: 10
            });
        } else if (current.value == 'start' && got_data) {
            trace('You won!');
            Luxe.renderer.clear_color.tween(1, { g: 1 });
        }

        Luxe.camera.shake(2);
        Main.bloom = 0.6;
        luxe.tween.Actuate.tween(Main, 0.4, { bloom: 0.4 });
    }

    function detected(node :GraphNode) {
        if (enemy_in_game || enemy_capture_node != null || enemy_current != null) return;

        enemy_current = node;
        enemy_capture_node = node;
        enemy_capture_time = 10;

        var detectionText = 'COUNTER MEASURES\nINITIATED!';
        if (countdown > 0) {
            countdownText.color.tween(1, { g: 0, b: 0 }).onComplete(function(_) {
                countdownText.color.tween(0.5, { b: 0.8 }).reflect().repeat();
            });
            countdown = -1;
            detectionText = 'DETECTED!';
        }
        Notification.Toast({
            text: detectionText,
            color: new Color(1, 0, 0),
            pos: node_entities[node].pos
        });

        Luxe.renderer.clear_color.tween(enemy_capture_time, { r: 0.4 });
        Luxe.camera.shake(5);
        Main.shift = 0.01;
        luxe.tween.Actuate.tween(Main, 0.3, { shift: 0.1 }).reflect().repeat(1);
    }

    var angle :Float = 0;
    override function update(dt :Float) {
        s.tick(dt * 10); // Hack to multiply dt

        var current_entity = node_entities[current];
        Luxe.camera.focus(current_entity.pos, 0.1);

        angle += dt;

        if (countdown > 0) {
            var minutes = Math.floor(countdown / 60);
            var seconds = Math.floor(countdown % 60);
            var miliseconds = Math.floor((countdown * 10) % 10);
            countdownText.text = (minutes < 10 ? '0' : '') + minutes + ':';
            countdownText.text += (seconds < 10 ? '0' : '') + seconds + ':';
            countdownText.text += (miliseconds < 10 ? '0' : '') + miliseconds;

            countdown -= dt;
            if (countdown <= 0) {
                countdownText.color.tween(1, { g: 0, b: 0 }).onComplete(function(_) {
                    countdownText.color.tween(0.5, { b: 0.8 }).reflect().repeat();
                });
            }
        }

        Luxe.camera.rotation.setFromAxisAngle(new Vector(1, 1, 0), Math.cos(angle) * 0.2);

        #if with_shader
        circuits_sprite.pos = Luxe.camera.center.clone();
        if (circuits_shader != null) circuits_shader.set_float('time', (Luxe.core.tick_start + dt) * 0.005);
        #end

        if (capture_node != null && capture_node != current) {
            capture_time -= dt;
            var capture_entity = node_entities[capture_node];
            var captured_by_player = (captured_nodes.indexOf(capture_node) > -1);

            if (!enemy_in_game) {
                if (captured_by_player) {
                    capture_entity.set_capture_text('0%');
                } else {
                    capture_entity.set_capture_text(capture_entity.detection + '%');
                }
            }
            if (capture_time <= 0) {
                capture_entity.set_capture_text('');
                for (lock in graph.get_locks_for_node(capture_node)) {
                    if (!node_entities.exists(lock)) continue;
                    node_entities[lock].set_capture_text('');
                }
                select_node(capture_node);

                if (!captured_by_player && Math.random() < capture_entity.detection / 100) {
                    detected(capture_node);
                }

                capture_node = null;
            }
        }

        if (enemy_capture_node != null) {
            enemy_capture_time -= dt;
            if (enemy_capture_time <= 0) {
                enemy_in_game = true;
                Luxe.camera.shake(5);
                luxe.tween.Actuate.tween(Main, 0.3, { shift: 0.1 }).reflect().repeat(1);

                enemy_current = enemy_capture_node;

                captured_nodes.remove(enemy_capture_node);
                if (node_entities.exists(enemy_capture_node)) {
                    node_entities[enemy_capture_node].color.set(0xFF0000);
                }
                if (enemy_capture_node == current) {
                    Luxe.camera.shake(10);
                    Luxe.renderer.clear_color.tween(0.3, { r: 0.9 });
                    luxe.tween.Actuate.tween(Main, 0.3, { shift: 0.2, bloom: 0.6 });
                    enemy_capture_node = null;
                    capture_node = null;
                    return;
                }
                enemy_captured_nodes.push(enemy_capture_node);
                var links = graph.get_edges_for_node(enemy_capture_node);
                enemy_capture_node = links.find(function(n) {
                    return (enemy_captured_nodes.indexOf(n) < 0); // uncaptured link
                });
                if (enemy_capture_node == null) enemy_capture_node = core.tools.ArrayTools.random(links);
                enemy_capture_time = 3;
            }
        }
    }
}
