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

class Graph<T> {
    var nodes :Array<Node<T>>;
    var links :Map<Node<T>, Array<Node<T>>>;

    public function new() {
        nodes = [];
        links = new Map();
    }

    public function create_node(value :T, ?id :Int) :Node<T> {
        var node = new Node(value, id);
        add_node(node);
        return node;
    }

    public function add_node(node :Node<T>) {
        nodes.push(node);
        links[node] = [];
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
        if (links[a].indexOf(b) < 0) links[a].push(b);
        if (links[b].indexOf(a) < 0) links[b].push(a);
    }

    public function unlink(a :Node<T>, b :Node<T>) {
        links[a].remove(b);
        links[b].remove(a);
    }

    public function get_links_for_node(node :Node<T>) {
        return links[node];
    }

    public function get_linked_node_with_value(node :Node<T>, value :T) {
        return links[node].find(function(l) { return (l.value == value); });
    }

    public function mark_pattern(pattern :Graph<T>) :Bool {
        // find first node
        trace('pattern node 0: ${pattern.nodes[0].value}');
        var first_nodes = nodes.filter(function(n) { return (n.value == pattern.nodes[0].value); });
        core.tools.ArrayTools.shuffle(first_nodes);
        for (n in first_nodes) {
            if (try_mark_pattern(n, pattern)) return true;
        }
        return false;
    }

    function try_mark_pattern(first :Node<T>, pattern :Graph<T>) {
        var current_node = first;
        current_node.id = pattern.nodes[0].id;
        for (i in 1 ... pattern.nodes.length) {
            trace('pattern node $i: ${pattern.nodes[i].value}');
            var links = get_links_for_node(current_node);
            current_node = get_linked_node_with_value(current_node, pattern.nodes[i].value);
            if (current_node == null) {
                trace('No node (#$i) with ID ${pattern.nodes[i].value}');
                trace('Linked nodes are:');
                for (l in links) {
                    trace('-> ${l.to_string()}');
                }
                return false;
            }
            current_node.id = pattern.nodes[i].id;
        }
        return true;
    }

    public function replace(pattern :Graph<T>, replacement :Graph<T>) :Bool {
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
        if (!mark_pattern(pattern)) {
            // reset ID's
            for (n in nodes) n.id = null;
            return false;
        }
        print();

        // trace('-------');
        // trace('Step 3: Remove links');
        var marked = nodes.filter(function(n) { return (n.id != null); });
        for (n in marked) {
            // removed links to all other marked
            for (l in get_links_for_node(n)) {
                if (l.id != null) {
                    unlink(n, l);
                }
            }
        }
        print();

        // trace('-------');
        // trace('Step 4: Replace nodes');
        for (n in marked) {
            n.value = replacement.get_node_from_id(n.id).value;
        }
        print();

        // trace('-------');
        // trace('Step 5: Add new nodes');
        for (r in replacement.nodes) {
            var node = get_node_from_id(r.id);
            if (node == null) {
                create_node(r.value, r.id);
            }
        }
        print();

        // trace('-------');
        // trace('Step 6: Add edges');
        for (r in replacement.nodes) {
            var node = get_node_from_id(r.id);
            for (l in replacement.get_links_for_node(r)) {
                link(node, get_node_from_id(l.id));
            }
        }
        print();

        // trace('-------');
        // trace('Step 7: Remove ids');
        for (n in nodes) {
            n.id = null;
        }
        print();

        return true;
    }

    public function print() {
        for (n in nodes) {
            // trace('[${n.to_string()}]');
            for (l in get_links_for_node(n)) trace('${n.to_string()} -> ${l.to_string()}');
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
            for (l in get_links_for_node(n)) {
                if (visited.indexOf(l) >= 0) continue;
                str += n.to_string() + ' -> ' + l.to_string() + '\n';
                str += print_recursive_walk(l) + '\n';
            }
            return str;
        }

        trace(print_recursive_walk(start));
    }

}

class Test {
    public static function get_graph() {
        var g = new Graph();
        var A = g.create_node('A');
        var B = g.create_node('B');
        var b = g.create_node('b');
        var a1 = g.create_node('a1');
        var a2 = g.create_node('a2');
        g.link(A, B);
        g.link(A, b);
        g.link(B, a1);
        g.link(B, a2);
        g.print();

        g.replace(get_graph_pattern(), get_graph_replacement());

        return g;
    }

    static function get_graph_pattern() {
        var g = new Graph();
        var A = g.create_node('A', 1);
        var B = g.create_node('B', 2);
        g.link(A, B);
        return g;
    }

    static function get_graph_replacement() {
        var g = new Graph();
        var A = g.create_node('A', 2);
        var B = g.create_node('B', 4);
        var b = g.create_node('b', 3);
        var a = g.create_node('a', 1);
        g.link(A, B);
        g.link(B, b);
        g.link(b, a);
        return g;
    }
}

class Test2 {
    public static function get_graph() {
        var g = new Graph();
        var start = g.create_node('start');
        var r1 = g.create_node('room');
        var r2 = g.create_node('room');
        var r3 = g.create_node('room');
        var r4 = g.create_node('room');
        var goal = g.create_node('goal');
        g.link(start, r1);
        g.link(r1, r2);
        g.link(r2, r3);
        g.link(r3, r4);
        g.link(r4, goal);

        trace('Before replace');
        g.print_walk(start);
        var r = g.replace(get_graph_pattern(), get_graph_replacement());
        trace('Did replace: $r');

        trace('After 1st replace');
        g.print_walk(start);

        r = g.replace(get_graph_pattern(), get_graph_replacement2());
        trace('Did replace: $r');

        trace('After 2nd replace');
        g.print_walk(start);

        /*
        var pattern_replacements :Array<{ pattern :Graph<String>, replacements :Array<Graph<String>> }> = [];
        pattern_replacements.push({ pattern: get_graph_pattern(), replacements: [get_graph_replacement(), get_graph_replacement2()]});
        pattern_replacements.push({ pattern: get_graph_pattern_lock(), replacements: [get_graph_replace_lock()]});

        var replacements = 0;
        var max_replacements = 10;
        while (replacements < max_replacements) {
            var replacements_this_pass = 0;
            core.tools.ArrayTools.shuffle(pattern_replacements);
            for (pair in pattern_replacements) {
                core.tools.ArrayTools.shuffle(pair.replacements);
                for (replacement in pair.replacements) {
                    if (g.replace(pair.pattern, replacement)) {
                        replacements++;
                        replacements_this_pass++;
                    }
                    if (replacements > max_replacements) break;
                }
                if (replacements > max_replacements) break;
            }
            if (replacements_this_pass == 0) break;
        }
        trace('Made $max_replacements replacements!');
        */

        return g;
    }

    // start
    // room
    // -> room_locked -> gate -> dataserver -> goal
    // room -> room_key

    static function get_graph_pattern() {
        var g = new Graph();
        var A = g.create_node('room', 1);
        var B = g.create_node('room', 2);
        g.link(A, B);
        return g;
    }

    static function get_graph_replacement() {
        var g = new Graph();
        var A = g.create_node('room', 1);
        var B = g.create_node('room_locked', 2);
        var b = g.create_node('room_key', 3);
        g.link(A, B);
        g.link(A, b);
        return g;
    }

    static function get_graph_replacement2() {
        var g = new Graph();
        var A = g.create_node('gate', 1);
        var B = g.create_node('dataserver', 2);
        g.link(A, B);
        return g;
    }

    static function get_graph_pattern_lock() {
        var g = new Graph();
        var A = g.create_node('room_key', 1);
        var B = g.create_node('room_locked', 2);
        g.link(A, B);
        return g;
    }

    static function get_graph_replace_lock() {
        var g = new Graph();
        var A = g.create_node('room', 1);
        var B = g.create_node('room_key', 3);
        var C = g.create_node('room_locked', 2);
        g.link(A, B);
        g.link(A, C);
        return g;
    }
}
