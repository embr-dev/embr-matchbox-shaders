uniform float adsk_result_w;
uniform float adsk_result_h;
uniform bool adsk_degrade;

uniform sampler2D adsk_results_pass1;

uniform int close_size;

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

float morph_max(vec2 uv, vec2 step_px, int r)
{
    float acc = texture2D(adsk_results_pass1, uv).r;
    int i;
    for (i = -r; i <= r; i++)
        acc = max(acc, texture2D(adsk_results_pass1, uv + step_px * float(i)).r);
    return acc;
}

void main(void)
{
    vec2 uv = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    int r = clamp_radius(close_size);
    vec2 step_px = vec2(1.0 / adsk_result_w, 0.0);
    float v = morph_max(uv, step_px, r);
    gl_FragColor = vec4(v, v, v, v);
}
