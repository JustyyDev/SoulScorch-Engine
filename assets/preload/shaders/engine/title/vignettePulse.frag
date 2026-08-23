#pragma header

uniform float iTime;
uniform float uBeat;
uniform vec3 uColor;

void main() {
    vec2 uv = openfl_TextureCoordv;
    vec4 col = flixel_texture2D(bitmap, uv);

    float d = distance(uv, vec2(0.5));
    float vig = smoothstep(0.9, 0.2, d);
    float pulse = 1.0 + uBeat * 0.15;
    col.rgb *= mix(1.0, vig * pulse, 0.5);

    // Edge glow in engine color on beat
    float edge = smoothstep(0.35, 0.5, d) * uBeat * 0.3;
    col.rgb += uColor * edge;

    gl_FragColor = col;
}
