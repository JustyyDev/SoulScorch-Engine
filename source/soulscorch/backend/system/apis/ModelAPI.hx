package soulscorch.backend.system.apis;

import away3d.animators.SkeletonAnimationSet;
import away3d.animators.SkeletonAnimator;
import away3d.animators.nodes.SkeletonClipNode;
import away3d.animators.transitions.CrossfadeTransition;
import away3d.containers.ObjectContainer3D;
import away3d.core.base.Geometry;
import away3d.core.base.SubGeometry;
import away3d.core.pick.PickingColliderType;
import away3d.core.pick.RaycastPicker;
import away3d.entities.Mesh;
import away3d.events.Asset3DEvent;
import away3d.events.LoaderEvent;
import away3d.library.assets.Asset3DType;
import away3d.lights.DirectionalLight;
import away3d.lights.LightBase;
import away3d.lights.PointLight;
import away3d.loaders.Loader3D;
import away3d.loaders.misc.AssetLoaderContext;
import away3d.loaders.parsers.AWDParser;
import away3d.loaders.parsers.Max3DSParser;
import away3d.loaders.parsers.MD5AnimParser;
import away3d.loaders.parsers.MD5MeshParser;
import away3d.loaders.parsers.OBJParser;
import away3d.materials.ColorMaterial;
import away3d.materials.MaterialBase;
import away3d.materials.SinglePassMaterialBase;
import away3d.materials.TextureMaterial;
import away3d.materials.lightpickers.StaticLightPicker;
import away3d.materials.methods.ColorTransformMethod;
import away3d.materials.methods.EnvMapMethod;
import away3d.materials.methods.FogMethod;
import away3d.materials.methods.RimLightMethod;
import away3d.primitives.CapsuleGeometry;
import away3d.primitives.CubeGeometry;
import away3d.primitives.CylinderGeometry;
import away3d.primitives.PlaneGeometry;
import away3d.primitives.SkyBox;
import away3d.primitives.SphereGeometry;
import away3d.primitives.TorusGeometry;
import away3d.textures.BitmapCubeTexture;
import away3d.textures.BitmapTexture;
import flixel.util.FlxColor;
import haxe.xml.Access;
import openfl.display.BitmapData;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix3D;
import openfl.geom.Vector3D;
import openfl.utils.ByteArray;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;
import soulscorch.backend.utils.ColorUtil;
import soulscorch.graphics.threed.Away3DManager;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef MeshTransformDef = {
    var x:Float;
    var y:Float;
    var z:Float;
    var rotX:Float;
    var rotY:Float;
    var rotZ:Float;
    var scaleX:Float;
    var scaleY:Float;
    var scaleZ:Float;
}

class ModelAPI {
    private static var _meshCache:Map<String, Mesh> = new Map<String, Mesh>();
    private static var _geometryCache:Map<String, Geometry> = new Map<String, Geometry>();
    private static var _materialCache:Map<String, MaterialBase> = new Map<String, MaterialBase>();
    private static var _textureCache:Map<String, BitmapTexture> = new Map<String, BitmapTexture>();
    private static var _animSetCache:Map<String, SkeletonAnimationSet> = new Map<String, SkeletonAnimationSet>();
    private static var _fallbackBitmap:BitmapData = null;
    private static var _defaultColorMat:ColorMaterial = null;

    public static var defaultMaterial(get, null):MaterialBase;
    private static function get_defaultMaterial():MaterialBase {
        if (_defaultColorMat == null) {
            _defaultColorMat = new ColorMaterial(0xCCCCCC);
        }
        return _defaultColorMat;
    }

    // =========================================================================
    // 1. Model Loading & .3soul / XML Integration
    // =========================================================================

    public static function loadMesh(modelPath:String, ?texturePath:String, ?onComplete:Mesh->Void, autoAddToScene:Bool = false):Null<ObjectContainer3D> {
        if (modelPath == null || modelPath.trim().length == 0) {
            Logger.warn("Cannot load mesh: empty model path provided.", "away3d");
            return null;
        }

        var resolvedModel:String = resolveModelPath(modelPath);
        if (resolvedModel == null || !AssetResolver.exists(resolvedModel)) {
            Logger.warn('3D Model file not found: $modelPath', "away3d");
            return null;
        }

        if (_meshCache.exists(resolvedModel)) {
            var cachedMesh:Mesh = cast(_meshCache.get(resolvedModel).clone(), Mesh);
            if (texturePath != null && texturePath.trim().length > 0) {
                cachedMesh.material = createTextureMaterial(texturePath);
            }
            if (autoAddToScene && Away3DManager.scene != null) {
                Away3DManager.scene.addChild(cachedMesh);
            }
            if (onComplete != null) onComplete(cachedMesh);
            return cachedMesh;
        }

        var loader:Loader3D = new Loader3D();
        var context:AssetLoaderContext = new AssetLoaderContext();
        var customMaterial:MaterialBase = (texturePath != null && texturePath.trim().length > 0) 
            ? createTextureMaterial(texturePath) 
            : new ColorMaterial(0xFFFFFF);

        var parser:Dynamic = getParserForExtension(resolvedModel);

        loader.addEventListener(Asset3DEvent.ASSET_COMPLETE, function(e:Asset3DEvent):Void {
            if (e.asset.assetType == Asset3DType.MESH) {
                var mesh:Mesh = cast(e.asset, Mesh);
                if (customMaterial != null) {
                    mesh.material = customMaterial;
                }
                mesh.pickingCollider = PickingColliderType.AUTO_FIRST_ENCOUNTERED;
                _meshCache.set(resolvedModel, cast(mesh.clone(), Mesh));
                _geometryCache.set(resolvedModel, mesh.geometry.clone());

                if (onComplete != null) onComplete(mesh);
            }
        });

        loader.addEventListener(LoaderEvent.RESOURCE_COMPLETE, function(e:LoaderEvent):Void {
            Logger.info('3D Model loaded successfully: $resolvedModel', "away3d");
            if (autoAddToScene && Away3DManager.scene != null) {
                Away3DManager.scene.addChild(loader);
            }
        });

        loader.addEventListener(LoaderEvent.LOAD_ERROR, function(e:LoaderEvent):Void {
            Logger.error('Failed to parse 3D Model: $resolvedModel -> ${e.message}', "away3d");
        });

        try {
            var bytes:ByteArray = loadByteArray(resolvedModel);
            if (bytes != null) {
                loader.loadData(bytes, context, null, parser);
            }
        } catch (e:Dynamic) {
            Logger.error('Exception while loading 3D model $resolvedModel: $e', "away3d");
            return null;
        }

        return loader;
    }

    /**
     * Parses an `<mesh>`, `<model>`, or `<primitive>` element from an .xmsoul manifest into a 3D object.
     */
    public static function loadModelFromXML(node:Access, ?lightPicker:StaticLightPicker):Null<ObjectContainer3D> {
        if (node == null) return null;

        var tag = node.name.toLowerCase();
        var container:ObjectContainer3D = null;

        if (tag == "primitive") {
            container = createPrimitiveFromXML(node);
        } else {
            var modelPath = XMSoul.getAttr(node, "model", XMSoul.getAttr(node, "src", ""));
            var texPath = XMSoul.getAttr(node, "texture", XMSoul.getAttr(node, "skin", ""));

            if (modelPath.length > 0) {
                container = loadMesh(modelPath, texPath.length > 0 ? texPath : null, function(mesh:Mesh) {
                    if (lightPicker != null) mesh.material.lightPicker = lightPicker;
                    applyMaterialAttributesFromXML(mesh.material, node);
                }, false);
            }
        }

        if (container != null) {
            applyTransformFromXML(container, node);

            if (node.hasNode.material && Std.isOfType(container, Mesh)) {
                var mesh = cast(container, Mesh);
                mesh.material = loadMaterialFromXML(node.node.material, lightPicker);
            }
        }

        return container;
    }

    // =========================================================================
    // 2. Primitives & Procedural Geometry
    // =========================================================================

    public static function createCube(width:Float = 100, height:Float = 100, depth:Float = 100, ?texturePath:String, color:Int = 0xFFFFFF, segmentsW:Int = 1, segmentsH:Int = 1, segmentsD:Int = 1):Mesh {
        var mat:MaterialBase = (texturePath != null) ? createTextureMaterial(texturePath) : createColorMaterial(color);
        return new Mesh(new CubeGeometry(width, height, depth, segmentsW, segmentsH, segmentsD, false), mat);
    }

    public static function createSphere(radius:Float = 50, ?texturePath:String, color:Int = 0xFFFFFF, segmentsW:Int = 16, segmentsH:Int = 12):Mesh {
        var mat:MaterialBase = (texturePath != null) ? createTextureMaterial(texturePath) : createColorMaterial(color);
        return new Mesh(new SphereGeometry(radius, segmentsW, segmentsH), mat);
    }

    public static function createPlane(width:Float = 500, height:Float = 500, ?texturePath:String, color:Int = 0xFFFFFF, doubleSided:Bool = true, segmentsW:Int = 1, segmentsH:Int = 1):Mesh {
        var mat:MaterialBase = (texturePath != null) ? createTextureMaterial(texturePath) : createColorMaterial(color);
        mat.bothSides = doubleSided;
        return new Mesh(new PlaneGeometry(width, height, segmentsW, segmentsH, true, doubleSided), mat);
    }

    public static function createCylinder(topRadius:Float = 50, bottomRadius:Float = 50, height:Float = 100, ?texturePath:String, color:Int = 0xFFFFFF, segmentsW:Int = 16, segmentsH:Int = 1):Mesh {
        var mat:MaterialBase = (texturePath != null) ? createTextureMaterial(texturePath) : createColorMaterial(color);
        return new Mesh(new CylinderGeometry(topRadius, bottomRadius, height, segmentsW, segmentsH), mat);
    }

    public static function createTorus(radius:Float = 50, tubeRadius:Float = 20, ?texturePath:String, color:Int = 0xFFFFFF, segmentsR:Int = 16, segmentsT:Int = 8):Mesh {
        var mat:MaterialBase = (texturePath != null) ? createTextureMaterial(texturePath) : createColorMaterial(color);
        return new Mesh(new TorusGeometry(radius, tubeRadius, segmentsR, segmentsT), mat);
    }

    public static function createCapsule(radius:Float = 30, height:Float = 100, ?texturePath:String, color:Int = 0xFFFFFF, segmentsW:Int = 16, segmentsH:Int = 12):Mesh {
        var mat:MaterialBase = (texturePath != null) ? createTextureMaterial(texturePath) : createColorMaterial(color);
        return new Mesh(new CapsuleGeometry(radius, height, segmentsW, segmentsH), mat);
    }

    public static function createSkybox(posX:String, negX:String, posY:String, negY:String, posZ:String, negZ:String):SkyBox {
        var cubeTex:BitmapCubeTexture = new BitmapCubeTexture(
            getBitmapDataSafe(posX),
            getBitmapDataSafe(negX),
            getBitmapDataSafe(posY),
            getBitmapDataSafe(negY),
            getBitmapDataSafe(posZ),
            getBitmapDataSafe(negZ)
        );
        return new SkyBox(cubeTex);
    }

    public static function createPrimitiveFromXML(node:Access):Null<Mesh> {
        var type = XMSoul.getAttr(node, "type", "cube").toLowerCase();
        var tex = XMSoul.getAttr(node, "texture", "");
        var col = parseColorAttr(node, "color", 0xFFFFFF);

        return switch (type) {
            case "cube", "box":
                createCube(
                    XMSoul.getFloatAttr(node, "width", 100),
                    XMSoul.getFloatAttr(node, "height", 100),
                    XMSoul.getFloatAttr(node, "depth", 100),
                    tex.length > 0 ? tex : null, col
                );
            case "sphere":
                createSphere(
                    XMSoul.getFloatAttr(node, "radius", 50),
                    tex.length > 0 ? tex : null, col,
                    XMSoul.getIntAttr(node, "segmentsW", 16),
                    XMSoul.getIntAttr(node, "segmentsH", 12)
                );
            case "plane":
                createPlane(
                    XMSoul.getFloatAttr(node, "width", 500),
                    XMSoul.getFloatAttr(node, "height", 500),
                    tex.length > 0 ? tex : null, col,
                    XMSoul.getBoolAttr(node, "doubleSided", true)
                );
            case "cylinder":
                createCylinder(
                    XMSoul.getFloatAttr(node, "topRadius", 50),
                    XMSoul.getFloatAttr(node, "bottomRadius", 50),
                    XMSoul.getFloatAttr(node, "height", 100),
                    tex.length > 0 ? tex : null, col
                );
            case "torus":
                createTorus(
                    XMSoul.getFloatAttr(node, "radius", 50),
                    XMSoul.getFloatAttr(node, "tubeRadius", 20),
                    tex.length > 0 ? tex : null, col
                );
            case "capsule":
                createCapsule(
                    XMSoul.getFloatAttr(node, "radius", 30),
                    XMSoul.getFloatAttr(node, "height", 100),
                    tex.length > 0 ? tex : null, col
                );
            default:
                createCube(100, 100, 100, tex.length > 0 ? tex : null, col);
        };
    }

    // =========================================================================
    // 3. Materials, Shaders & Methods
    // =========================================================================

    public static function createColorMaterial(color:Int = 0xFFFFFF, alpha:Float = 1.0, lightPicker:StaticLightPicker = null):ColorMaterial {
        var mat:ColorMaterial = new ColorMaterial(color, alpha);
        mat.lightPicker = lightPicker;
        mat.mipmap = true;
        return mat;
    }

    public static function createTextureMaterial(texturePath:String, smooth:Bool = true, repeat:Bool = false, mipmap:Bool = true):TextureMaterial {
        if (_materialCache.exists(texturePath) && Std.isOfType(_materialCache.get(texturePath), TextureMaterial)) {
            return cast(_materialCache.get(texturePath), TextureMaterial);
        }

        var texture:BitmapTexture = getTexture(texturePath);
        var mat:TextureMaterial = new TextureMaterial(texture, smooth, repeat, mipmap);
        mat.ambient = 0.25;
        mat.specular = 0.5;
        mat.gloss = 50;

        _materialCache.set(texturePath, mat);
        return mat;
    }

    public static function loadMaterialFromXML(node:Access, ?lightPicker:StaticLightPicker):MaterialBase {
        var texturePath = XMSoul.getAttr(node, "texture", XMSoul.getAttr(node, "diffuse", ""));
        var mat:MaterialBase = null;

        if (texturePath.length > 0) {
            mat = createTextureMaterial(
                texturePath,
                XMSoul.getBoolAttr(node, "smooth", true),
                XMSoul.getBoolAttr(node, "repeat", false),
                XMSoul.getBoolAttr(node, "mipmap", true)
            );
        } else {
            var col = parseColorAttr(node, "color", 0xFFFFFF);
            var alpha = XMSoul.getFloatAttr(node, "alpha", 1.0);
            mat = createColorMaterial(col, alpha);
        }

        mat.lightPicker = lightPicker;
        mat.bothSides = XMSoul.getBoolAttr(node, "bothSides", false);

        applyMaterialAttributesFromXML(mat, node);
        return mat;
    }

    public static function applyMaterialAttributesFromXML(material:MaterialBase, node:Access):Void {
        if (material == null || node == null) return;

        if (Std.isOfType(material, SinglePassMaterialBase)) {
            var spm:SinglePassMaterialBase = cast(material, SinglePassMaterialBase);

            spm.ambient = XMSoul.getFloatAttr(node, "ambient", spm.ambient);
            spm.specular = XMSoul.getFloatAttr(node, "specular", spm.specular);
            spm.gloss = XMSoul.getFloatAttr(node, "gloss", spm.gloss);

            if (node.has.normalMap) applyNormalMap(cast spm, node.att.normalMap);
            if (node.has.specularMap) applySpecularMap(cast spm, node.att.specularMap, spm.gloss);

            if (node.hasNode.rimLight) {
                var rl = node.node.rimLight;
                applyRimLighting(
                    spm,
                    parseColorAttr(rl, "color", 0xFFFFFF),
                    XMSoul.getFloatAttr(rl, "strength", 0.4),
                    XMSoul.getFloatAttr(rl, "power", 2.0)
                );
            }

            if (node.hasNode.fog) {
                var f = node.node.fog;
                applyDistanceFog(
                    spm,
                    XMSoul.getFloatAttr(f, "min", 500),
                    XMSoul.getFloatAttr(f, "max", 3000),
                    parseColorAttr(f, "color", 0x000000)
                );
            }
        }
    }

    public static function applyNormalMap(material:TextureMaterial, normalMapPath:String):Void {
        if (material == null) return;
        material.normalMap = getTexture(normalMapPath);
    }

    public static function applySpecularMap(material:TextureMaterial, specMapPath:String, gloss:Float = 50):Void {
        if (material == null) return;
        material.specularMap = getTexture(specMapPath);
        material.gloss = gloss;
    }

    public static function applyRimLighting(material:SinglePassMaterialBase, color:Int = 0xFFFFFF, strength:Float = 0.4, power:Float = 2.0):Void {
        if (material == null) return;
        material.addMethod(new RimLightMethod(color, strength, power));
    }

    public static function applyEnvironmentReflections(material:TextureMaterial, cubeMap:BitmapCubeTexture, reflectivity:Float = 0.5):Void {
        if (material == null || cubeMap == null) return;
        material.addMethod(new EnvMapMethod(cubeMap, reflectivity));
    }

    public static function applyDistanceFog(material:MaterialBase, minDistance:Float = 500, maxDistance:Float = 3000, fogColor:Int = 0x000000):Void {
        if (material == null) return;
        if (Std.isOfType(material, SinglePassMaterialBase)) {
            cast(material, SinglePassMaterialBase).addMethod(new FogMethod(minDistance, maxDistance, fogColor));
        }
    }

    public static function getTexture(path:String):BitmapTexture {
        if (_textureCache.exists(path)) {
            return _textureCache.get(path);
        }

        var bmd:BitmapData = getBitmapDataSafe(path);
        var texture:BitmapTexture = new BitmapTexture(bmd);
        _textureCache.set(path, texture);
        return texture;
    }

    // =========================================================================
    // 4. Lighting Rigging & XML Light Loaders
    // =========================================================================

    public static function createDirectionalLight(dirX:Float = 0, dirY:Float = -1, dirZ:Float = 1, color:Int = 0xFFFFFF, ambient:Float = 0.2, diffuse:Float = 0.8):DirectionalLight {
        var light:DirectionalLight = new DirectionalLight(dirX, dirY, dirZ);
        light.color = color;
        light.ambient = ambient;
        light.diffuse = diffuse;
        if (Away3DManager.scene != null) Away3DManager.scene.addChild(light);
        return light;
    }

    public static function createPointLight(posX:Float = 0, posY:Float = 100, posZ:Float = 0, radius:Float = 500, color:Int = 0xFFFFFF, ambient:Float = 0.1, diffuse:Float = 0.9):PointLight {
        var light:PointLight = new PointLight();
        light.x = posX;
        light.y = posY;
        light.z = posZ;
        light.radius = radius;
        light.color = color;
        light.ambient = ambient;
        light.diffuse = diffuse;
        if (Away3DManager.scene != null) Away3DManager.scene.addChild(light);
        return light;
    }

    public static function loadLightFromXML(node:Access):Null<LightBase> {
        if (node == null) return null;
        var type = XMSoul.getAttr(node, "type", "directional").toLowerCase();
        var color = parseColorAttr(node, "color", 0xFFFFFF);
        var ambient = XMSoul.getFloatAttr(node, "ambient", 0.2);
        var diffuse = XMSoul.getFloatAttr(node, "diffuse", 0.8);

        if (type == "point") {
            return createPointLight(
                XMSoul.getFloatAttr(node, "x", XMSoul.getFloatAttr(node, "posX", 0)),
                XMSoul.getFloatAttr(node, "y", XMSoul.getFloatAttr(node, "posY", 100)),
                XMSoul.getFloatAttr(node, "z", XMSoul.getFloatAttr(node, "posZ", 0)),
                XMSoul.getFloatAttr(node, "radius", 500),
                color, ambient, diffuse
            );
        }

        return createDirectionalLight(
            XMSoul.getFloatAttr(node, "dirX", 0),
            XMSoul.getFloatAttr(node, "dirY", -1),
            XMSoul.getFloatAttr(node, "dirZ", 1),
            color, ambient, diffuse
        );
    }

    public static function createLightPicker(lights:Array<LightBase>):StaticLightPicker {
        return new StaticLightPicker(cast lights);
    }

    public static function bindLightsToMesh(container:ObjectContainer3D, lightPicker:StaticLightPicker):Void {
        forEachMesh(container, function(mesh:Mesh) {
            mesh.material.lightPicker = lightPicker;
        });
    }

    // =========================================================================
    // 5. Rigging, Animation & Sockets
    // =========================================================================

    public static function loadSkeletalAnimation(animPath:String, animName:String, targetMesh:Mesh):Void {
        var resolvedPath:String = resolveFilePath(animPath, [".md5anim", ".3soul", ""]);
        if (resolvedPath == null || !AssetResolver.exists(resolvedPath)) {
            Logger.warn('Animation file not found: $animPath', "away3d");
            return;
        }

        var loader:Loader3D = new Loader3D();
        var parser:MD5AnimParser = new MD5AnimParser();

        loader.addEventListener(Asset3DEvent.ASSET_COMPLETE, function(e:Asset3DEvent):Void {
            if (e.asset.assetType == Asset3DType.ANIMATION_NODE) {
                var node:SkeletonClipNode = cast(e.asset, SkeletonClipNode);
                node.name = animName;

                var animator:SkeletonAnimator = cast(targetMesh.animator, SkeletonAnimator);
                if (animator != null) {
                    var animSet:SkeletonAnimationSet = cast(animator.animationSet, SkeletonAnimationSet);
                    if (animSet != null) {
                        try {
                            animSet.addAnimation(node);
                            Logger.info('Registered Skeletal Animation: $animName', "away3d");
                        } catch (e:Dynamic) {}
                    }
                }
            }
        });

        var bytes:ByteArray = loadByteArray(resolvedPath);
        if (bytes != null) {
            loader.loadData(bytes, new AssetLoaderContext(), null, parser);
        }
    }

    public static function playAnimation(mesh:Mesh, animName:String, crossfadeTime:Float = 0.2):Void {
        if (mesh == null || mesh.animator == null) return;
        var animator:SkeletonAnimator = cast(mesh.animator, SkeletonAnimator);
        if (animator != null) {
            animator.playbackSpeed = 1.0;
            if (crossfadeTime > 0) {
                animator.play(animName, new CrossfadeTransition(crossfadeTime));
            } else {
                animator.play(animName, null, 0);
            }
        }
    }

    public static function pauseAnimation(mesh:Mesh):Void {
        if (mesh == null || mesh.animator == null) return;
        var animator:SkeletonAnimator = cast(mesh.animator, SkeletonAnimator);
        if (animator != null) {
            animator.playbackSpeed = 0.0;
        }
    }

    public static function attachToSocket(parentContainer:ObjectContainer3D, childObject:ObjectContainer3D, offsetPos:Vector3D = null, offsetRot:Vector3D = null):Void {
        if (parentContainer == null || childObject == null) return;
        parentContainer.addChild(childObject);
        if (offsetPos != null) {
            childObject.x = offsetPos.x;
            childObject.y = offsetPos.y;
            childObject.z = offsetPos.z;
        }
        if (offsetRot != null) {
            childObject.rotationX = offsetRot.x;
            childObject.rotationY = offsetRot.y;
            childObject.rotationZ = offsetRot.z;
        }
    }

    public static function centerPivot(mesh:Mesh):Void {
        if (mesh == null || mesh.geometry == null) return;
        var matrix:Matrix3D = mesh.sceneTransform != null ? mesh.sceneTransform : new Matrix3D();
        mesh.geometry.applyTransformation(matrix);
        mesh.pivotPoint = new Vector3D(0, 0, 0);
    }

    public static function normalizeMeshScale(mesh:Mesh, targetSize:Float = 100.0):Void {
        if (mesh == null) return;
        try {
            var b = mesh.bounds;
            if (b != null && b.max != null && b.min != null) {
                var maxDimension:Float = Math.max(b.max.x - b.min.x, Math.max(b.max.y - b.min.y, b.max.z - b.min.z));
                if (maxDimension > 0) {
                    var scaleFactor:Float = targetSize / maxDimension;
                    mesh.scale(scaleFactor);
                }
            }
        } catch (e:Dynamic) {}
    }

    public static function setMeshTint(container:ObjectContainer3D, color:Int, alpha:Float = 1.0):Void {
        forEachMesh(container, function(mesh:Mesh) {
            if (Std.isOfType(mesh.material, SinglePassMaterialBase)) {
                var spm:SinglePassMaterialBase = cast(mesh.material, SinglePassMaterialBase);
                var ct = new ColorTransform();
                ct.color = color;
                ct.alphaMultiplier = alpha;
                spm.addMethod(new ColorTransformMethod());
            } else if (Std.isOfType(mesh.material, ColorMaterial)) {
                var colMat:ColorMaterial = cast(mesh.material, ColorMaterial);
                colMat.color = color;
                colMat.alpha = alpha;
            }
        });
    }

    public static function applyBillboard(container:ObjectContainer3D, cameraPos:Vector3D):Void {
        if (container == null || cameraPos == null) return;
        container.lookAt(cameraPos);
    }

    public static function forEachMesh(container:ObjectContainer3D, action:Mesh->Void):Void {
        if (container == null || action == null) return;

        if (Std.isOfType(container, Mesh)) {
            action(cast(container, Mesh));
        }

        for (i in 0...container.numChildren) {
            forEachMesh(container.getChildAt(i), action);
        }
    }

    // =========================================================================
    // 6. Path Resolution, Parsers & Utilities
    // =========================================================================

    public static function applyTransformFromXML(container:ObjectContainer3D, node:Access):Void {
        if (container == null || node == null) return;

        container.x = XMSoul.getFloatAttr(node, "x", container.x);
        container.y = XMSoul.getFloatAttr(node, "y", container.y);
        container.z = XMSoul.getFloatAttr(node, "z", container.z);

        container.rotationX = XMSoul.getFloatAttr(node, "rotX", XMSoul.getFloatAttr(node, "rotationX", container.rotationX));
        container.rotationY = XMSoul.getFloatAttr(node, "rotY", XMSoul.getFloatAttr(node, "rotationY", container.rotationY));
        container.rotationZ = XMSoul.getFloatAttr(node, "rotZ", XMSoul.getFloatAttr(node, "rotationZ", container.rotationZ));

        if (node.has.scale) {
            var s = XMSoul.getFloatAttr(node, "scale", 1.0);
            container.scaleX = s;
            container.scaleY = s;
            container.scaleZ = s;
        } else {
            container.scaleX = XMSoul.getFloatAttr(node, "scaleX", container.scaleX);
            container.scaleY = XMSoul.getFloatAttr(node, "scaleY", container.scaleY);
            container.scaleZ = XMSoul.getFloatAttr(node, "scaleZ", container.scaleZ);
        }
    }

    public static function resolveModelPath(path:String):String {
        var resolved:String = ModManager.getPath(path);
        if (!AssetResolver.exists(resolved)) {
            resolved = AssetResolver.resolveFile(path, [".3soul", ".obj", ".awd", ".3ds", ".md5mesh", ".fbx", ""]);
        }
        return resolved;
    }

    public static function resolveFilePath(path:String, extensions:Array<String>):String {
        var resolved:String = ModManager.getPath(path);
        if (!AssetResolver.exists(resolved)) {
            resolved = AssetResolver.resolveFile(path, extensions);
        }
        return resolved;
    }

    private static function loadByteArray(path:String):ByteArray {
        #if sys
        if (FileSystem.exists(path)) {
            return ByteArray.fromBytes(File.getBytes(path));
        }
        #end
        return AssetResolver.getBytes(path);
    }

    private static function getBitmapDataSafe(path:String):BitmapData {
        var resolved:String = resolveFilePath(path, [".png", ".jpg", ".jpeg", ""]);
        if (resolved != null && AssetResolver.exists(resolved)) {
            var bmd:BitmapData = AssetResolver.getBitmapData(resolved);
            if (bmd != null) return bmd;
        }
        Logger.warn('Texture image not found: $path. Using magenta placeholder fallback.', "away3d");
        if (_fallbackBitmap == null) {
            _fallbackBitmap = new BitmapData(64, 64, false, 0xFF00FF);
        }
        return _fallbackBitmap;
    }

    private static function getParserForExtension(path:String):Dynamic {
        var ext:String = path.substring(path.lastIndexOf(".") + 1).toLowerCase();

        if (ext == "3soul") {
            try {
                var bytes = loadByteArray(path);
                if (bytes != null && bytes.length >= 3) {
                    bytes.position = 0;
                    var b1 = bytes.readUnsignedByte();
                    var b2 = bytes.readUnsignedByte();
                    var b3 = bytes.readUnsignedByte();

                    // AWD signature: 'A', 'W', 'D'
                    if (b1 == 65 && b2 == 87 && b3 == 68) return new AWDParser();
                    // 3DS binary chunk: 0x4D, 0x4D
                    if (b1 == 0x4D && b2 == 0x4D) return new Max3DSParser();
                }
            } catch (e:Dynamic) {}
            return new OBJParser();
        }

        return switch (ext) {
            case "awd": new AWDParser();
            case "3ds": new Max3DSParser();
            case "md5mesh": new MD5MeshParser();
            case "obj": new OBJParser();
            default: new OBJParser();
        };
    }

    private static function parseColorAttr(node:Access, attrName:String, fallback:Int = 0xFFFFFF):Int {
        if (node.has.resolve(attrName)) {
            var raw = node.att.resolve(attrName);
            if (raw.startsWith("0x") || raw.startsWith("#")) return ColorUtil.fromHexSafe(raw, fallback);
            var parsed = Std.parseInt(raw);
            return parsed != null ? parsed : fallback;
        }
        return fallback;
    }

    public static function clearCache():Void {
        for (mesh in _meshCache) mesh.dispose();
        for (geo in _geometryCache) geo.dispose();
        for (mat in _materialCache) mat.dispose();
        for (tex in _textureCache) tex.dispose();

        if (_fallbackBitmap != null) {
            _fallbackBitmap.dispose();
            _fallbackBitmap = null;
        }
        if (_defaultColorMat != null) {
            _defaultColorMat.dispose();
            _defaultColorMat = null;
        }

        _meshCache.clear();
        _geometryCache.clear();
        _materialCache.clear();
        _textureCache.clear();
        _animSetCache.clear();
        Logger.info("[ModelAPI] Global 3D model, geometry, texture, and animation caches wiped.", "away3d");
    }
}