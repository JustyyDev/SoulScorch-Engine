#pragma header

// rely on common uniforms injected by engine header (iTime, etc.)
uniform float uIntensity;
uniform vec3 uTint;

void main() {
    vec2 uv = openfl_TextureCoordv;
    vec4 col = flixel_texture2D(bitmap, uv);

    // Horizontal hologram bands
    float bands = sin(uv.y * 120.0 + iTime * 3.0) * 0.5 + 0.5;
    col.rgb += bands * 0.06 * uIntensity;

    // Chromatic shimmer
    float shimmer = sin(iTime * 2.0 + uv.y * 10.0) * 0.01 * uIntensity;
    col.r = flixel_texture2D(bitmap, uv + vec2(shimmer, 0.0)).r;
    col.b = flixel_texture2D(bitmap, uv - vec2(shimmer, 0.0)).b;

    // Flicker
    float flicker = 0.92 + 0.08 * sin(iTime * 30.0);
    col.rgb *= flicker;

    // Tint (engine color)
    col.rgb = mix(col.rgb, col.rgb * uTint, 0.4 * uIntensity);

    gl_FragColor = col;
}
