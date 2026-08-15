uniform float adsk_result_w;
uniform float adsk_result_h;
uniform bool adsk_degrade;

uniform sampler2D adsk_results_pass12;

uniform int size;
uniform int softness;

int clamp_radius(int sz)
{
    int r = sz;
    if (r < 0)
        r = 0;
    if (r > 64)
        r = 64;
    if (adsk_degrade && r > 8)
        r = 8;
    return r;
}

int diamond_radius()
{
    int r = clamp_radius(size + softness);
    int s = int(float(r) * 0.41421356 + 0.5);
    int d = r - s;
    if (d < 0)
        d = 0;
    return d;
}

float morph_min(vec2 uv, vec2 step_px, int r)
{
    float acc = texture2D(adsk_results_pass12, uv).r;
    int i;
    for (i = -r; i <= r; i++)
        acc = min(acc, texture2D(adsk_results_pass12, uv + step_px * float(i)).r);
    return acc;
}

void main(void)
{
    vec2 uv = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    int r = diamond_radius();
    vec2 step_px = vec2(-1.0 / adsk_result_w, 1.0 / adsk_result_h);
    float v = morph_min(uv, step_px, r);
    gl_FragColor = vec4(v, v, v, v);
}
