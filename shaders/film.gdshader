shader_type canvas_item;
uniform float danger = 0.0;
uniform float darkness = 0.0;
void fragment() {
    vec2 p = UV-0.5;
    float vig = smoothstep(0.18,0.73,length(p*vec2(0.85,1.0)));
    float grain = fract(sin(dot(UV+vec2(TIME),vec2(12.9898,78.233)))*43758.5453);
    float alpha = vig*(0.45+danger*0.35)+grain*0.023+darkness;
    COLOR = vec4(vec3(danger*0.13,0.006,0.004),min(alpha,0.97));
}
