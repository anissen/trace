
#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D tex0;
uniform float time;
uniform vec2 tcoord;
uniform vec2 resolution;

// Cleaned up Source
const float speed     = 0.2;
const float frequency = 8.0;

vec2 shift( vec2 p ) {
    float d = time * speed;
    vec2 f = frequency * (p + d);
    vec2 q = cos( vec2(
       cos(f.x-f.y)*cos(f.y),
       sin(f.x+f.y)*sin(f.y) ) );
    return q;
}

void main() {
    vec2 r = gl_FragCoord.xy / resolution.xy;
    vec2 p = shift( r );
    vec2 q = shift(r + 1.0);
    float amplitude = 2.0 / resolution.x;
    vec2 s = r + amplitude * (p - q);
    s.y = 1. - s.y; // flip Y axis for ShaderToy
    gl_FragColor = texture2D(tex0, s);
}
