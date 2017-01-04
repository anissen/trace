
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
import core.tools.PromiseQueue;
import game.entities.Notification;
import game.entities.ItemBox;

import core.physics.*;

using Lambda;

typedef GraphNode = core.models.Graph.Node<String>;
typedef TutorialData = { id: String, texts :Array<String>, entity :luxe.Entity };

class WorldState extends State {
    static public var StateId :String = 'WorldState';

    var paused :Bool;
    var game_over :Bool;

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

    var enemy_icon :Sprite;

    var honeypots :Array<GraphNode>;
    var nuked :Array<GraphNode>;

    var got_data :Bool;

    var node_entities :Map<GraphNode, game.entities.Node>;

    var countdownText :Text;
    var countdown :Float;

    var stopwatchIcon :Sprite;

    var ui_batcher :phoenix.Batcher;

    var item_boxes :Array<ItemBox>;
    var capture_item_boxes :Array<ItemBox>;
    var max_item_boxes :Int = 2;

    var random :luxe.utils.Random;

    var countdownFunctions :Array<{ time :Float, func :Void->Void }>;
    var tutorial_entity :luxe.Entity;
    var start_node :GraphNode;

    var promise_queue :PromiseQueue<TutorialData>;

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

        ui_batcher = Luxe.renderer.create_batcher({
            name: 'ui',
            layer: 500
        });
    }

    function add_linked_nodes(n :GraphNode) {
        var delay = 0.0;
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
                delayed_function(function() {
                    var p = add_node();
                    node_entities[l] = create_node_entity(p, l);
                    nodes[l] = p;
                    add_edge(p, nodes[n]);
                }, delay);
                delay += 0.5;
            }
        }
    }

    function delayed_function(func :Void->Void, delay :Float) {
        countdownFunctions.push({ time: delay, func: func });
    }

    function create_node_entity(p :Particle, n :GraphNode) {
        var detection = 10;
        var capture_time = 1.5;
        var texture = null;
        var description = ['N/A'];
        switch (n.value) {
            case 'start':
                texture = Luxe.resources.texture('assets/images/black-flag.png');
            case 'goal':
                detection = 20;
                capture_time = 3;
                texture = Luxe.resources.texture('assets/images/database.png');
            case 'datastore':
                detection = 20;
                capture_time = 3;
                texture = Luxe.resources.texture('assets/images/database.png');
                description = ['DATASTORES can be hacked to gain access to useful data.', 'One of the DATASTORES in the network\nholds the DATA you\'re after.', 'The other DATASTORES provide you\nwith useful abilities when hacked.', 'Be aware that DATASTORES are\nrisky and time consuming to hack.'];
            case 'node':
                // default values
                description = ['NODES are nondescript computers in the network.'];
            case 'lock':
                detection = 5;
                texture = Luxe.resources.texture('assets/images/finger-print.png');
                description = ['LOCKS are nodes that require a user certificate to access.'];
            case 'key':
                texture = Luxe.resources.texture('assets/images/id-card.png');
                description = ['KEYS are nodes that contain a user\ncertificate for a specific LOCK', 'Once hacked, the corresponding LOCK will be accessible.'];
        }

        if (available_keys.length == 0) {
            available_keys = 'ABCDEFGHIJKLMNOPQRSTUVXYZ'.split(''); // HACK
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
            key: available_keys.splice(random.int(available_keys.length), 1)[0],
            detection: detection,
            capture_time: capture_time
        });

        if (is_locked(n)) {
            entity.set_capture_text('?');
        }

        if (n.value == 'start') {
            tutorial('node-type-start', entity, ['Welcome to the hacking interface.\n\n     [Press <Enter> to continue]', 'Each node in the graph represents a\ncomputer in the network.', 'Your goal is to find and extract DATA\nfrom the master DATASTORE.', 'You hack nodes by holding down\nthe key shown on the node.']).then(function() {
                paused = false;
            });
            tutorial('node-type-timer', entity, ['You need to act quickly!', 'When the timer runs out a TRACE will be initiated.', 'If you get caught by the TRACE you will get\nlocked out of the system and fail your mission.']);
        } else if (n.value == 'node' || n.value == 'lock' || n.value == 'key' || n.value == 'datastore') {
            tutorial('node-type-${n.value}', entity, ['This node is of type ${n.value.toUpperCase()}.'].concat(description));
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
         s.setDrag(0.5);

         initialize();
    }

    var NODE_SIZE :Float = 50;
    var EDGE_LENGTH :Float = 200;
    var EDGE_STRENGTH :Float = 2;
    var SPACER_STRENGTH :Float = 20000;

    function addSpacersToNode(p :Particle, r :Particle) {
        for (q in s.particles) {
            if (p != q && p != r) {
                var attraction = s.makeAttraction( p, q, 0, 50 );
                luxe.tween.Actuate.update(attraction.setStrength, 0.5, [0], [-SPACER_STRENGTH]);
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
        luxe.tween.Actuate.tween(Luxe.camera, 0.7, { zoom: 1 });

        promise_queue = new PromiseQueue();
        promise_queue.set_handler(tutorial_to_promise);

        var bg_texture = Luxe.resources.texture('assets/images/background.png');
        bg_texture.clamp_s = phoenix.Texture.ClampType.repeat;
        bg_texture.clamp_t = phoenix.Texture.ClampType.repeat;
        bg_texture.width = 3000;
        bg_texture.height = 3000;
        new Sprite({
            texture: bg_texture,
            // size: Vector.Multiply(Luxe.screen.size, 10),
            color: new Color(0.5, 1, 0.5, 0.2),
            depth: -100
        });

        overlay_filter = new Sprite({
            centered: false,
            pos: new Vector(0, 0),
            texture: Luxe.resources.texture('assets/images/overlay_filter.png'),
            size: Luxe.screen.size.clone(),
            batcher: overlay_batcher,
            depth: 1000
        });
        overlay_filter.color.a = 0.8;

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

        game_over = false;

        nodes = new Map();
        node_entities = new Map();
        random = new luxe.utils.Random(Math.random() /* TODO: Use seed */);

        countdownFunctions = [];
        tutorial_entity = null;

        enemy_icon = null;

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

        honeypots = [];
        nuked = [];

        countdownText = new Text({
            text: '--:--:--',
            pos: new Vector(Luxe.screen.mid.x, 50),
            point_size: 64,
            align: center,
            align_vertical: center,
            batcher: ui_batcher
        });

        stopwatchIcon = new Sprite({
            pos: new Vector(Luxe.screen.w * 0.70, 55),
            texture: Luxe.resources.texture('assets/images/hazard-sign.png'),
            scale: new Vector(0.25, 0.25),
            batcher: ui_batcher
        });

        // test
        graph = core.models.Graph.Factory.create_graph(random_int);

        setup_particles();

        item_boxes = [];
        capture_item_boxes = [];

        start_node = graph.get_node('start');
        select_node(start_node);

        countdown = 60;

        delayed_function(function() {
            detected(start_node);
        }, countdown);

        paused = true;
    }

    /* Tutorial TODO:
    - items
    - the TRACE
    */

    override function onleave(_) {
        Luxe.scene.empty();
    }

    override function onrender() {
        var current_linked_nodes = (current == null ? [] : graph.get_edges_for_node(current));

        for (r in graph.get_references()) {
            if (!node_entities.exists(r.a) || !node_entities.exists(r.b)) continue;

            if (r.type == Key && captured_nodes.indexOf(r.a) == -1) { // locked node with discovered (uncaptured) key
                Luxe.draw.line({
                    p0: node_entities[r.a].pos,
                    p1: node_entities[r.b].pos,
                    color: new Color(0, 1, 0, 0.3),
                    immediate: true,
                    depth: 5
                });
            } else if (r.type != Key) {
                var is_linked_to = ((r.a == current && current_linked_nodes.indexOf(r.b) != -1) || (r.b == current && current_linked_nodes.indexOf(r.a) != -1));

                Luxe.draw.line({
                    p0: node_entities[r.a].pos,
                    p1: node_entities[r.b].pos,
                    immediate: true,
                    color: new Color(1, 1, 1, (is_locked(r.b) ? 0.05 : (is_linked_to ? 1 : 0.3))),
                    depth: 5
                });
            }
        }

        for (itembox in item_boxes) {
            itembox.visible(false);
        }
        if (current != null) {
            var p = nodes[current];
            if (node_entities.exists(current) && capture_node == null) {
                var current_entity_pos = node_entities[current].pos;
                for (itembox in item_boxes) {
                    itembox.visible(true);
                    itembox.pos = current_entity_pos.clone();
                }
            }
            Luxe.draw.ngon({
                x: p.position.x,
                y: p.position.y,
                r: NODE_SIZE * 1.15,
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

    function handle_item(name :String) {
        switch (name) {
            // capture
            case 'Scan':
                if (capture_node != null) add_linked_nodes(capture_node);
            case 'Trojan':
                if (capture_node != null) {
                    // ensure old node text is cleared when using trojan
                    node_entities[capture_node].set_capture_text('');
                    select_node(capture_node);
                }
                capture_node = null;
            // node
            case 'Enforce':
                if (node_entities.exists(current)) {
                    var entity = node_entities[current];
                    if (entity.enforced) return;
                    entity.enforced = true;
                    entity.capture_time += 5;
                    if (enemy_capture_node == current) {
                        enemy_capture_time += 5;
                    }
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
                };
            case 'Honeypot':
                if ((honeypots.indexOf(current) < 0) && node_entities.exists(current)) {
                    var entity = node_entities[current];
                    honeypots.push(current);
                    entity.honeypot = new luxe.Sprite({
                        pos: new Vector(0, 70),
                        texture: Luxe.resources.texture('assets/images/honeypot.png'),
                        scale: new Vector(0.25, 0.25),
                        color: new Color(1, 0.3, 1),
                        parent: entity,
                        depth: 50
                    });
                }
            case 'Nuke':
                if ((nuked.indexOf(current) < 0) && node_entities.exists(current)) {
                    var entity = node_entities[current];
                    nuked.push(current);
                    entity.nuked(true);
                    var nukeSprite = new luxe.Sprite({
                        texture: Luxe.resources.texture('assets/images/mushroom-cloud.png'),
                        scale: new Vector(0.35, 0.35),
                        color: new Color(1, 0, 0),
                        parent: entity,
                        depth: 11
                    });
                    if (enemy_capture_node == current) {
                        if (!enemy_in_game) {
                            enemy_capture_node = null;
                        } else {
                            enemy_capture_node = get_enemy_capture_node(enemy_current);
                            enemy_capture_time = get_enemy_capture_time();
                        }
                    }
                    var current_copy = current; // to ensure a local copy of current for the delayed function
                    delayed_function(function() {
                        nukeSprite.destroy();
                        entity.set_capture_text('UP: 3s');
                    }, 17);
                    delayed_function(function() {
                        entity.set_capture_text('UP: 2s');
                    }, 18);
                    delayed_function(function() {
                        entity.set_capture_text('UP: 1s');
                    }, 19);
                    delayed_function(function() {
                        entity.nuked(false);
                        nuked.remove(current_copy);
                        if (enemy_capture_node == null) {
                            enemy_capture_node = current_copy;
                            enemy_capture_time = get_enemy_capture_time();
                        }
                    }, 20);
                }
        }
    }

    override function onkeydown(event :luxe.Input.KeyEvent) {
        if (tutorial_entity != null) return;

        if (event.keycode >= luxe.Input.Key.key_0 && event.keycode <= luxe.Input.Key.key_9) {
            var items = ((capture_node != null) ? capture_item_boxes : item_boxes);
            var index = switch (event.keycode) {
                case luxe.Input.Key.key_1: 0;
                case luxe.Input.Key.key_2: 1;
                case luxe.Input.Key.key_3: 2;
                case luxe.Input.Key.key_4: 3;
                case _: -1;
            }
            var item = items.find(function(i) { return (i.index == index); });
            if (item == null) return;
            play_sound('use_item.wav');
            handle_item(item.item);
            items.remove(item);
            item.destroy();
            return;
        }

        if (capture_node != null) {
            // to avoid retriggering the capture
            if (event.keycode == node_entities[capture_node].key.toLowerCase().charCodeAt(0)) return;
        }
        for (n in graph.get_edges_for_node(current)) {
            if (enemy_in_game && (n == enemy_current)) continue; // cannot select enemy node
            if (nuked.indexOf(n) > -1) continue; // cannot select nuked node
            if (!node_entities.exists(n)) continue; // if creation delay

            var entity = node_entities[n];
            if (event.keycode == entity.key.toLowerCase().charCodeAt(0)) {
                var already_captured = (captured_nodes.indexOf(n) >= 0);
                if (!already_captured && is_locked(n)) return;
                capture_time = (already_captured ? 0.2 : entity.capture_time);
                capture_node = n;

                tutorial('detection-risk', entity, ['Hacking a node involves a risk of detection.\nThe risk is shown in the node label.', 'If the breach is detected, a TRACE will\nbe initiated at the comprimised node.']);

                var i = Luxe.utils.random.int(1, 3);
                play_sound('click$i.wav');
                return;
            }
        }
    }

    override function onkeyup(event :luxe.Input.KeyEvent) {
        if (capture_node == null || tutorial_entity != null) return;
        switch (event.keycode) {
            case luxe.Input.Key.key_1: return;
            case luxe.Input.Key.key_2: return;
            case luxe.Input.Key.key_3: return;
            case luxe.Input.Key.key_4: return;
            case _:
        }
        if (node_entities.exists(capture_node)) node_entities[capture_node].set_capture_text('');
        capture_node = null;
    }

    function select_node(node :GraphNode) {
        if (enemy_in_game && (node == enemy_current)) return; // cannot select enemy node
        if (nuked.indexOf(node) > -1) return; // cannot select nuked node

        if (current != null && node_entities.exists(current)) {
            var entity = node_entities[current];
            entity.color.rgb(0x2ECC40); // .rgb(0x44FF44);
        }

        current = node;

        // ensure linked nodes are cleared of others
        var current_particle = nodes[current];
        for (spring in s.springs) {
            if (spring.getOneEnd() == current_particle || spring.getTheOtherEnd() == current_particle) {
                spring.setRestLength(EDGE_LENGTH);
            } else {
                spring.setRestLength(EDGE_LENGTH * 1.5);
            }
        }

        if (!nodes.exists(node)) {
            nodes[node] = add_node();
        }
        var p = nodes[current];
        if (!node_entities.exists(node)) {
            node_entities[node] = create_node_entity(p, node);
        }
        var current_entity = node_entities[current];
        current_entity.color.rgb(0xF012BE); // .rgb(0xDD00FF);
        add_linked_nodes(node);

        if (current.value == 'goal' && !got_data) {
            got_data = true;
            tutorial('data acquired', current_entity, ['DATA acquired!']).then(function() {
                tutorial('data acquired 2', node_entities[start_node], ['Return to the EXTRACTION NODE.']).then(function() {
                    Notification.Toast({
                        text: 'DATA ACQUIRED\nRETURN TO EXTRACTION NODE',
                        color: new Color(1, 0, 1),
                        pos: new Vector(current_entity.pos.x, current_entity.pos.y - 120),
                        duration: 10
                    });
                });
            });
            play_sound('pickup.wav');
        } else if (current.value == 'start' && got_data) {
            play_sound('game_over.wav');
            Luxe.renderer.clear_color.tween(1, { g: 1 });
            game_over = true;
            countdownFunctions = [];
            delayed_function(function() {
                Main.states.set(MenuState.StateId, 'DATA EXTRACTED\nSUCCESSFULLY!\n\nRETRY?');
            }, 3);
        } else if (current.value == 'datastore') {
            if (captured_nodes.indexOf(current) == -1) { // new datastore
                gain_random_item(current_entity.pos);
            }
        }

        if (captured_nodes.indexOf(node) < 0) {
            play_sound('capture.wav');
            captured_nodes.push(node);
        } else {
            play_sound('select.wav');
        }
        enemy_captured_nodes.remove(node);

        for (itembox in item_boxes) itembox.reset_position();

        Luxe.camera.shake(2);
        Main.bloom = 0.6;
        luxe.tween.Actuate.tween(Main, 0.4, { bloom: 0.4 });
    }

    function play_sound(id :String) {
        var sound = Luxe.resources.audio('assets/sounds/$id');
        Luxe.audio.play(sound.source);
    }

    function gain_random_item(pos :Vector) {
        var list = item_boxes; // node items
        if (random.bool()) list = capture_item_boxes; // capture items instead

        if (list.length >= 4) {
            Notification.Toast({
                text: 'CAPACITY FULL',
                color: new Color(1, 0, 1),
                pos: new Vector(pos.x, pos.y - 120),
                duration: 8
            });
            return;
        }
        list.sort(function(a, b) {
            return a.index - b.index;
        });
        var index = 0;
        for (l in list) {
            if (index < l.index) break;
            if (l.index == index) index++;
        }
        var item :ItemBox = null;
        var description = 'N/A';
        if (list == item_boxes) {
            item = switch (random.int(3)) {
                case 0: description = 'increase the time it takes the TRACE to\ncapture the node.';
                new ItemBox({
                    item: 'Enforce',
                    texture: Luxe.resources.texture('assets/images/shieldcomb.png'),
                    index: index
                });
                case 1: description = 'lure the TRACE to capture the node.';
                new ItemBox({
                    item: 'Honeypot',
                    texture: Luxe.resources.texture('assets/images/honeypot.png'),
                    index: index
                });
                case 2: description = 'take the node completely offline for\n20 seconds.';
                new ItemBox({
                    item: 'Nuke',
                    texture: Luxe.resources.texture('assets/images/mushroom-cloud.png'),
                    index: index
                });
                case _: throw 'Error';
            }
        } else {
            item = switch (random.int(2)) {
                case 0: description = 'reveal the network of the node.';
                new ItemBox({
                    item: 'Scan',
                    texture: Luxe.resources.texture('assets/images/radar-sweep.png'),
                    inverted: true,
                    index: index
                });
                case 1: description = 'instantly capture the node without detection.';
                new ItemBox({
                    item: 'Trojan',
                    texture: Luxe.resources.texture('assets/images/trojan-horse.png'),
                    inverted: true,
                    index: index
                });
                case _: throw 'Error';
            }
        }

        play_sound('pickup.wav');

        var item_name = item.item.toUpperCase();

        tutorial(item.item, node_entities[current], ['$item_name ability acquired.', item_name + ' can be used ' + (item.inverted ? 'when capturing a node to\n' : 'on the active node to\n') + description]).then(function() {
            tutorial('any_item_usage', node_entities[current], ['Abilities are used by pressing their corresponding key.']);
        }).then(function() {
            Notification.Toast({
                text: '$item_name ACQUIRED',
                color: new Color(1, 0, 1),
                pos: new Vector(pos.x, pos.y - 120),
                duration: 8
            });
        });

        list.push(item);
    }

    function tutorial_to_promise(data :TutorialData) {
        tutorial_entity = data.entity;
        luxe.tween.Actuate.tween(Luxe, 0.3, { timescale: 0.1 });
        var infobox = new game.entities.InfoBox({
            depth: 1000,
            duration: data.texts.length * 4,
            scene: Luxe.scene,
            texts: data.texts
        });
        infobox.get_promise().then(function() {
            tutorial_entity = null;
            luxe.tween.Actuate.tween(Luxe, 0.1, { timescale: 1.0 });
        });
        data.entity.add(infobox);
        return infobox.get_promise();
    }

    function tutorial(id :String, entity :luxe.Entity, texts :Array<String>) {
        if (Luxe.io.string_load(id) != null) return Promise.resolve();
        Luxe.io.string_save(id, 'done');

        return promise_queue.handle({ id: id, entity: entity, texts: texts });
    }

    function detected(node :GraphNode) {
        if (enemy_in_game || enemy_capture_node != null || enemy_current != null) return;

        enemy_current = node;
        enemy_capture_node = node;
        enemy_capture_time = 10;

        var detectionText = 'TRACE INITIATED!';
        var tutorialTexts = ['A TRACE has been initiated at the EXTRACTION NODE'];
        if (countdown >= 0) {
            countdownText.color.tween(1, { g: 0, b: 0 }).onComplete(function(_) {
                countdownText.color.tween(0.5, { b: 0.8 }).reflect().repeat();
            });
            countdown = -1;
            detectionText = 'DETECTED!';
            tutorialTexts = ['You have been detected!', 'A TRACE has been initiated at your location.'];
        }
        tutorial('detected', node_entities[enemy_current], tutorialTexts.concat(['Once initiated, the TRACE will proceed to search the network.', 'Evade the TRACE and finish your mission!'])).then(function() {
            Notification.Toast({
                text: detectionText,
                color: new Color(1, 0, 0),
                pos: node_entities[node].pos
            });
        });

        play_sound('alarm.wav');

        // flash warning icon
        stopwatchIcon.color = new Color(1, 0, 0);
        stopwatchIcon.color.tween(0.5, { b: 0.8 }).reflect().repeat();

        Luxe.renderer.clear_color.tween(enemy_capture_time, { r: 0.4 });
        Luxe.camera.shake(5);
        Main.shift = 0.01;
        luxe.tween.Actuate.tween(Main, 0.3, { shift: 0.1 }).reflect().repeat(1);
    }

    var angle :Float = 0;
    override function update(dt :Float) {
        if (paused) return;

        for (c in countdownFunctions) {
            c.time -= dt;
            if (c.time <= 0) {
                countdownFunctions.remove(c);
                c.func();
            }
        }

        if (game_over) return;

        s.tick(dt * 10); // Hack to multiply dt

        Luxe.camera.focus((tutorial_entity != null ? tutorial_entity.pos : node_entities[current].pos), 0.1);

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
                countdownText.text = '00:00:00';
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

                if (!captured_by_player && random.get() < capture_entity.detection / 100) {
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

                // captured_nodes.remove(enemy_capture_node);
                if (node_entities.exists(enemy_capture_node)) {
                    var enemy_capture_entity = node_entities[enemy_capture_node];
                    enemy_capture_entity.color.set(0xFF0000);
                    if (enemy_capture_entity.honeypot != null) enemy_capture_entity.honeypot.destroy();

                    if (enemy_icon == null) {
                        enemy_icon = new luxe.Sprite({
                            pos: enemy_capture_entity.pos,
                            texture: Luxe.resources.texture('assets/images/spider-bot.png'),
                            scale: new Vector(0.35, 0.35),
                            color: new Color(0.7, 0, 0),
                            depth: 50
                        });
                    }
                }
                if (enemy_capture_node == current) {
                    play_sound('game_over.wav');
                    Luxe.camera.shake(10);
                    Luxe.renderer.clear_color.tween(0.3, { r: 0.9 });
                    luxe.tween.Actuate.tween(Main, 0.3, { shift: 0.2, bloom: 0.6 });
                    enemy_capture_node = null;
                    capture_node = null;
                    game_over = true;
                    countdownFunctions = [];
                    delayed_function(function() {
                        Main.states.set(MenuState.StateId, 'YOU GOT CAUGHT\n\nRETRY?');
                    }, 3);
                    return;
                }
                enemy_captured_nodes.push(enemy_capture_node);
                honeypots.remove(enemy_capture_node);

                play_sound('enemy_capture.wav');

                enemy_capture_node = get_enemy_capture_node(enemy_capture_node);
                enemy_capture_time = get_enemy_capture_time();
            }
        }

        if (enemy_icon != null && enemy_current != null) {
            if (node_entities.exists(enemy_current)) {
                var enemy_capture_entity = node_entities[enemy_current];
                enemy_icon.pos.lerp(enemy_capture_entity.pos, 10 * dt);
            }
        }
    }

    function get_enemy_capture_node(from :GraphNode) {
        var links = graph.get_edges_for_node(from);
        links = links.filter(function(n) {
            return (nuked.indexOf(n) < 0);
        });

        if (links.length == 0) return null;

        links.sort(function(a, b) { // always choose honeypots first
            // positive if a should come before b (see http://try.haxe.org/#3440f)
            // a honeypot: 2, -1
            // b honeypot: -1, 2
            // both honeypot: 2, 1
            // no honeypot: -1, -1
            return (honeypots.indexOf(b) - honeypots.indexOf(a));
        });
        var node = links.find(function(n) {
            return (enemy_captured_nodes.indexOf(n) < 0); // uncaptured link
        });
        if (node != null) return node;

        node = links.find(function(n) { // pick a honeypot, if possible
            return (honeypots.indexOf(n) > -1);
        });
        if (node != null) return node;

        // just pick a random node
        return core.tools.ArrayTools.random(links, random_int);
    }

    function random_int(max :Int) {
        return random.int(max);
    }

    function get_enemy_capture_time() {
        if (enemy_capture_node != null && node_entities.exists(enemy_capture_node)) {
            var enemy_capture_entity = node_entities[enemy_capture_node];
            return enemy_capture_entity.capture_time * 1.5;
        } else {
            return 3;
        }
    }
}
