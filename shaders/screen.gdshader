shader_type spatial;
render_mode unshaded;
uniform bool powered = false;
float hash(vec2 p) { return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453); }
void fragment() {
    float n=hash(floor(UV*vec2(280.0,200.0))+floor(TIME*22.0));
    float scan=0.7+0.3*sin(UV.y*640.0+TIME*4.0);
    float edge=pow(max(0.0,1.0-length((UV-0.5)*1.4)),0.4);
    ALBEDO = powered ? vec3(0.38,0.49,0.46)*n*scan*edge : vec3(0.014,0.024,0.025)*(0.5+UV.y);
    EMISSION = powered ? vec3(0.2,0.3,0.27)*n*edge : vec3(0.0);
}
