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

    public function mark_pattern(pattern :Graph<T>) {
        // find first node
        trace('pattern node 0: ${pattern.nodes[0].value}');
        var current_node = nodes.find(function(n) { return (n.value == pattern.nodes[0].value); });
        if (current_node == null) {
            trace('No node with ID ${pattern.nodes[0].value}');
            return;
        }

        current_node.id = pattern.nodes[0].id;
        for (i in 1 ... pattern.nodes.length) {
             trace('pattern node $i: ${pattern.nodes[i].value}');
            current_node = get_linked_node_with_value(current_node, pattern.nodes[i].value);
            if (current_node == null) {
                trace('No node (#$i) with ID ${pattern.nodes[i].value}');
                return;
            }
            current_node.id = pattern.nodes[i].id;
        }
    }

    public function replace(pattern :Graph<T>, replacement :Graph<T>) {
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
        trace('-------');
        trace('Step 1 & Step 2: Mark nodes');
        mark_pattern(pattern);
        print();

        trace('-------');
        trace('Step 3: Remove links');
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

        trace('-------');
        trace('Step 4: Replace nodes');
        for (n in marked) {
            n.value = replacement.get_node_from_id(n.id).value;
        }
        print();

        trace('-------');
        trace('Step 5: Add new nodes');
        for (r in replacement.nodes) {
            var node = get_node_from_id(r.id);
            if (node == null) {
                create_node(r.value, r.id);
            }
        }
        print();

        trace('-------');
        trace('Step 6: Add edges');
        for (r in replacement.nodes) {
            var node = get_node_from_id(r.id);
            for (l in replacement.get_links_for_node(r)) {
                link(node, get_node_from_id(l.id));
            }
        }
        print();

        trace('-------');
        trace('Step 7: Remove ids');
        for (n in nodes) {
            n.id = null;
        }
        print();
    }

    public function print() {
        for (n in nodes) {
            trace('[${n.to_string()}]');
            for (l in get_links_for_node(n)) trace('${n.to_string()} -> ${l.to_string()}');
        }
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
