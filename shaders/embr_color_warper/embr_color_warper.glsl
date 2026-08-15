uniform float adsk_result_w;
uniform float adsk_result_h;

uniform sampler2D front;
uniform sampler2D selective;

uniform vec3 pivot;
uniform float falloff;
uniform vec3 pin;
uniform float pin_falloff;
uniform float hue;
uniform float exposure;
uniform float saturation;
uniform vec3 cdl_slope;
uniform vec3 cdl_offset;
uniform vec3 cdl_power;
uniform float cdl_sat;
uniform float mix_amount;
uniform bool preview;

vec3 adsk_rgb2yuv(vec3 src);
vec3 adsk_yuv2rgb(vec3 src);
float adsk_getLuminance(vec3 color);

float chroma_weight(vec3 yuv, vec3 centre_yuv, float width)
{
    float w = 0.0;

    if (width > 0.000001)
    {
        vec2 dlt = vec2(yuv.y - centre_yuv.y, yuv.z - centre_yuv.z);
        float d = length(dlt);
        w = exp(-0.5 * (d / width) * (d / width));
    }

    return w;
}

float cdl_channel(float v, float slope, float off, float pwr)
{
    float sop = v * slope + off;
    return (sop > 0.0) ? pow(sop, pwr) : sop;
}

vec3 apply_cdl(vec3 rgb)
{
    vec3 powered = vec3(
        cdl_channel(rgb.x, cdl_slope.x, cdl_offset.x, cdl_power.x),
        cdl_channel(rgb.y, cdl_slope.y, cdl_offset.y, cdl_power.y),
        cdl_channel(rgb.z, cdl_slope.z, cdl_offset.z, cdl_power.z));
    float luma = adsk_getLuminance(powered);
    return mix(vec3(luma), powered, cdl_sat);
}

vec3 apply_warp(vec3 yuv, float w)
{
    vec2 chroma = vec2(yuv.y, yuv.z);
    float sat_mix = mix(1.0, saturation, w);
    float ang = hue * 0.01745329252 * w;
    float ca = cos(ang);
    float sa = sin(ang);
    vec2 rotated = vec2(
        chroma.x * ca - chroma.y * sa,
        chroma.x * sa + chroma.y * ca);

    return vec3(
        yuv.x * exp(exposure * w * 0.69314718),
        rotated.x * sat_mix,
        rotated.y * sat_mix);
}

void main(void)
{
    vec2 uv = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    vec4 src = texture2D(front, uv);
    vec3 src_yuv = adsk_rgb2yuv(src.rgb);
    float w_move = chroma_weight(src_yuv, adsk_rgb2yuv(pivot), falloff);
    float w_pin = chroma_weight(src_yuv, adsk_rgb2yuv(pin), pin_falloff);
    float w = w_move * (1.0 - w_pin);
    float amt = mix_amount * texture2D(selective, uv).r;

    vec3 cdl_rgb = mix(src.rgb, apply_cdl(src.rgb), w);
    vec3 warped = adsk_yuv2rgb(apply_warp(adsk_rgb2yuv(cdl_rgb), w));
    vec3 rgb = mix(src.rgb, warped, amt);

    if (preview)
    {
        rgb = mix(src.rgb, vec3(0.0, 1.0, 1.0), w_pin * amt * 0.35);
        rgb = mix(rgb, vec3(1.0, 0.0, 0.0), w * amt * 0.5);
    }

    gl_FragColor = vec4(rgb, src.a);
}
