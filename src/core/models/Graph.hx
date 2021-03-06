package core.models;

using Lambda;

class Node<T> {
    public var value :T;
    public var id :Null<Int>;

    public function new(value :T, ?id :Int) {
        this.value = value;
        this.id = id;
    }

    public function to_string() {
        return (id != null ? '$id:$value' : '$value');
    }
}

enum ReferenceType {
    Edge(bidirectional :Bool);
    Key;
}

class Reference<T, R> {
    public var a :Node<T>;
    public var b :Node<T>;
    public var type :R;

    public function new(a :Node<T>, b :Node<T>, type: R) {
        this.a = a;
        this.b = b;
        this.type = type;
    }
}

class Graph<T> {
    var nodes :Array<Node<T>>;
    var key_ref :Map<Node<T>, Node<T>>;
    var references :Array<Reference<T, ReferenceType>>;
    public var name :Null<String> = null;

    public function new(?name :String) {
        this.name = name;
        nodes = [];
        key_ref = new Map();

        references = [];
    }

    public function create_node(value :T, ?id :Int) :Node<T> {
        var node = new Node(value, id);
        add_node(node);
        return node;
    }

    public function add_node(node :Node<T>) {
        nodes.push(node);
    }

    public function get_nodes() {
        return nodes;
    }

    public function get_node(value :T) {
        return nodes.find(function(n) { return (n.value == value); });
    }

    public function get_node_from_id(id :Int) {
        return nodes.find(function(n) { return (n.id == id); });
    }

    public function link(a :Node<T>, b :Node<T>) { // bidirectional link
        references.push(new Reference(a, b, Edge(true)));
    }

    public function unlink(a :Node<T>, b :Node<T>) {
        for (r in references) {
            if ((r.a == a || r.b == a) && (r.a == b || r.b == b)) {
                references.remove(r);
            }
        }
    }

    public function key_link(a :Node<T>, b :Node<T>) {
        references.push(new Reference(a, b, Key));
    }

    public function get_references() {
        return references;
    }

    public function get_edges() {
        return references.filter(function(r) {
            return switch (r.type) {
                case Edge(_): true;
                case _: false;
            }
        });
    }

    public function get_edges_for_node(node :Node<T>) {
        return references
            .filter(function(r) {
                return switch (r.type) {
                    case Edge(false): (r.a == node);                 // unidirectional
                    case Edge(true):  (r.a == node || r.b == node);  // bidirectional
                    case _: false;
                }
            })
            .map(function(r) { return (node == r.a ? r.b : r.a); });
    }

    public function get_keys_for_node(node :Node<T>) {
        return references
            .filter(function(r) { return (r.type == Key && r.b == node); })
            .map(function(r) { return r.a; });
    }

    public function get_locks_for_node(node :Node<T>) {
        return references
            .filter(function(r) { return (r.type == Key && r.a == node); })
            .map(function(r) { return r.b; });
    }

    public function mark_pattern(pattern :Graph<T>, random :Int->Int) :Bool {
        var first_nodes = nodes.filter(function(n) { return (n.value == pattern.nodes[0].value); });
        core.tools.ArrayTools.shuffle(first_nodes, random);
        for (n in first_nodes) {
            if (try_mark_pattern(n, pattern)) return true;
            for (n in pattern.nodes) n.id = null; // mark pattern failed, reset marks
        }
        return false;
    }

    function try_mark_pattern(first :Node<T>, pattern :Graph<T>) {
        var current_node = first;
        current_node.id = pattern.nodes[0].id;
        for (i in 1 ... pattern.nodes.length) {
            current_node = get_edges_for_node(current_node).find(function(n) { return (n.value == pattern.nodes[i].value); });
            if (current_node == null) return false;
            current_node.id = pattern.nodes[i].id;
        }
        return true;
    }

    public function replace(pattern :Graph<T>, replacement :Graph<T>, random :Int->Int) :Bool {
        /*
        Step 1: Select a group of nodes for replacement as described by a particular rule
        Step 2: The selected nodes are numbered according to the left-hand side of the rule.
        Step 3: All edges between the selected nodes are removed.
        Step 4: The numbered nodes are then replaced by their equivalents (nodes with the same number) on the right-hand side of the rule.
        Step 5: Any nodes on the right-hand side that do not have an equivalent on the left-hand side are added to the graph.
        Step 6: The edges connecting the new nodes are put into the graph as specified by the right-hand side of the rule.
        Step 7: The numbers are removed.
        */

        // Step 1: Select group of nodes for replacement
        // Step 2: Rename nodes according to pattern
        // trace('-------');
        // trace('Step 1 & Step 2: Mark nodes');
        if (!mark_pattern(pattern, random)) {
            // reset ID's
            for (n in nodes) n.id = null;
            return false;
        }
        // print();

        // trace('-------');
        // trace('Step 3: Remove links');
        var marked = nodes.filter(function(n) { return (n.id != null); });
        for (n in marked) {
            // removed links to all other marked
            for (l in get_edges_for_node(n)) {
                if (l.id != null) {
                    unlink(n, l);
                }
            }
        }
        // print();

        // trace('-------');
        // trace('Step 4: Replace nodes');
        for (n in marked) {
            n.value = replacement.get_node_from_id(n.id).value;
        }
        // print();

        // trace('-------');
        // trace('Step 5: Add new nodes');
        for (r in replacement.nodes) {
            var node = get_node_from_id(r.id);
            if (node == null) {
                create_node(r.value, r.id);
            }
        }
        // print();

        // trace('-------');
        // trace('Step 6: Add edges');
        for (r in replacement.references) {
            var node1 = get_node_from_id(r.a.id);
            var node2 = get_node_from_id(r.b.id);
            switch (r.type) {
                case Edge(false): throw 'Not yet implemented!';                 // unidirectional
                case Edge(true): link(node1, node2);  // bidirectional
                case Key: key_link(node1, node2);
            }
        }
        // print();

        // trace('-------');
        // trace('Step 7: Remove ids');
        for (n in nodes) {
            n.id = null;
        }
        // print();

        return true;
    }

    public function print() {
        for (n in nodes) {
            // trace('[${n.to_string()}]');
            for (l in get_edges_for_node(n)) trace('${n.to_string()} -> ${l.to_string()}');
        }
    }

    // start -> room_key -> room_locked -> goal
    // room_locked -> blah
    // start -> room
    public function print_walk(start :Node<T>) {
        var visited :Array<Node<T>> = [];

        function print_recursive_walk(n :Node<T>) {
            if (visited.indexOf(n) >= 0) return '';
            visited.push(n);

            var str = '';
            for (l in get_edges_for_node(n)) {
                if (visited.indexOf(l) >= 0) continue;
                str += n.to_string() + ' -> ' + l.to_string() + '\n';
                str += print_recursive_walk(l) + '\n';
            }
            return str;
        }

        trace(print_recursive_walk(start));
    }

}

class Factory {
    public static function create_graph(?random :Int->Int) {
        if (random == null) random = Std.random;

        var g = new Graph();
        var start = g.create_node('start');
        var ds1 = g.create_node('datastore');
        var chainStart1 = g.create_node('ChainStart');
        var key1 = g.create_node('key');
        var chainEnd1 = g.create_node('ChainEnd');
        var chainStart2 = g.create_node('ChainStart');
        var chainEnd2 = g.create_node('ChainEnd');
        var ds2 = g.create_node('datastore');
        var lock1 = g.create_node('lock');
        // var ds1 = g.create_node('datastore');

        // var chain3 = g.create_node('Chain');
        // var chain4 = g.create_node('ChainWithKey');
        // var key2 = g.create_node('key');
        // var lock2 = g.create_node('lock');
        // var ds2 = g.create_node('datastore');
        var goal = g.create_node('goal');

        g.link(start, ds1);

        // chain set 1
        g.link(start, chainStart1);
        g.link(chainStart1, chainEnd1);
        g.link(chainEnd1, key1);

        g.link(start, chainStart2);
        g.link(chainStart2, chainEnd2);

        g.link(chainEnd1, lock1);
        g.link(chainEnd2, lock1);
        g.link(lock1, ds2);

        g.key_link(key1, lock1);

        // chain set 2
        var chainStart3 = g.create_node('ChainStart');
        var key2 = g.create_node('key');
        var chainEnd3 = g.create_node('ChainEnd');
        var chainStart4 = g.create_node('ChainStart');
        var chainEnd4 = g.create_node('ChainEnd');
        var lock2 = g.create_node('lock');

        g.link(lock1, chainStart3);
        g.link(chainStart3, chainEnd3);
        g.link(chainEnd3, key2);

        g.link(lock1, chainStart4);
        g.link(chainStart4, chainEnd4);

        g.link(chainEnd3, lock2);
        g.link(chainEnd4, lock2);

        g.link(lock2, goal);

        g.key_link(key2, lock2);

        var pattern_replacements :Array<{ pattern :Graph<String>, replacements :Array<Graph<String>> }> = [];
        pattern_replacements.push({ pattern: chain_pattern(), replacements: [chain_replacement1(), chain_replacement2(), chain_replacement3()]});
        pattern_replacements.push({ pattern: nodes_pattern(), replacements: [nodes_replacement3(), nodes_replacement2(), nodes_replacement1()]});

        var replacements = 0;
        var max_replacements = 10;
        while (replacements < max_replacements) {
            var replacements_this_pass = 0;
            core.tools.ArrayTools.shuffle(pattern_replacements, random);
            for (pair in pattern_replacements) {
                core.tools.ArrayTools.shuffle(pair.replacements, random);
                for (replacement in pair.replacements) {
                    if (g.replace(pair.pattern, replacement, random)) {
                        trace('Replaced "${pair.pattern.name}" with ${replacement.name}');
                        // trace('Made a replacement with:');
                        // trace('Pattern:'); pair.pattern.print();
                        // trace('Replacement:'); replacement.print();
                        replacements++;
                        replacements_this_pass++;

                        // Test: remove replacement to avoid loops
                        pair.replacements.remove(replacement);
                    }
                    if (replacements >= max_replacements) break;
                }
                if (replacements >= max_replacements) break;
            }
            if (replacements_this_pass == 0) {
                trace('No more available patterns found!');
                break;
            }
        }
        trace('Made $replacements replacements!');
        // g.print_walk(start);

        return g;
    }

    static function chain_pattern() {
        var g = new Graph('chain_pattern');
        var A = g.create_node('ChainStart', 1);
        var B = g.create_node('ChainEnd', 2);
        g.link(A, B);
        return g;
    }

    static function chain_replacement1() {
        var g = new Graph('chain_replacement1');
        var A = g.create_node('node', 1);
        var B = g.create_node('node', 2);
        g.link(A, B);
        return g;
    }

    static function chain_replacement2() {
        var g = new Graph('chain_replacement2');
        var A = g.create_node('node', 1);
        var B = g.create_node('node', 2);
        var C = g.create_node('node', 3);
        g.link(A, B);
        g.link(A, C);
        return g;
    }

    static function chain_replacement3() {
        var g = new Graph('chain_replacement3');
        var A = g.create_node('node', 1);
        var B = g.create_node('node', 3);
        var C = g.create_node('node', 2);
        g.link(A, B);
        g.link(B, C);
        return g;
    }

    static function nodes_pattern() {
        var g = new Graph('nodes_pattern');
        var A = g.create_node('node', 1);
        var B = g.create_node('node', 2);
        g.link(A, B);
        return g;
    }

    static function nodes_replacement1() {
        var g = new Graph('nodes_replacement1');
        var A = g.create_node('node', 1);
        var B = g.create_node('key', 3);
        var C = g.create_node('lock', 2);
        g.link(A, B);
        g.link(A, C);
        g.key_link(B, C);
        return g;
    }

    static function nodes_replacement2() {
        var g = new Graph('nodes_replacement2');
        var A = g.create_node('node', 1);
        var B = g.create_node('lock', 3);
        var C = g.create_node('datastore', 4);
        var D = g.create_node('key', 2);
        g.link(A, B);
        g.link(B, C);
        g.link(A, D);
        g.key_link(D, B);
        return g;
    }

    static function nodes_replacement3() {
        var g = new Graph('nodes_replacement3');
        var A = g.create_node('datastore', 1);
        var B = g.create_node('node', 2);
        g.link(A, B);
        return g;
    }
}
