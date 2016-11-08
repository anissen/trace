
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
    var fixParticle :Particle;
    var particles :Array<Particle>;

    var nodes :Map<core.models.Graph.Node<String>, luxe.Visual>;

    public function new() {
        super({ name: StateId });
        particles = [];
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

        nodes = new Map();
        // test
        var graph = core.models.Graph.Test.get_graph();
        for (n in graph.get_nodes()) {
            var pos = new Vector(Luxe.screen.w * Math.random(), Luxe.screen.h * Math.random());
            var node = new luxe.Visual({
                pos: new Vector(Luxe.screen.w * Math.random(), Luxe.screen.h * Math.random()),
                geometry: Luxe.draw.circle({ r: 30 })
            });
            new luxe.Text({
                text: n.value,
                color: new Color(0, 0, 0),
                align: center,
                align_vertical: center,
                parent: node
            });
            nodes[n] = node;
        }
        for (n in graph.get_nodes()) {
            for (l in graph.get_links_for_node(n)) {
                Luxe.draw.line({
                    p0: nodes[n].pos,
                    p1: nodes[l].pos,
                    color: new Color(1, 0, 0)
                });
            }
        }

        setup_particles();
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

    // var centroidX :Float = 0.0;
    // var centroidY :Float = 0.0;
    // var scale :Float = 1.0;

    var NODE_SIZE :Float = 10;
    var EDGE_LENGTH :Float = 50;
    var EDGE_STRENGTH :Float = 0.2;
    var SPACER_STRENGTH :Float = 1000;

    // function updateCentroid() {
    //     var xMax = Math.NEGATIVE_INFINITY;
    //     var xMin = Math.POSITIVE_INFINITY;
    //     var yMin = Math.POSITIVE_INFINITY;
    //     var yMax = Math.NEGATIVE_INFINITY;
    //
    //     for (p in particles) {
    //         xMax = Math.max(xMax, p.position.x);
    //         xMin = Math.min(xMin, p.position.x);
    //         yMin = Math.min(yMin, p.position.y);
    //         yMax = Math.max(yMax, p.position.y);
    //     }
    //     var deltaX = xMax - xMin;
    //     var deltaY = yMax - yMin;
    //
    //     centroidX = xMin + 0.5 * deltaX;
    //     centroidY = yMin + 0.5 * deltaY;
    //
    //     if (Luxe.screen.height / deltaY < Luxe.screen.width / deltaX) {
    //         scale = Luxe.screen.height / (deltaY + 50);
    //     } else {
    //         scale = Luxe.screen.width / (deltaX + 50);
    //     }
    // }

    function addSpacersToNode(p :Particle, r :Particle) {
        for (q in particles) {
            if (p != q && p != r) {
                s.makeAttraction( p, q, -SPACER_STRENGTH, 20 );
            }
        }
    }

    function makeEdgeBetween(a :Particle, b :Particle) {
        s.makeSpring( a, b, EDGE_STRENGTH, EDGE_STRENGTH, EDGE_LENGTH );
    }

    function initialize() {
        s.clear();
        addNode();
    }

    function addNode() {
        var p :Particle = s.makeParticle();
        if (particles.length > 0) {
            var q :Particle = s.getParticle(Math.floor((s.numberOfParticles()-1) * Math.random()));
            while (q == p) {
                q = s.getParticle(Math.floor((s.numberOfParticles()-1) * Math.random()));
            }
            addSpacersToNode( p, q );
            makeEdgeBetween( p, q );
            p.position = new Vector3D(q.position.x -1 + 2 * Math.random(), q.position.y -1 + 2 * Math.random(), 0);
        }
        particles.push(p);
    }

    override function onenter(_) {
        // Luxe.camera.zoom = 0.10;
        // luxe.tween.Actuate.tween(Luxe.camera, 1.0, { zoom: 1 });

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
        // if (particles.length > 0) trace(particles[0]);
        // Luxe.draw.poly({
        //     points: [ for (p in particles) new Vector(p.position.x, p.position.y) ],
        //     solid: false,
        //     immediate: true
        // });

        for (i in 0 ... s.numberOfSprings()) {
            var e :Spring = s.getSpring(i);
            var a :Particle = e.getOneEnd();
            var b :Particle = e.getTheOtherEnd();

            Luxe.draw.line({
                p0: new Vector(a.position.x, a.position.y),
                p1: new Vector(b.position.x, b.position.y),
                immediate: true
            });
        }

        for (p in particles) {
            Luxe.draw.ngon({
                x: p.position.x,
                y: p.position.y,
                r: 10,
                sides: 6,
                color: new Color(1, 0, 1, 1),
                solid: true,
                immediate: true
            });
        }
        /*
        //for (p in p_fixed) {
            Luxe.draw.circle({
                pos: new Vector(fixParticle.position.x, fixParticle.position.y),
                r: 30,
                immediate: true,
                color: new Color(0, 0, 1)
            });
        //}
        */

        if (particles.length > 0) {
            Luxe.camera.pos = new Vector(particles[0].position.x - Luxe.screen.width / 2, particles[0].position.y - Luxe.screen.height / 2);

            // TODO: should be fixed to the current node
            // Luxe.camera.pos = new Vector(centroidX - Luxe.screen.width / 2, centroidY - Luxe.screen.height / 2);
            // Luxe.camera.zoom = scale;
        }
    }
    override function onmousemove(event :MouseEvent) {

    }

    override function onmousedown(event :MouseEvent) {
        addNode();
    }

    override function update(dt :Float) {
        s.tick(dt * 10); // Hack to multiply dt
        // if (s.numberOfParticles() > 1) updateCentroid();
    }
}
