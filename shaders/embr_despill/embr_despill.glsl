uniform float adsk_result_w;
uniform float adsk_result_h;

uniform sampler2D front;
uniform sampler2D back;
uniform sampler2D matte;

uniform int screen;
uniform int algorithm;
uniform int cyan_mode;
uniform float amount;
uniform float fine_tune;
uniform float restore;
uniform float colour_amount;
uniform vec3 replace_colour;
uniform vec3 spill_colour;
uniform float background_amount;
uniform int view_mode;

float adsk_getLuminance(vec3 color);

float algorithm_cap(float a, float b)
{
    float cap = 0.5 * (a + b);

    if (algorithm == 1)
        cap = max(a, b);
    else if (algorithm == 2)
        cap = (a + 2.0 * b) / 3.0;
    else if (algorithm == 3)
        cap = (2.0 * a + b) / 3.0;
    else if (algorithm == 4)
        cap = b;
    else if (algorithm == 5)
        cap = a;

    return cap * fine_tune;
}

vec3 limit_green(vec3 rgb)
{
    rgb.g = min(rgb.g, algorithm_cap(rgb.r, rgb.b));
    return rgb;
}

vec3 limit_blue(vec3 rgb)
{
    rgb.b = min(rgb.b, algorithm_cap(rgb.r, rgb.g));
    return rgb;
}

vec3 limit_cyan_coupled(vec3 rgb)
{
    float avg = 0.5 * (rgb.g + rgb.b);
    float lim = rgb.r;

    if (algorithm == 4)
        lim = min(rgb.g, rgb.b);

    lim *= fine_tune;

    float factor = 1.0;
    if (avg > lim && avg > 0.000001)
        factor = lim / avg;

    rgb.g *= factor;
    rgb.b *= factor;
    return rgb;
}

vec3 limit_cyan_independent(vec3 rgb)
{
    vec3 limited = limit_green(rgb);
    limited.b = min(rgb.b, algorithm_cap(rgb.r, rgb.g));
    return limited;
}

vec3 gray_axis(void)
{
    return vec3(1.0 / sqrt(3.0));
}

vec3 rotate_around_gray(vec3 rgb, float ang)
{
    float c = cos(ang);
    float s = sin(ang);
    vec3 axis = gray_axis();
    return rgb * c + cross(axis, rgb) * s + axis * dot(axis, rgb) * (1.0 - c);
}

float chroma_angle_around_gray(vec3 rgb)
{
    vec3 axis = gray_axis();
    vec3 chroma = rgb - axis * dot(axis, rgb);
    vec3 e1 = vec3(1.0, -1.0, 0.0) * (1.0 / sqrt(2.0));
    vec3 e2 = cross(axis, e1);
    return atan(dot(chroma, e2), dot(chroma, e1));
}

vec3 limit_custom(vec3 rgb, vec3 key)
{
    vec3 limited = rgb;
    vec3 k = max(key, vec3(0.0));
    float key_mean = (k.r + k.g + k.b) * (1.0 / 3.0);

    if (length(k - vec3(key_mean)) > 0.000001)
    {
        float ang = chroma_angle_around_gray(vec3(0.0, 1.0, 0.0)) - chroma_angle_around_gray(k);
        limited = rotate_around_gray(limit_green(rotate_around_gray(rgb, ang)), -ang);
    }

    return limited;
}

vec3 apply_limit(vec3 rgb)
{
    vec3 limited = limit_green(rgb);

    if (screen == 1)
        limited = limit_blue(rgb);
    else if (screen == 2)
    {
        if (cyan_mode == 1)
            limited = limit_cyan_independent(rgb);
        else
            limited = limit_cyan_coupled(rgb);
    }
    else if (screen == 3)
        limited = limit_custom(rgb, spill_colour);

    return limited;
}

vec3 apply_replace(vec3 limited, vec3 back_rgb, float spill_amt)
{
    return limited
         + vec3(restore * spill_amt)
         + replace_colour * colour_amount * spill_amt
         + back_rgb * background_amount * spill_amt;
}

void main(void)
{
    vec2 uv = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    vec3 orig = texture2D(front, uv).rgb;
    vec3 back_rgb = texture2D(back, uv).rgb;
    float m = texture2D(matte, uv).r;
    vec3 limited = apply_limit(orig);
    vec3 spill_pos = max(orig - limited, vec3(0.0));
    vec3 restored = apply_replace(limited, back_rgb, adsk_getLuminance(spill_pos));
    vec3 rgb = mix(orig, restored, amount * m);

    if (view_mode == 1)
        rgb = spill_pos;
    else if (view_mode == 2)
        rgb = orig - limited;

    gl_FragColor = vec4(rgb, 1.0);
}
