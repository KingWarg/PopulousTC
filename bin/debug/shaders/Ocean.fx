/*********************************************************************NVMH3****
$Revision: #3 $

Copyright NVIDIA Corporation 2007
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THIS SOFTWARE IS PROVIDED
*AS IS* AND NVIDIA AND ITS SUPPLIERS DISCLAIM ALL WARRANTIES, EITHER EXPRESS
OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE.  IN NO EVENT SHALL NVIDIA OR ITS SUPPLIERS
BE LIABLE FOR ANY SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES
WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS PROFITS,
BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR ANY OTHER PECUNIARY
LOSS) ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF
NVIDIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

% Simple ocean shader with animated bump map and geometric waves
% Based partly on "Effective Water Simulation From Physical Models", GPU Gems

keywords: material animation environment bumpmap

These paramters have been updated so as to look appropriate when applied to an
FX Composer2 "plane" object


To learn more about shading, shaders, and to bounce ideas off other shader
    authors and users, visit the NVIDIA Shader Library Forums at:

    http://developer.nvidia.com/forums/

******************************************************************************/

#ifdef _3DSMAX_
int ParamID = 0x0003; // Defined by Autodesk
#endif /* _3DSMAX_ */

float Script : STANDARDSGLOBAL <
    string UIWidget = "none";
    string ScriptClass = "object";
    string ScriptOrder = "standard";
    string ScriptOutput = "color";
#ifdef _XSI_
    string Script = "Technique=Static;";
#else /* ! _XSI_ */
    string Script = "Technique=Main;";
#endif /* ! _XSI_ */
> = 0.8;

//// UN-TWEAKABLES - AUTOMATICALLY-TRACKED TRANSFORMS ////////////////

float4x4 WorldITXf : WorldInverseTranspose < string UIWidget="None"; >;
float4x4 WvpXf : WorldViewProjection < string UIWidget="None"; >;
float4x4 WorldXf : World < string UIWidget="None"; >;
float4x4 ViewIXf : ViewInverse < string UIWidget="None"; >;

float Timer : Time < string UIWidget = "none"; >;

//////////////// TEXTURES ///////////////////

texture NormalTexture  <
    string ResourceName = "waves2.dds";
    string UIName =  "Normal Map";
    string ResourceType = "2D";
>;

sampler2D NormalSampler = sampler_state {
    Texture = <NormalTexture>;
    MinFilter = Linear;
    MipFilter = Linear;
    MagFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
};
texture EnvTexture : ENVIRONMENT <
    string ResourceName = "CloudyHillsCubemap2.dds";
    string UIName =  "Environment Cubemap";
    string ResourceType = "Cube";
>;

samplerCUBE EnvSampler = sampler_state {
    Texture = <EnvTexture>;
    MagFilter = Linear;
    MinFilter = Linear;
    MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
    AddressW = Clamp;
};

///////// TWEAKABLE PARAMETERS //////////////////

float BumpScale <
    string UIWidget = "slider";
    float UIMin = 0.0;
    float UIMax = 2.0;
    float UIStep = 0.01;
    string UIName = "Bump Height";
> = 1.4;

float TexReptX <
    string UIName = "Texture Repeat X";
    string UIWidget = "slider";
    float UIMin = 1.0;
    float UIMax = 16.0;
    float UIStep = 0.1;
> = 8.0;

float TexReptY <
    string UIName = "Texture Repeat Y";
    string UIWidget = "slider";
    float UIMin = 1.0;
    float UIMax = 16.0;
    float UIStep = 0.1;
> = 4.0;

float BumpSpeedX <
    string UIName = "Bump Speed X";
    string UIWidget = "slider";
    float UIMin = -0.2;
    float UIMax = 0.2;
    float UIStep = 0.001;
> = -0.05;

float BumpSpeedY <
    string UIName = "Bump Speed Y";
    string UIWidget = "slider";
    float UIMin = -0.2;
    float UIMax = 0.2;
    float UIStep = 0.001;
> = 0.0;


static float2 TextureScale = float2(TexReptX,TexReptY);
static float2 BumpSpeed = float2(BumpSpeedX,BumpSpeedY);


float FresnelBias <
    string UIName = "Fresnel Bias";
    string UIWidget = "slider";
    float UIMin = 0.0;
    float UIMax = 1.0;
    float UIStep = 0.01;
> = 0.1;

float FresnelExp <
    string UIName = "Fresnel Exponent";
    string UIWidget = "slider";
    float UIMin = 0.0;
    float UIMax = 5.0;
    float UIStep = 0.01;
> = 4.0;

float HDRMultiplier <
    string UIName = "HDR Multiplier";
    string UIWidget = "slider";
    float UIMin = 0.0;
    float UIMax = 100.0;
    float UIStep = 0.01;
> = 3.0;

float3 DeepColor <
    string UIName = "Deep Water";
    string UIWidget = "Color";
> = {0.0f, 0.0f, 0.1f};

float3 ShallowColor <
    string UIName = "Shallow Water";
    string UIWidget = "Color";
> = {0.0f, 0.5f, 0.5f};

float3 ReflTint <
    string UIName = "Reflection Tint";
    string UIWidget = "Color";
> = {1.0f, 1.0f, 1.0f};

// these are redundant, but makes the ui easier:
float Kr <
    string UIName = "Reflection Strength";
    string UIWidget = "slider";    
    float UIMin = 0.0;
    float UIMax = 2.0;
    float UIStep = 0.01;    
> = 1.0f;

float KWater <
    string UIName = "Water Color Strength";
    string UIWidget = "slider";    
    float UIMin = 0.0;
    float UIMax = 2.0;
    float UIStep = 0.01;    
> = 1.0f;

float WaveAmp <
    string UIName = "Wave Amplitude";
    string UIWidget = "slider";
    float UIMin = 0.0;
    float UIMax = 0.25;
    float UIStep = 0.001;
> = 0.05;

float WaveFreq <
    string UIName = "Wave frequency";
    string UIWidget = "slider";
    float UIMin = 0.0;
    float UIMax = 6.0;
    float UIStep = 0.01;
> = 3.0;

//////////// CONNECTOR STRUCTS //////////////////

struct AppData {
    float4 Position : POSITION;   // in object space
    float2 UV : TEXCOORD0;
    float3 Tangent  : TEXCOORD1;
    float3 Binormal : TEXCOORD2;
    float3 Normal   : NORMAL;
};

struct OceanVertOut {
    float4 HPosition  : POSITION;  // in clip space
    float2 UV  : TEXCOORD0;
    float3 T2WXf1 : TEXCOORD1; // first row of the 3x3 transform from tangent to cube space
    float3 T2WXf2 : TEXCOORD2; // second row of the 3x3 transform from tangent to cube space
    float3 T2WXf3 : TEXCOORD3; // third row of the 3x3 transform from tangent to cube space
    float2 bumpUV0 : TEXCOORD4;
    float2 bumpUV1 : TEXCOORD5;
    float2 bumpUV2 : TEXCOORD6;
    float3 WorldView  : TEXCOORD7;
};

// wave functions ///////////////////////

struct Wave {
  float freq;  // 2*PI / wavelength
  float amp;   // amplitude
  float phase; // speed * 2*PI / wavelength
  float2 dir;
};

#define NWAVES 2
Wave wave[NWAVES] = {
	{ 1.0, 1.0, 0.5, float2(-1, 0) },
	{ 2.0, 0.5, 1.3, float2(-0.7, 0.7) }	
};

float evaluateWave(Wave w, float2 pos, float t)
{
  return w.amp * sin( dot(w.dir, pos)*w.freq + t*w.phase);
}

// derivative of wave function
float evaluateWaveDeriv(Wave w, float2 pos, float t)
{
  return w.freq*w.amp * cos( dot(w.dir, pos)*w.freq + t*w.phase);
}

// sharp wave functions
float evaluateWaveSharp(Wave w, float2 pos, float t, float k)
{
  return w.amp * pow(sin( dot(w.dir, pos)*w.freq + t*w.phase)* 0.5 + 0.5 , k);
}

float evaluateWaveDerivSharp(Wave w, float2 pos, float t, float k)
{
  return k*w.freq*w.amp * pow(sin( dot(w.dir, pos)*w.freq + t*w.phase)* 0.5 + 0.5 , k - 1) * cos( dot(w.dir, pos)*w.freq + t*w.phase);
}

///////// SHADER FUNCTIONS ///////////////

OceanVertOut OceanVS(AppData IN)
{
    OceanVertOut OUT = (OceanVertOut)0;
    wave[0].freq = WaveFreq;
    wave[0].amp = WaveAmp;
    wave[1].freq = WaveFreq*2.0;
    wave[1].amp = WaveAmp*0.5;
    float4 Po = float4(IN.Position.xyz,1.0);
    // sum waves	
    Po.y = 0.0;
    float ddx = 0.0, ddy = 0.0;
    for(int i=0; i<NWAVES; i++) {
	Po.y += evaluateWave(wave[i], Po.xz, Timer);
	float deriv = evaluateWaveDeriv(wave[i], Po.xz, Timer);
	ddx += deriv * wave[i].dir.x;
	ddy += deriv * wave[i].dir.y;
    }
    // compute tangent basis
    float3 B = float3(1, ddx, 0);
    float3 T = float3(0, ddy, 1);
    float3 N = float3(-ddx, 1, -ddy);
    OUT.HPosition = mul(Po,WvpXf);
    // pass texture coordinates for fetching the normal map
    OUT.UV = IN.UV.xy*TextureScale;
    float cycle = fmod(Timer, 100.0);
    OUT.bumpUV0.xy = IN.UV.xy*TextureScale + cycle*BumpSpeed;
    OUT.bumpUV1.xy = IN.UV.xy*TextureScale*2.0 + cycle*BumpSpeed*4.0;
    OUT.bumpUV2.xy = IN.UV.xy*TextureScale*4.0 + cycle*BumpSpeed*8.0;

    // compute the 3x3 tranform from tangent space to object space
    float3x3 objToTangentSpace;
    // first rows are the tangent and binormal scaled by the bump scale
    objToTangentSpace[0] = BumpScale * normalize(T);
    objToTangentSpace[1] = BumpScale * normalize(B);
    objToTangentSpace[2] = normalize(N);

    OUT.T2WXf1.xyz = mul(objToTangentSpace,WorldXf[0].xyz);
    OUT.T2WXf2.xyz = mul(objToTangentSpace,WorldXf[1].xyz);
    OUT.T2WXf3.xyz = mul(objToTangentSpace,WorldXf[2].xyz);

    // compute the eye vector (going from shaded point to eye) in cube space
    float3 Pw = mul(Po,WorldXf).xyz;
    OUT.WorldView = ViewIXf[3].xyz - Pw; // view inv. transpose contains eye position in world space in last row
    return OUT;
}


// Pixel Shaders

float4 OceanPS(OceanVertOut IN) : COLOR
{
    // sum normal maps
    float4 t0 = tex2D(NormalSampler, IN.bumpUV0)*2.0-1.0;
    float4 t1 = tex2D(NormalSampler, IN.bumpUV1)*2.0-1.0;
    float4 t2 = tex2D(NormalSampler, IN.bumpUV2)*2.0-1.0;
    float3 Nt = t0.xyz + t1.xyz + t2.xyz;
    //    float3 Nt = t1.xyz;

    float3x3 m; // tangent to world matrix
    m[0] = IN.T2WXf1;
    m[1] = IN.T2WXf2;
    m[2] = IN.T2WXf3;
    float3 Nw = mul(m,Nt);
    float3 Nn = normalize(Nw);

	// reflection
    float3 Vn = normalize(IN.WorldView);
    float3 R = reflect(-Vn, Nn);

    float4 reflection = texCUBE(EnvSampler, R);
    // hdr effect (multiplier in alpha channel)
    reflection.rgb *= (1.0 + reflection.a*HDRMultiplier);

    float facing = 1.0 - max(dot(Vn, Nn), 0);
    float fres = Kr*(FresnelBias+(1.0-FresnelBias)*pow(facing,FresnelExp));

    float3 waterColor = KWater * lerp(DeepColor, ShallowColor, facing);
    float3 result = waterColor + (fres * reflection.rgb * ReflTint);
    return float4(result.rgb,1.0);
}

//////////////////// TECHNIQUE ////////////////

#ifdef _XSI_
#define Main Static
#endif /* _XSI_ */

technique Main < string Script = "Pass=p0;"; > {
    pass p0 < string Script = "Draw=geometry;"; > {
	VertexShader = compile vs_2_0 OceanVS();
		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = LessEqual;
		AlphaBlendEnable = false;
		CullMode = None;
	PixelShader = compile ps_2_a OceanPS();
    }
}

///////////////////////////////// eof ///
