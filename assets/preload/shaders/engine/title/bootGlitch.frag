#pragma header

uniform float iTime;
uniform float uProgress; // 0 = hidden, 1 = fully revealed
uniform float uIntensity;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = openfl_TextureCoordv;
    float prog = clamp(uProgress, 0.0, 1.0);

    // Block displacement glitch that resolves as progress increases
    float glitchAmt = (1.0 - prog) * uIntensity;
    float blockY = floor(uv.y * 24.0);
    float r = hash(vec2(blockY, floor(iTime * 12.0)));
    float shift = (r - 0.5) * glitchAmt * 0.2 * step(0.6, r);
    uv.x += shift;

    // RGB split that fades out
    float split = glitchAmt * 0.03;
    vec4 col;
    col.r = flixel_texture2D(bitmap, uv + vec2(split, 0.0)).r;
    col.g = flixel_texture2D(bitmap, uv).g;
    col.b = flixel_texture2D(bitmap, uv - vec2(split, 0.0)).b;
    col.a = flixel_texture2D(bitmap, uv).a;

    // Scanline flash during transition
    float scan = sin(uv.y * 800.0 + iTime * 20.0) * 0.04 * (1.0 - prog);
    col.rgb += scan;

    // Reveal mask: pixels fade in from center as progress grows
    float mask = smoothstep(0.0, 1.0, prog * 1.5 - distance(uv, vec2(0.5)) * 0.8);
    col.a *= clamp(mask, 0.0, 1.0);

    gl_FragColor = col;
}
