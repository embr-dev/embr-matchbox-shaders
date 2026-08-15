uniform float adsk_result_w;
uniform float adsk_result_h;

uniform sampler2D adsk_results_pass9;
uniform sampler2D adsk_results_pass13;

void main(void)
{
    vec2 uv = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    float dilated = texture2D(adsk_results_pass9, uv).r;
    float eroded = texture2D(adsk_results_pass13, uv).r;
    float edge = max(dilated - eroded, 0.0);
    gl_FragColor = vec4(edge, edge, edge, edge);
}
