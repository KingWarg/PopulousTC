// =============================================================
// Atmosphere Shader
// 
// Copyright (c) 2006 Renaud Bédard (Zaknafein)
// http://zaknafein.no-ip.org (renaud.bedard@gmail.com)
// =============================================================

// -------------------------------------------------------------
// Semantics
// -------------------------------------------------------------
float4x4 matWorldViewProj : WORLDVIEWPROJECTION;
float4x4 matWorldIT : WORLDINVERSETRANSPOSE;
float4x4 matWorld : WORLD;	
float3 lightVec : LIGHTDIR0_DIRECTION;
float4 vecViewPosition : VIEWPOS;

// -------------------------------------------------------------
// Parameters
// -------------------------------------------------------------
float3 color = float3(0.45f, 0.65f, 1.0f); //106,159,219 

// -------------------------------------------------------------
// Input/Output channels
// -------------------------------------------------------------
struct VS_INPUT {
	float4 rawPos : POSITION;		// Vertex position in object space
	float4 normalVec : NORMAL;		// Vertex normal in object space
	float2 texCoord : TEXCOORD0;	// Vertex texture coordinate
};
struct VS_OUTPUT {
	float4 homogenousPos : POSITION;	// Transformed position
	float2 texCoord : TEXCOORD0;		// Interpolated & scaled t.c.
	float3 viewVec : TEXCOORD1;			// Eye vector in tangent space	
	float3 normalVec : TEXCOORD2;		
};
#define	PS_INPUT VS_OUTPUT		// What comes out of VS goes into PS!

// -------------------------------------------------------------
// Vertex Shader function
// -------------------------------------------------------------
VS_OUTPUT VS(VS_INPUT IN) {
	VS_OUTPUT OUT;
    
    // Basic transformation into clip-space
    OUT.homogenousPos = mul(IN.rawPos, matWorldViewProj);	    
    
	// Since the light position is in world-space,...
    float4 worldPos = mul(IN.rawPos, matWorld);    
    
	OUT.normalVec = mul(IN.normalVec, matWorldIT);
	OUT.viewVec = vecViewPosition - worldPos;
	
    // Since the TextureMod commands do not affect the coordinates,
    // we need to supply and apply them ourselves
    OUT.texCoord = IN.texCoord;
    
	return OUT;
}

// -------------------------------------------------------------
// Pixel Shader function
// -------------------------------------------------------------
float4 PS(PS_INPUT IN) : COLOR {
	float3 normedNormal = normalize(IN.normalVec);
	float dotProduct = 1 - abs(dot(normalize(IN.viewVec), normedNormal));
	float alpha = 1 - pow(dotProduct, 3);
	alpha *= dotProduct;
	
	return float4(color, saturate(pow(alpha, 4) * dot(normedNormal, normalize(-lightVec)) * 7.0f));
	
	/*float3 normedNormal = normalize(IN.normalVec);
	return abs(dot(normalize(IN.viewVec), normedNormal));*/
}

// -------------------------------------------------------------
// Technique
// -------------------------------------------------------------
technique TShader {
    pass P0 {
		// States
		AlphablendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		AlphaTestEnable = false;
    
        // Compile Shaders
        VertexShader = compile vs_2_0 VS();
        PixelShader  = compile ps_2_0 PS();
    }
}