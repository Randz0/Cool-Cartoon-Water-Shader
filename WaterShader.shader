// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/WaterShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "blue" {}

        _InverseDetail ("1 / Resolution of Plane", Float) = 0.03333333333333 
        _MaxUVDisplacement ("Wonkiness", Range(0, 1)) = 0.4 

        _NoiseMap ("Noise Map", 3D) = "white" 
        _SizeOfNoiseMap ("Size Noise Map", int) = 10
        _InverseSizeNoiseMap (" 1 / Size Of Noise Map", float) = 0.1
    }
    SubShader
    {

        Pass
        {
            // Basically the idea is that you distort the uvs to give the impression of movement
            // And for lighting, it's just mapped to a 3D noise sample so that it transitions smoothly

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #define PI 3.141592653589793238462643382479 // More than enough detail i hope
            #define ROOTOF_3OVER4 0.86602540378

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler3D _NoiseMap;

            int _SizeOfNoiseMap;
            float _InverseSizeNoiseMap;

            float _InverseDetail;
            float _MaxUVDisplacement;

            struct VertIn {
                float4 positionVert : POSITION;
                float2 uv1 : TEXCOORD0;
            };

            struct VertOut {
                float4 positionVert : SV_POSITION;
                float2 uv1 : TEXCOORD0;

                float calculatedPerlinLighting : TEXCOORD1;
            };

            float TrigSumX (float val) {
                float withTime = val + _Time.y;

                return 0.5 * sin(withTime) + 0.25 * cos(2 * withTime) - 0.25 * sin(PI * withTime);
            }

            float TrigSumY(float val) {
                float withTime = val + _Time.y;

                return -0.625 * cos (0.5 * withTime) + 0.1875 * sin(PI * withTime) + 0.0625 * sin(0.75 * withTime);
            }

            float2 GetUVDistortion (float2 posXZ) {
                float xDisp = TrigSumX(posXZ.x);
                float yDisp = TrigSumY(posXZ.y);

                return float2(xDisp, yDisp) * _InverseDetail * _MaxUVDisplacement; 
            }

            void GetGradients(float4 bottomRightUVPos, out float3 gradients[8]) {
                gradients[0] = tex3Dlod(_NoiseMap, bottomRightUVPos); // Bottom Left
                gradients[1] = tex3Dlod(_NoiseMap, bottomRightUVPos + float4(_InverseSizeNoiseMap, 0, 0, 0)); // Bottom Right
                gradients[2] = tex3Dlod(_NoiseMap, bottomRightUVPos + float4(0, _InverseSizeNoiseMap, 0, 0)); // Bottom Forward
                gradients[3] = tex3Dlod(_NoiseMap, bottomRightUVPos + float4(_InverseSizeNoiseMap, _InverseSizeNoiseMap, 0, 0)); // Bottom Forward Right
                gradients[4] = tex3Dlod(_NoiseMap, bottomRightUVPos + float4(0, 0, _InverseSizeNoiseMap, 0)); // Top Left
                gradients[5] = tex3Dlod(_NoiseMap, bottomRightUVPos + float4(_InverseSizeNoiseMap, 0, _InverseSizeNoiseMap, 0)); // Top Right
                gradients[6] = tex3Dlod(_NoiseMap, bottomRightUVPos + float4(0, _InverseSizeNoiseMap, _InverseSizeNoiseMap, 0)); // Top Forward
                gradients[7] = tex3Dlod(_NoiseMap, bottomRightUVPos + float4(_InverseSizeNoiseMap, _InverseSizeNoiseMap, _InverseSizeNoiseMap, 0)); // Top Forward Right
            } // This is a lot of code but it really just samples from the tex3d for the relevant gradient info

            float FadePerAxis (float value) {
                return value * value * value * (value * ( value * 6 - 15) + 10);
            }

            float JointFadeFunction (float3 displacementXYZ) {
                return FadePerAxis(displacementXYZ.x) * FadePerAxis(displacementXYZ.y) * FadePerAxis(displacementXYZ.z);
            } // When implementing perlin noise, a fade function is often used for convienience; Expects the inputs in pixel coords with decimal precision

            void GetJointFadesWithDifferences (float3 positionInUnitCube, out float fades[8], out float3 diffs[8]) {
                diffs[0] = float3(1,1,1) - positionInUnitCube;
                fades[0] = JointFadeFunction(diffs[0]); // Bottom Left

                diffs[1] = float3(positionInUnitCube.x, 1 - positionInUnitCube.yz);
                fades[1] = JointFadeFunction(diffs[1]); // Bottom Right
                
                diffs[2] = float3(1 - positionInUnitCube.x, positionInUnitCube.y, 1 - positionInUnitCube.z);
                fades[2] = JointFadeFunction(diffs[2]); // Bottom Forward
                
                diffs[3] = float3(positionInUnitCube.x, positionInUnitCube.y, 1 - positionInUnitCube.z);
                fades[3] = JointFadeFunction(diffs[3]); // Bottom Forward Right
                
                diffs[4] = float3(1 - positionInUnitCube.x, 1 - positionInUnitCube.y, positionInUnitCube.z);
                fades[4] = JointFadeFunction(diffs[4]); // Top Left
                
                diffs[5] = float3(positionInUnitCube.x, 1 - positionInUnitCube.y, positionInUnitCube.z);
                fades[5] = JointFadeFunction(diffs[5]); // Top Right
                
                diffs[6] = float3(1 - positionInUnitCube.x, positionInUnitCube.y, positionInUnitCube.z);
                fades[6] = JointFadeFunction(diffs[6]); // Top Forward
                
                diffs[7] = float3(positionInUnitCube.x, positionInUnitCube.y, positionInUnitCube.z);
                fades[7] = JointFadeFunction(diffs[7]); // Top Forward Right
            } // Calculates the Joint fade function and caches the differences for the later dot products

            float GetFinalPerlinValue (float fades[8], float3 diffs[8], float3 gradients[8]) {
                return (
                    dot (diffs[0], gradients[0]) * fades[0] +
                    dot (diffs[1], gradients[1]) * fades[1] +
                    dot (diffs[2], gradients[2]) * fades[2] +
                    dot (diffs[3], gradients[3]) * fades[3] +
                    dot (diffs[4], gradients[4]) * fades[4] +
                    dot (diffs[5], gradients[5]) * fades[5] +
                    dot (diffs[6], gradients[6]) * fades[6] +
                    dot (diffs[7], gradients[7]) * fades[7]
                );
            } // Does the final operation which is nice and implemented

            #define OUTPUT_SHIFT 0.43301270189
            #define OUTPUT_SCALE 0.76980035892

            // Samples the value of perlin noise from within the model
            float GetBrightnessFromNoiseMap(float3 sampleAt) {
                float4 unitSamplingPosition = float4(sampleAt.xyz, 0); // Actual uv position
                float4 bottomLeftSample = float4( floor(unitSamplingPosition * _SizeOfNoiseMap) * _InverseSizeNoiseMap); // bottomleft uv position

                float3 positionRelativeBottomLeft = (unitSamplingPosition - bottomLeftSample) * _SizeOfNoiseMap; // should be from 0-1 as in texel coords

                float3 gradients[8];
                float3 diffs[8];
                float fades[8];

                GetGradients(bottomLeftSample, gradients);
                GetJointFadesWithDifferences(positionRelativeBottomLeft, fades, diffs);
                
                return (GetFinalPerlinValue(fades, diffs, gradients) + OUTPUT_SHIFT) * OUTPUT_SCALE;
            }

           VertOut vert (VertIn i) {
                VertOut o;

                o.positionVert = UnityObjectToClipPos(i.positionVert);

                float4 worldPositionVert = mul (unity_ObjectToWorld, i.positionVert );
                o.uv1 = i.uv1 + GetUVDistortion(worldPositionVert.xz);

                o.calculatedPerlinLighting = GetBrightnessFromNoiseMap(float3(i.uv1, _Time.x));
                o.uv1 = o.uv1 * _MainTex_ST.xy + _MainTex_ST.zw;

                return o;
            }

            float4 frag(VertOut i) : SV_TARGET {
                return i.calculatedPerlinLighting * tex2D(_MainTex, i.uv1);
            }

            ENDCG
        }
    }
}