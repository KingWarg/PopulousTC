// -------------------------------------------------------------
// Compilation switches (should be defined by the host app.)
// -------------------------------------------------------------
//#define LINEAR_INTERPOLATION
//#define HERMITE_INTERPOLATION

// -------------------------------------------------------------
// Semantic mappings
// -------------------------------------------------------------
float4x4 matWorldIT : WORLDIT;
float4x4 matWorldViewProjection : WORLDVIEWPROJ;

float3 horizonColor : AMBIENT;
float3 overHorizonColor : DIFFUSE;
float3 midSkyColor : SPECULAR;
float3 zenithColor : EMISSIVE;

int fogType : FOGTYPE = 1;
float3 belowHorizonColor : FOGCOLOR;

// -------------------------------------------------------------
// Textures & Samplers
// -------------------------------------------------------------
texture texClouds : TEXTURE0;
sampler sampClouds = sampler_state {
	Texture = (texClouds);
};

// -------------------------------------------------------------
// Parameters
// -------------------------------------------------------------
float2 cloudsTiling = {1, 1};
float2 cloudsTranslation = {0, 0};
float4 cloudsColor = {1, 1, 1, 1};

// -------------------------------------------------------------
// Constants
// -------------------------------------------------------------
#define HORIZON_LEVEL      0.0175f
#define OVER_HORIZON_LEVEL 0.035f
#define MID_SKY_LEVEL      0.15f
#define ZENITH_LEVEL       0.375f

#define CLOUD_FALLOFF_STEP_1  0.1111111f
#define CLOUD_FALLOFF_STEP_2  0.4444444f

// -------------------------------------------------------------
// Input/Output channels
// -------------------------------------------------------------
struct VS_INPUT 
{
	float4 position : POSITION;			
	float2 texCoord : TEXCOORD;	
	float3 normal : NORMAL;	
};
struct VS_OUTPUT 
{
	float4 position : POSITION;
	float2 texCoord : TEXCOORD0;
	float normalY : TEXCOORD1;
	
};
#define PS_INPUT VS_OUTPUT

// -------------------------------------------------------------
// Vertex Shader
// -------------------------------------------------------------
VS_OUTPUT VS(VS_INPUT IN) 
{
	VS_OUTPUT OUT;
	
	OUT.position = mul(IN.position, matWorldViewProjection);
	OUT.texCoord = IN.texCoord * cloudsTiling + cloudsTranslation;
	OUT.normalY = IN.normal.y;
	
	return OUT;
}

// -------------------------------------------------------------
// Miscellaneous Functions
// -------------------------------------------------------------
float3 interpolate(float3 origin, float3 destination, float startStep, float endStep, float step)
{
	#ifdef HERMITE_INTERPOLATION
		return lerp(origin, destination, smoothstep(startStep, endStep, step));
	#elif defined(LINEAR_INTERPOLATION)
		return lerp(origin, destination, saturate((step - startStep) / (endStep - startStep)));
	#else // Fallback so that it compiles...
		return 0.0f.rrr;
	#endif
}

// -------------------------------------------------------------
// Pixel Shader Functions
// -------------------------------------------------------------
float4 PS(PS_INPUT IN) : COLOR
{
	float theta = IN.normalY;
	
	float3 color;
	float4 cloudsColor = tex2D(sampClouds, IN.texCoord) * cloudsColor;
	
	float3 cloudedOverHorizon = lerp(overHorizonColor, cloudsColor.rgb, cloudsColor.a * CLOUD_FALLOFF_STEP_1);
	float3 cloudedMidSky = lerp(midSkyColor, cloudsColor.rgb, cloudsColor.a * CLOUD_FALLOFF_STEP_2);
	float3 cloudedZenith = lerp(zenithColor, cloudsColor.rgb, cloudsColor.a);

	color = interpolate(belowHorizonColor, horizonColor, 0, HORIZON_LEVEL, theta);	
	
	if(theta > HORIZON_LEVEL)
		color = interpolate(horizonColor, cloudedOverHorizon, HORIZON_LEVEL, OVER_HORIZON_LEVEL, theta);		
	if(theta > OVER_HORIZON_LEVEL)
		color = interpolate(cloudedOverHorizon, cloudedMidSky, OVER_HORIZON_LEVEL, MID_SKY_LEVEL, theta);
	if(theta > MID_SKY_LEVEL)
		color = interpolate(cloudedMidSky, cloudedZenith, MID_SKY_LEVEL, ZENITH_LEVEL, theta);	
		
	return float4(color, 1);
}

// -------------------------------------------------------------
// Techniques
// -------------------------------------------------------------
technique TSM3
{
    pass P1
    {
		VertexShader = compile vs_3_0 VS();
		PixelShader = compile ps_3_0 PS();
		ZWriteEnable = false;
    }
}
technique TSM2b
{
    pass P1
    {
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_b PS();
		ZWriteEnable = false;
    }
}
technique TSM2a
{
    pass P1
    {
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_a PS();
		ZWriteEnable = false;
    }
}
technique TSM2 
{
    pass P1
    {
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS();
		ZWriteEnable = false;
    }
}