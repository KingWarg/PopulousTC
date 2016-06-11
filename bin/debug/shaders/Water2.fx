// =============================================================
// Non-Reflective Water Shader
// ***************************
// Copyright (c) 2006 Renaud Bédard (Zaknafein)
// E-mail : renaud.bedard@gmail.com
// =============================================================

// -------------------------------------------------------------
// Compilation flags
// -------------------------------------------------------------
// Define if you use a DXT5-compressed map with the red channel
// cleared and its data in the alpha channel (the DXT5NM standard)
#define DXT5NM_NORMAL_MAP;

// -------------------------------------------------------------
// Semantics
// -------------------------------------------------------------
float4x4 matWorldViewProj : WORLDVIEWPROJECTION;
float4x4 matWorldIT : WORLDIT;
float4x4 matWorld : WORLD;
float3 viewPosition : VIEWPOSITION;
float time : TIME;
float3 lightDir : LIGHTDIR0_DIRECTION;
float3 lightCol : LIGHTDIR0_COLOR; 
				  
// -------------------------------------------------------------
// Textures & Samplers
// -------------------------------------------------------------
texture texNormal : TEXTURE0;
sampler sampNormal = sampler_state {
	Texture = (texNormal);
	MagFilter = Linear;
	MinFilter = Linear;
	MipFilter = Linear;
};

texture texSpecularMask < string name = "..\Data\Textures\Water\SpecularMask.dds"; >;
sampler sampSpecularMask = sampler_state {
	Texture = (texSpecularMask);
	MagFilter = Linear;
	MinFilter = Linear;
	MipFilter = Linear;	
};

texture texAlpha < string name = "..\Data\Textures\Water\AlphaMap.dds"; >;
sampler sampAlpha = sampler_state {
	Texture = (texAlpha);
	MagFilter = Linear;
	MinFilter = Linear;
	MipFilter = Linear;	
};

// -------------------------------------------------------------
// Constants
// -------------------------------------------------------------
// Fog-related, do not modify
#define FOG_TYPE_NONE    0
#define FOG_TYPE_EXP     1
#define FOG_TYPE_EXP2    2
#define FOG_TYPE_LINEAR  3

// -------------------------------------------------------------
// Parameters
// -------------------------------------------------------------
// The wave movement speed, based on texture coordinates
// scrolling/translation
float waveMovementSpeed = 3;
// The normalmap tiling -- using more tiles on Y makes the waves
// appear oval, looks a little better IMHO
float2 waveSize = {35, 45};
// The specular mask tiling, defines the size and spacing of the
// specular "sparkles"
float2 sparkleSize = {8, 10};

// Water dark (bottom) and light (top) colors, used for diffuse bump-mapping
float3 waterDarkColor;
float3 waterLightColor;

// Fog settings
// In a future beta of TV3D 6.5, all those will be feeded by semantics
float3 fogColor;
float fogDensity;
float fogStart;
float fogEnd;
int fogType;

// -------------------------------------------------------------
// Input/Output channels
// -------------------------------------------------------------
struct VS_INPUT {
	float4 pos : POSITION;			// Vertex position in object space
	float2 texCoord : TEXCOORD;		// Vertex texture coordinates
};
struct VS_OUTPUT {
	float4 pos : POSITION;				// Pixel position in clip space	
	float2 normalMapTC1 : TEXCOORD0;	// First normalmap sampler TC
	float2 normalMapTC2 : TEXCOORD1;	// Second normalmap sampler TC
	float3 view : TEXCOORD2;			// View vector in tangent space
	float3 light : TEXCOORD3;			// Light vector in tangent space
	float2 specularMapTC : TEXCOORD4;	// Specular mask TC
	float2 alphaMapTC : TEXCOORD5;		// Alpha map TC (1:1)
	float fog : FOG;					// Vertex-Fog thickness
};
#define	PS_INPUT VS_OUTPUT		// What comes out of VS goes into PS!

// -------------------------------------------------------------
// Other structs
// -------------------------------------------------------------
struct COMMON_PS_OUTPUT {
	float3 waterColor;
	float specular;
	float alpha;
};

// -------------------------------------------------------------
// Vertex Shader function
// -------------------------------------------------------------
VS_OUTPUT VS(VS_INPUT IN) {
	VS_OUTPUT OUT;

	OUT.pos = mul(IN.pos, matWorldViewProj);
	
	// Light, view transformation in plane-tangent space	
	float3 worldPos =  mul(IN.pos, matWorld);
	OUT.view = (viewPosition - worldPos).xzy;
	OUT.light = mul(matWorldIT, -lightDir).xzy;

	// Specular and alpha maps texture coords
	OUT.alphaMapTC = IN.texCoord;
	OUT.specularMapTC = IN.texCoord * sparkleSize;	

	IN.texCoord *= waveSize;
	// Scroll both normal maps texture coordinates
	OUT.normalMapTC1 = float2(IN.texCoord.x, IN.texCoord.y - time * waveMovementSpeed / 100);		
	OUT.normalMapTC2 = float2(IN.texCoord.x + 0.5f, IN.texCoord.y + time * waveMovementSpeed / 100);		

	// Calculate vertex fog
	float dist = distance(worldPos, viewPosition);
	OUT.fog = (fogType == FOG_TYPE_NONE) +
			1 / exp(dist * fogDensity) * (fogType == FOG_TYPE_EXP) +
			1 / exp(pow(dist * fogDensity, 2)) * (fogType == FOG_TYPE_EXP2) +
			saturate((fogEnd - dist) / (fogEnd - fogStart)) * (fogType == FOG_TYPE_LINEAR);

	return OUT;
}

// -------------------------------------------------------------
// Pixel Shader functions
// -------------------------------------------------------------
// Common PS 2.0 and PS 3.0 function
COMMON_PS_OUTPUT CommonPS(PS_INPUT IN) {
	COMMON_PS_OUTPUT OUT;

	// Perform alpha-testing with a very small epsilon (0.001f) so that
	// the water isn't rendered below the land (small optimization)
	OUT.alpha = tex2D(sampAlpha, IN.alphaMapTC).r;
	clip(OUT.alpha - 0.001f);

	// Sample the normal-map two times with TC's moving in opposite directions
	float2 normalMapTC1 = IN.normalMapTC1;
	float2 normalMapTC2 = IN.normalMapTC2;
	float3 firstSampling, secondSampling;
	#ifdef DXT5NM_NORMAL_MAP
		// AGB instead of RGB, R is cleared by contract
		firstSampling = tex2D(sampNormal, normalMapTC1).agb;	
		secondSampling = tex2D(sampNormal, normalMapTC2).agb;	
	#else
		firstSampling = tex2D(sampNormal, normalMapTC1).rgb;	
		secondSampling = tex2D(sampNormal, normalMapTC2).rgb;	
	#endif
	
	// Average and normalize the normal
	float3 pixelNormal = normalize(firstSampling * 2 + secondSampling * 2 - 2);
	
	// Normalize all input vectors
	float3 light = normalize(IN.light);	
	float3 view = normalize(IN.view);
	// Phong reflection optimization on a planar surface
	float3 reflected = float3(-light.xy, light.z);
	// Specular masking TC's are warped using the pixel normal to fake animation
	// 0.03 is an arbitrary factor, and depends on the tiling of the specular map
	float2 specularMapTC = IN.specularMapTC + pixelNormal.rg * 0.03f;
	// 2 factor is to make colored specular go white where the sun hits... could be removed
	OUT.specular = pow(saturate(dot(reflected, view)), 4) * tex2D(sampSpecularMask, specularMapTC) * 2;	
	
	// Greaten the normal's effect on the diffuse bump-mapping
	pixelNormal.rg *= 1.5f;
	OUT.waterColor = lerp(waterDarkColor, waterLightColor, dot(pixelNormal, light));
	
	return OUT;
}

// PS 2.0 Function
float4 PS2(PS_INPUT IN) : COLOR {
	COMMON_PS_OUTPUT common = CommonPS(IN);

	// In PS 2.0, no need to put fog in the equation, it's done for us!	
	float3 retColor = common.waterColor + common.specular * lightCol;
	
	// max(alpha, specular) makes the alpha visible on small alpha values, looks nicer
	return float4(retColor, max(common.alpha, common.specular));
}

// PS 3.0 Function
float4 PS3(PS_INPUT IN) : COLOR {
	COMMON_PS_OUTPUT common = CommonPS(IN);

	// We need to LERP with fog color in PS 3.0
	float3 retColor = lerp(common.waterColor + common.specular * lightCol, fogColor, 1 - IN.fog);
	
	// max(alpha, specular) makes the alpha visible on small alpha values, looks nicer
	return float4(retColor, max(common.alpha, common.specular));
}

// -------------------------------------------------------------
// Technique
// -------------------------------------------------------------
// Use SM3 if available
technique TSM3 {
    pass P0 {    
		VertexShader = compile vs_3_0 VS();
		PixelShader  = compile ps_3_0 PS3();
		// Alphablending renderstates
		AlphablendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		AlphaTestEnable = false;  		
    }
}
// Or fallback to SM2
technique TSM2 {
    pass P0 {  
		VertexShader = compile vs_2_0 VS();
		PixelShader  = compile ps_2_0 PS2();		
		// Alphablending renderstates
		AlphablendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		AlphaTestEnable = false;
    }
}