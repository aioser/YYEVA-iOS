//
//  YSEVAPlayer_render.metal
//
//  Created by guoyabin on 2022/4/21.
//

#include <metal_stdlib>
#include "YYEVAVideoShareTypes.h"

using namespace metal;
   
typedef struct
{
    float4 postion [[position]]; // position的修饰符表示这个是顶点
    float2 textureCoordinate; // 纹理坐标
    
} VertexSharderOutput;

typedef struct
{
    float4 postion [[position]]; // position的修饰符表示这个是顶点
    float2 rgbTextureCoordinate; // 纹理坐标
    float2 alphaTextureCoordinate; // 纹理坐标
} VertexMaskSharderOutput;
 
typedef struct
{
    float4 postion [[position]]; // position的修饰符表示这个是顶点
    float2 sourceTextureCoordinate; // 纹理坐标
    float2 maskTextureCoordinate; // 纹理坐标
} VertexElementSharderOutput;


float3 RGBColorFromYuvTextures(sampler textureSampler, float2 coordinate, texture2d<float> texture_luma, texture2d<float> texture_chroma, matrix_float3x3 rotationMatrix, float3 offset) {
    
    float3 sourceYUV = float3(texture_luma.sample(textureSampler, coordinate).r,
                              texture_chroma.sample(textureSampler, coordinate).rg);
    return rotationMatrix * (sourceYUV + offset);;
}

vertex VertexSharderOutput
normalVertexShader(uint vertexID [[ vertex_id ]],
             constant YSVideoMetalVertex *vertexArray [[ buffer(YSVideoMetalVertexInputIndexVertices) ]])
{
    VertexSharderOutput out;
    out.postion = float4(vertexArray[vertexID].positon);
    out.textureCoordinate = vertexArray[vertexID].texturCoordinate;
    return out;
}

 
fragment float4
normalFragmentSharder(VertexSharderOutput input [[stage_in]],
               texture2d<float> textureY [[ texture(YSVideoMetalFragmentTextureIndexTextureY) ]],
               texture2d<float> textureUV [[ texture(YSVideoMetalFragmentTextureIndexTextureUV) ]],
               constant YSVideoMetalConvertMatrix *convertMatrix [[ buffer(YSVideoMetalFragmentBufferIndexMatrix) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    float sourceX = input.textureCoordinate.x / 2;
    float alphaX =  input.textureCoordinate.x / 2 + 0.5;
    float y = input.textureCoordinate.y;
    float2 sourceCoordinate = float2(sourceX,y);
    float2 alphaCoordinate = float2(alphaX,y);
    float3 sourceYUV = float3(textureY.sample(textureSampler, sourceCoordinate).r,
                        textureUV.sample(textureSampler, sourceCoordinate).rg);
    float3 alphaYUV = float3(textureY.sample(textureSampler, alphaCoordinate).r,
                        textureUV.sample(textureSampler, alphaCoordinate).rg);
    float3 sourceRGB = convertMatrix->matrix * (sourceYUV + convertMatrix->offset);
    float3 alphaRGB = convertMatrix->matrix * (alphaYUV + convertMatrix->offset);
    //新增mask
    return float4(sourceRGB, alphaRGB.r);
}
 

vertex VertexMaskSharderOutput
maskVertexShader(uint vertexID [[ vertex_id ]],
             constant YSVideoMetalMaskVertex *vertexArray [[ buffer(YSVideoMetalVertexInputIndexVertices) ]])
{
    VertexMaskSharderOutput out;
    out.postion = float4(vertexArray[vertexID].positon);
    out.rgbTextureCoordinate = vertexArray[vertexID].rgbTexturCoordinate;
    out.alphaTextureCoordinate = vertexArray[vertexID].alphaTexturCoordinate;
    return out;
}


fragment float4
maskFragmentSharder(VertexMaskSharderOutput input [[stage_in]],
               texture2d<float> textureY [[ texture(YSVideoMetalFragmentTextureIndexTextureY) ]],
               texture2d<float> textureUV [[ texture(YSVideoMetalFragmentTextureIndexTextureUV) ]],
               constant YSVideoMetalConvertMatrix *convertMatrix [[ buffer(YSVideoMetalFragmentBufferIndexMatrix) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    float3 sourceYUV = float3(textureY.sample(textureSampler, input.rgbTextureCoordinate).r,
                        textureUV.sample(textureSampler, input.rgbTextureCoordinate).rg);
    float3 alphaYUV = float3(textureY.sample(textureSampler, input.alphaTextureCoordinate).r,
                        textureUV.sample(textureSampler, input.alphaTextureCoordinate).rg);
    float3 sourceRGB = convertMatrix->matrix * (sourceYUV + convertMatrix->offset);
    float3 alphaRGB = convertMatrix->matrix * (alphaYUV + convertMatrix->offset);
//    //新增mask
    return float4(sourceRGB, alphaRGB.r);
 
}

vertex VertexElementSharderOutput
elementVertexShader(uint vertexID [[ vertex_id ]],
             constant YSVideoMetalElementVertex *vertexArray [[ buffer(YSVideoMetalVertexInputIndexVertices) ]])
{
    VertexElementSharderOutput out;
    out.postion = vertexArray[vertexID].positon;
    out.sourceTextureCoordinate = vertexArray[vertexID].sourceTextureCoordinate;
    out.maskTextureCoordinate =  vertexArray[vertexID].maskTextureCoordinate;
    return out;
}

fragment float4 elementFragmentSharder(VertexElementSharderOutput input [[ stage_in ]],
                                             texture2d<float>  lumaTexture [[ texture(0) ]],
                                             texture2d<float>  chromaTexture [[ texture(1) ]],
                                             texture2d<float>  sourceTexture [[ texture(2) ]],
                                             constant YSVideoMetalConvertMatrix *convertMatrix [[ buffer(0) ]],
                                             constant YSVideoElementFragmentParameter *fillParams [[ buffer(1) ]]) {
    
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    matrix_float3x3 rotationMatrix = convertMatrix->matrix;
    float3 offset = convertMatrix->offset;
    float3 mask = RGBColorFromYuvTextures(textureSampler, input.maskTextureCoordinate, lumaTexture, chromaTexture, rotationMatrix, offset);
    float4 source = sourceTexture.sample(textureSampler, input.sourceTextureCoordinate);
    float alpha = source.a * mask.r;
      
    return float4(source.rgb, alpha);
}


vertex VertexSharderOutput
bgVertexShader(uint vertexID [[ vertex_id ]],
             constant YSVideoMetalVertex *vertexArray [[ buffer(YSVideoMetalVertexInputIndexVertices) ]])
{
    VertexSharderOutput out;
    out.postion = float4(vertexArray[vertexID].positon);
    out.textureCoordinate = vertexArray[vertexID].texturCoordinate;
    return out;
}

 
fragment float4
bgFragmentSharder(VertexSharderOutput input [[stage_in]],
               texture2d<float> texture [[ texture(YSVideoMetalFragmentTextureIndexTextureY) ]],
               constant YSVideoMetalConvertMatrix *convertMatrix [[ buffer(YSVideoMetalFragmentBufferIndexMatrix) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
      
    return texture.sample(textureSampler, input.textureCoordinate);
}
