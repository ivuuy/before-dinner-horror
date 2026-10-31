shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float lit = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
void fragment() {
    vec2 p = UV;
    float tree = smoothstep(0.09,0.015,abs(p.x-0.28-sin(p.y*8.0)*0.025));
    tree += smoothstep(0.04,0.012,abs(p.x-0.72+sin(p.y*11.0)*0.04));
    float night = 0.45+0.55*p.y;
    vec3 col = mix(vec3(0.035,0.059,0.073),vec3(0.11,0.17,0.20),night);
    col *= 1.0-min(tree,1.0)*0.7;
    vec2 grid = vec2(p.x*85.0,p.y*7.0+TIME*0.7);
    float streak = pow(1.0-abs(fract(grid.x)-0.5)*2.0,18.0);
    streak *= smoothstep(0.4,1.0,hash(vec2(floor(grid.x),floor(grid.y)))) * (1.0-fract(grid.y));
    col += vec3(0.14,0.2,0.24)*streak;
    ALBEDO = col+vec3(lit);
}
