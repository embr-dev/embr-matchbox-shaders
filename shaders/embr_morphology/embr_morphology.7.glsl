uniform float adsk_result_w;
uniform float adsk_result_h;
uniform bool adsk_degrade;

uniform sampler2D adsk_results_pass6;
uniform sampler2D strength;
uniform int mode;
uniform int size;
uniform float angle;
uniform int kernel;
uniform int channel;

float adsk_getLuminance(vec3 color);

vec2 step_from_angle(float deg)
{
    float a = deg * 0.01745329252;
    return vec2(cos(a) / adsk_result_w, sin(a) / adsk_result_h);
}

int clamp_radius(int sz)
{
    int r = sz;
    if (r < 0)
        r = -r;
    if (r > 256)
        r = 256;
    if (adsk_degrade && r > 8)
        r = 8;
    return r;
}

int apply_strength(int r, vec2 uv)
{
    float str = clamp(texture2D(strength, uv).r, 0.0, 1.0);
    return int(float(r) * str + 0.5);
}

int kernel_radius(int r, int kern, int along_diag)
{
    int rs = r;
    int rd = 0;

    if (kern != 2)
    {
        if (along_diag != 0)
            rs = 0;
    }
    else
    {
        rs = int(float(r) * 0.41421356 + 0.5);
        if (along_diag != 0)
        {
            rd = r - rs;
            if (rd < 0)
                rd = 0;
            rs = rd;
        }
    }
    return rs;
}

vec3 apply_luma(vec3 rgb, float y_new)
{
    float y = adsk_getLuminance(rgb);
    vec3 out_rgb = vec3(y_new);

    if (y >= 0.000001)
        out_rgb = rgb * (y_new / y);
    return out_rgb;
}

vec3 morph_1d(sampler2D src, vec2 uv, vec2 step_px, int r, bool use_max, int ch)
{
    vec3 center = texture2D(src, uv).rgb;
    vec3 acc = center;
    float y_acc = 0.0;
    int i;

    if (ch == 1)
        y_acc = adsk_getLuminance(center);

    for (i = -r; i <= r; i++)
    {
        vec3 s = texture2D(src, uv + step_px * float(i)).rgb;
        if (ch == 1)
        {
            float ys = adsk_getLuminance(s);
            if (use_max)
                y_acc = max(y_acc, ys);
            else
                y_acc = min(y_acc, ys);
        }
        else
        {
            if (use_max)
                acc = max(acc, s);
            else
                acc = min(acc, s);
        }
    }

    if (ch == 1)
        acc = apply_luma(center, y_acc);
    return acc;
}

void main(void)
{
    vec2 uv = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    vec3 result = texture2D(adsk_results_pass6, uv).rgb;
    int r = 0;
    bool use_max = (size < 0);

    if (mode == 1 && size != 0 && kernel == 2)
    {
        r = apply_strength(kernel_radius(clamp_radius(size), kernel, 1), uv);
        result = morph_1d(adsk_results_pass6, uv, step_from_angle(angle + 45.0), r, use_max, channel);
    }

    gl_FragColor = vec4(result, 1.0);
}
