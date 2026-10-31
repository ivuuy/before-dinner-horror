shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.3, 0.25, 0.18, 1.0);
uniform int surface_type = 0; // plaster / wood / wallpaper / tile / fabric
uniform float roughness_value = 0.86;
varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; wn = normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
    vec2 p = abs(wn.y) > 0.6 ? wp.xz : (abs(wn.x) > 0.6 ? wp.zy : wp.xy);
    float n = noise(p*6.0)*0.12 + noise(p*72.0)*0.055;
    vec3 col = tint.rgb * (0.79+n);
    if(surface_type==1) {
        float grain = sin(p.y*165.0 + noise(vec2(p.x*2.0,p.y*16.0))*7.0);
        vec2 board = vec2(p.x/2.0 + floor(p.y/0.24)*0.37,p.y/0.24);
        vec2 edge = min(fract(board),1.0-fract(board));
        float seams = smoothstep(0.0,0.012,edge.x)*smoothstep(0.0,0.025,edge.y);
        col *= (0.83+grain*0.09+hash(floor(board))*0.22)*mix(0.27,1.0,seams);
    }
    if(surface_type==2) {
        vec2 f = fract(p*4.2)-0.5;
        float stem = smoothstep(0.025,0.0,abs(f.x+sin(f.y*9.0)*0.07));
        float leaf = smoothstep(0.13,0.09,length(f*vec2(1.7,0.8)+vec2(sin(f.y*12.0)*0.13,0)));
        col *= 1.0-(stem+leaf)*0.13;
        col *= 0.9+0.1*smoothstep(0.2,1.5,wp.y);
    }
    if(surface_type==3) {
        vec2 f = fract(p*2.5); vec2 edge = min(f,1.0-f);
        float grout = smoothstep(0.008,0.025,min(edge.x,edge.y));
        col = mix(vec3(0.09,0.085,0.07),col*(0.8+hash(floor(p*2.5))*0.3),grout);
    }
    if(surface_type==4) { col *= 0.9+0.1*sin(p.x*500.0)*sin(p.y*500.0); }
    ALBEDO = col;
    ROUGHNESS = roughness_value;
}
