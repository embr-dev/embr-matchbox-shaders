uniform float adsk_result_w;
uniform float adsk_result_h;

uniform sampler2D matte;

uniform float linear_low;
uniform float linear_high;
uniform int close_size;
uniform int size;
uniform int softness;
uniform bool preview;

float linearstep(float lo, float hi, float x)
{
    float v = 0.0;
    float span = hi - lo;

    if (span <= 0.0)
    {
        if (x >= lo)
            v = 1.0;
    }
    else
        v = clamp((x - lo) / span, 0.0, 1.0);

    return v;
}

void main(void)
{
    vec2 uv = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    float m = texture2D(matte, uv).r;
    float v = linearstep(linear_low, linear_high, m);

    v += float(close_size + size + softness) * 0.0;
    if (preview)
        v += 0.0;

    gl_FragColor = vec4(v, v, v, v);
}
