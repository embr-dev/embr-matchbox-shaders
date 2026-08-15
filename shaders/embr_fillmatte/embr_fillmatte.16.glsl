uniform float adsk_result_w;
uniform float adsk_result_h;
uniform bool adsk_degrade;

uniform sampler2D matte;
uniform sampler2D adsk_results_pass5;
uniform sampler2D adsk_results_pass15;

uniform bool preview;
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

float blur_1d(vec2 uv, vec2 step_px, int r)
{
    float acc = 0.0;
    int n = 2 * r + 1;
    int i;
    for (i = -r; i <= r; i++)
        acc += texture2D(adsk_results_pass15, uv + step_px * float(i)).r;
    return acc / float(n);
}

void main(void)
{
    vec2 uv = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    float m = texture2D(matte, uv).r;
    float fill = texture2D(adsk_results_pass5, uv).r;
    float edge = blur_1d(uv, vec2(0.0, 1.0 / adsk_result_h), clamp_radius(softness));
    float comp = mix(fill, m, edge);
    vec3 rgb = vec3(comp);

    if (preview)
        rgb = mix(vec3(m), vec3(1.0, 0.0, 0.0), edge * 0.5);

    gl_FragColor = vec4(rgb, comp);
}
