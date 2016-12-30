
#ifdef GL_ES
precision mediump float;
#endif

uniform vec2 resolution;
uniform float time;
uniform sampler2D tex0;
varying vec2 tcoord;

// Does not work on Android (OpenGL ES)!
// http://stackoverflow.com/questions/4200224/random-noise-functions-for-glsl#comment22549967_4275343
// float rand(vec2 co) {
//     return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
// }

// Does not work on Android either...
// Source: http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0/
// float rand(vec2 co)
// {
//     float a = 12.9898;
//     float b = 78.233;
//     float c = 43758.5453;
//     float dt= dot(co.xy ,vec2(a,b));
//     float sn= mod(dt,3.14);
//     return fract(sin(sn) * c);
// }

const float bloom = 0.35;  // TODO make uniform input (bloom = good / points)
const float shiftOffset = 0.003; // TODO make uniform input (shift = bad / damage)
const float bloomDisp = 0.005; // Bloom image displacement
const float bloomColorSat = 2.0; // Bloom color satuation
const float vignetteAmount = 20.0;
const float scanlinesScrollSpeed = 8.0;
const float scanlinesScale = 900.0;
const float glitchChance = 0.01; //

void main(void)
{
    vec2 q = tcoord.xy / resolution.xy;
    vec2 uv = 0.5 + (q - 0.5);
    // vec2 uv = 0.5 + (q - 0.5) * (0.9 + 0.1 * sin(0.2 * time));
    vec3 col;
    vec4 sum = vec4(0);
    vec4 curcol = texture2D(tex0, q);
    float shift = shiftOffset;

    // neighbourhood interpolation for bloom
    sum += texture2D(tex0, vec2(-bloomDisp, -bloomDisp) + q) * bloomColorSat;
    sum += texture2D(tex0, vec2( bloomDisp, -bloomDisp) + q) * bloomColorSat;
    sum += texture2D(tex0, vec2(-bloomDisp,  bloomDisp) + q) * bloomColorSat;
    sum += texture2D(tex0, vec2( bloomDisp,  bloomDisp) + q) * bloomColorSat;
    // for(int i = -4; i < 4; i += 2) {
    //     for (int j = -4; j < 4; j += 2) {
    //         sum += texture2D(tex0, vec2(j,i) * 0.004 + q) * 0.25;
    //     }
    // }

    // electron beam shift (plus random distortion)
    // if (rand(vec2(1.0 - time, sin(time))) < glitchChance) {
    //     shift = 0.1 * rand(vec2(time, time));
    //     col.r = texture2D(tex0, vec2(uv.x + shift, uv.y)).x;
    //     col.g = texture2D(tex0, vec2(uv.x, uv.y)).y;
    //     col.b = texture2D(tex0, vec2(uv.x - shift, uv.y)).z;
    // } else {
        col = curcol.rgb;
    // }

    // col = clamp(col*0.5+0.5*col*col*1.2,0.0,1.0);          // tone curve
    col *= 0.3 + 0.7 * vignetteAmount * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y); // vignette
    // col *= vec3(0.7,1.0,0.6);                              // green tint
    col *= 0.95 + 0.05 * sin(scanlinesScrollSpeed * time + uv.y * scanlinesScale);        // scanlines
    // col *= 1.0 - 0.05 * rand(vec2(time, tan(time)));          // random flicker

    // bloom
    gl_FragColor = bloom * (sum * sum) * (1.0 - curcol.r) / 40.0 + vec4(col, 1.0);
}
