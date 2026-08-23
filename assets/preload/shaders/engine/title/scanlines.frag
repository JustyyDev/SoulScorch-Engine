#pragma header

// rely on common uniforms injected by engine header (iTime, etc.)
uniform float uIntensity;
uniform float uBeat;

void main() {
    vec2 uv = openfl_TextureCoordv;
    vec4 col = flixel_texture2D(bitmap, uv);

    // CRT scanlines
    float scan = sin(uv.y * 800.0) * 0.5 + 0.5;
    col.rgb *= 1.0 - (scan * 0.08 * uIntensity);

    // Soft vignette
    float d = distance(uv, vec2(0.5));
    float vig = smoothstep(0.85, 0.35, d);
    col.rgb *= mix(1.0, vig, uIntensity * 0.6);

    // Subtle beat pulse brightness
    col.rgb *= 1.0 + uBeat * 0.05;

    gl_FragColor = col;
}
