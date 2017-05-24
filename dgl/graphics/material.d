/*
Copyright (c) 2015-2016 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dgl.graphics.material;

import std.string;
import std.math;

import dlib.core.memory;
import dlib.image.color;
import dlib.container.dict;

import dgl.core.api;
import dgl.core.interfaces;
import dgl.core.application;
import dgl.graphics.texture;
import dgl.graphics.state;
import dgl.graphics.shader;
import dgl.graphics.ubershader;
import dgl.asset.props;

enum
{
    CBlack = Color4f(0.0f, 0.0f, 0.0f, 1.0f),
    CWhite = Color4f(1.0f, 1.0f, 1.0f, 1.0f),
    CRed = Color4f(1.0f, 0.0f, 0.0f, 1.0f),
    COrange = Color4f(1.0f, 0.5f, 0.0f, 1.0f),
    CYellow = Color4f(1.0f, 1.0f, 0.0f, 1.0f),
    CGreen = Color4f(0.0f, 1.0f, 0.0f, 1.0f),
    CCyan = Color4f(0.0f, 1.0f, 1.0f, 1.0f),
    CBlue = Color4f(0.0f, 0.0f, 1.0f, 1.0f),
    CPurple = Color4f(0.5f, 0.0f, 1.0f, 1.0f),
    CMagenta = Color4f(1.0f, 0.0f, 1.0f, 1.0f)
}

enum ShadowType: int
{
    BoxBlur = 0,
    PoissonDisk = 1,
    HardEdges = 2
}

class Material: Modifier
{
    int id;
    string name;
    
    Texture[8] textures;
    Shader shader;
    __gshared static UberShader uberShader;

    Color4f ambientColor;
    Color4f diffuseColor;
    Color4f specularColor;
    Color4f emissionColor;
    float specularity = 0.9f;
    float roughness = 0.4f;
    float fresnel = 0.3f;
    float metallic = 0.01f;
    
    bool shadeless = false;
    bool useTextures = true;
    bool additiveBlending = false;
    bool doubleSided = false;
    bool forceActive = false;
    bool useGLSL = true;
    bool bump = true;
    bool parallax = true;
    bool glowMap = true;
    bool useFog = true;
    bool matcap = false;
    bool receiveShadows = true;
    bool castShadows = true;
    
    ShadowType shadowType = ShadowType.BoxBlur;
    
    this()
    {
        ambientColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
        diffuseColor = Color4f(0.8f, 0.8f, 0.8f, 1.0f);
        specularColor = Color4f(1.0f, 1.0f, 1.0f, 1.0f);
        emissionColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
    }
    
    static void deleteUberShader()
    {
        if (uberShader)
            Delete(uberShader);
    }
    
    void setShader(Shader sh)
    {
        if (!useGLSL)
            return;
    
        if (!isGLSLSupported())
            return;
            
        if (!isShadersEnabled())
            return;
        
        shader = sh;
    }
    
    void setShader()
    {
        if (!useGLSL)
            return;
    
        if (!isGLSLSupported())
            return;
            
        if (!isShadersEnabled())
            return;
        
        if (uberShader is null)
            uberShader = New!UberShader();
            
        shader = uberShader;
    }
    
    static bool isGLSLSupported()
    {
        return DerelictGL.isExtensionSupported("GL_ARB_shading_language_100");
    }
    
    static bool isShadersEnabled()
    {
        if ("fxShadersEnabled" in config)
        {
            return config["fxShadersEnabled"].toBool;
        }
        else
            return false;
    }
    
    @property uint numTextures()
    {
        uint res = 0;
        foreach(t; textures)
            if (t !is null) res++;
        return res;
    }
    
    void bind(double dt)
    {
        if (!PipelineState.materialsActive && !forceActive)
            return;

        glPushAttrib(GL_ENABLE_BIT);

        glDisable(GL_TEXTURE_2D);
        
        glEnable(GL_LIGHTING);
        glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, ambientColor.arrayof.ptr);
        glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, diffuseColor.arrayof.ptr);
        glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, specularColor.arrayof.ptr);
        glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, emissionColor.arrayof.ptr);
        float shininess = pow(2.0f, (1.0f - roughness) * 10.0f);
        glMaterialfv(GL_FRONT_AND_BACK, GL_SHININESS, &shininess);
        
        if (additiveBlending)
            glBlendFunc(GL_ONE, GL_ONE);
            
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        if (shadeless)
        {
            glColor4f(diffuseColor.r, diffuseColor.g, diffuseColor.b, diffuseColor.a);
            glDisable(GL_LIGHTING);
        }
        
        if (doubleSided)
            glDisable(GL_CULL_FACE);

        if (useTextures)
        foreach(i, tex; textures)
        {
            if (tex !is null)
            {
                glActiveTextureARB(GL_TEXTURE0_ARB + cast(uint)i);
                tex.bind(dt);
            }
        }

        if (shader)
        {            
            shader.bind(this);
        }
    }
    
    void unbind()
    {
        if (!PipelineState.materialsActive && !forceActive)
            return;

        if (shader)
            shader.unbind();
    
        if (useTextures)
        foreach(i, tex; textures)
        {
            if (tex !is null)
            {
                glActiveTextureARB(GL_TEXTURE0_ARB + cast(uint)i);
                tex.unbind();
            }
        }
        
        glDisable(GL_LIGHTING);
        
        if (doubleSided)
            glEnable(GL_CULL_FACE);

        glActiveTextureARB(GL_TEXTURE0_ARB);

        if (additiveBlending)
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        glPopAttrib();
    }
    
    override string toString()
    {
        return format(
            "id = %s\n"~
            "name = %s\n"~
            "diffuseColor = %s\n"~
            "specularColor = %s\n"~
            "emissionColor = %s",
            id,
            name,
            diffuseColor,
            specularColor,
            emissionColor
        );
    }
    
    static void setFogDistance(float minDist, float maxDist)
    {
        glFogf(GL_FOG_START, minDist);
        glFogf(GL_FOG_END, maxDist);
    }
    
    static void setFogColor(Color4f col)
    {
        glFogfv(GL_FOG_COLOR, col.arrayof.ptr);
    }
}

/*
class MaterialLibrary
{
    Dict!(Material, int) materialsById;
    Dict!(Material, string) materialsByName;
    
    this()
    {
        materialsById = New!(Dict!(Material, int));
        materialsByName = New!(Dict!(Material, string));
    }
    
    void addMaterial(int id, string name, Material mat)
    {
        materialsById[id] = mat;
        materialsByName[copyStr(name)] = mat;
    }
    
    Material getMaterial(int id)
    {
        if (id in materialsById)
            return materialsById[id];
        else
            return null;
    }
    
    Material getMaterial(string name)
    {
        if (name in materialsByName)
            return materialsByName[name];
        else
            return null;
    }
    
    void setShader()
    {
        foreach(i, m; materialsById)
            m.setShader();
    }
    
    ~this()
    {
        foreach(name, m; materialsByName)
        {
            Delete(name);
            Delete(m);
        }
        Delete(materialsByName);
        Delete(materialsById);
    }
}
*/
