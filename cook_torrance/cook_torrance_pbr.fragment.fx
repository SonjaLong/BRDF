precision highp float;

// Varying
varying vec3 vPosition;
varying vec3 vNormal;
varying vec2 vUV;

// Uniforms
uniform mat4 world;

// Refs
uniform vec3 cameraPosition;
uniform sampler2D albedoMap;

const float PI = 3.14159265359;

                       
float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a      = roughness*roughness;
    float a2     = a*a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;	
    float num   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
	
    return num / denom;
}
float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float num   = NdotV;
    float denom = NdotV * (1.0 - k) + k;
	
    return num / denom;
}
float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2  = GeometrySchlickGGX(NdotV, roughness);
    float ggx1  = GeometrySchlickGGX(NdotL, roughness);	
    return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
} 
void main(void) {
    
    vec3 lightColor = mainLightColor * lightIntensity;

    vec3 vPositionW = vec3(world * vec4(vPosition, 1.0));
    vec3 N = normalize(vec3(world * vec4(vNormal, 0.0)));
    vec3 V  = normalize(cameraPosition - vPositionW);

    //base albedo and base normal
    vec3 albedo_base = texture(albedoMap, vUV).rgb;
    vec3 normalMap = normalize(texture2D(nrmMap, vUV).rgb * 2. - 1.);
    //normalMap.xy = normalMap.xy * scale;
    normalMap = normalize(normalMap);
    mat3 TBN = cotangent_frame(N, -V, vUV);
    vec3 nrm_base = normalize(TBN * normalMap);
    float maskVl = texture2D(mask, vUV).r;

    //lighting
    vec3 L = normalize(lightPosition - vPositionW);
    vec3 H = normalize(V + L);
    float distance    = length(lightPosition - vPositionW);
    float attenuation = 1.0 / (distance * distance);
    vec3 radiance     = lightColor * attenuation;

    //brdf for base material
    vec3 F0 = vec3(0.04); 
    F0      = mix(F0, albedo_base, metallic);
    vec3 Lo = vec3(0.0);
    vec3 F  = fresnelSchlick(max(dot(nrm_base, V), 0.0), F0);
    F = F * 0.5;
    float NDF = DistributionGGX(nrm_base, H, roughness);       
    float G   = GeometrySmith(nrm_base, V, L, roughness);

    //diffuse irradiance
    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= (1.0 - metallic);
    vec2 uv = SampleSphericalMap(normalize(vPosition));
    vec3 irradiance = texture2D(irradianceMap, uv).rgb;
    vec3 diffuse    = irradiance * albedo_base;
    vec3 color = vec3(0.0);
    float NdotL = max(dot(nrm_base, L), 0.0);

    vec3 numerator    = NDF * G * F;
    float denominator = 4.0 * max(dot(nrm_base, V), 0.0) * max(dot(nrm_base, L), 0.0);
    vec3 specular     = numerator / max(denominator, 0.001);
        
    vec3 ambient = (kD * diffuse + Tspecular * temp) * ao; 
        
    Lo = (kD * albedo_base / PI + specular) * radiance * NdotL;
    color   = ambient + Lo;

    // HDR tonemapping
    color = color / (color + vec3(1.0));
    // gamma correct
    color = pow(color, vec3(1.0/2.2)); 
    
    gl_FragColor = vec4(color, 1.);
}