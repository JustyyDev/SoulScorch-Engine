package soulscorch.graphics.threed;

import away3d.containers.ObjectContainer3D;
import away3d.entities.Mesh;
import away3d.lights.DirectionalLight;
import away3d.lights.LightBase;
import away3d.lights.PointLight;
import away3d.materials.lightpickers.StaticLightPicker;
import away3d.primitives.SkyBox;
import flixel.FlxBasic;
import haxe.xml.Access;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.system.apis.ModelAPI;
import soulscorch.backend.utils.Logger;

class Stage3D extends FlxBasic {
    public var stageContainer:ObjectContainer3D;
    public var skybox:SkyBox;
    public var lightPicker:StaticLightPicker;
    public var activeLights:Array<LightBase> = [];
    public var loadedMeshes:Map<String, ObjectContainer3D> = new Map<String, ObjectContainer3D>();

    public var stageName:String;

    public function new(stageName:String) {
        super();
        this.stageName = stageName;
        stageContainer = new ObjectContainer3D();
        if (Away3DManager.scene != null) {
            Away3DManager.scene.addChild(stageContainer);
        }
        loadFromXMSoul(stageName);
    }

    public function loadFromXMSoul(stageId:String):Void {
        var access:Access = XMSoul.parse('stages/$stageId');
        if (access == null) access = XMSoul.parse('data/stages/$stageId');

        if (access == null) {
            Logger.warn('Failed locating 3D stage manifest: $stageId', "stage3d");
            return;
        }

        // 1. Skybox
        if (access.hasNode.skybox) {
            var s = access.node.skybox;
            skybox = ModelAPI.createSkybox(
                XMSoul.getAttr(s, "posX", ""),
                XMSoul.getAttr(s, "negX", ""),
                XMSoul.getAttr(s, "posY", ""),
                XMSoul.getAttr(s, "negY", ""),
                XMSoul.getAttr(s, "posZ", ""),
                XMSoul.getAttr(s, "negZ", "")
            );
            if (Away3DManager.scene != null && skybox != null) {
                Away3DManager.scene.addChild(skybox);
            }
        }

        // 2. Lights
        if (access.hasNode.lights) {
            for (l in access.node.lights.nodes.light) {
                var lType = XMSoul.getAttr(l, "type", "directional").toLowerCase();
                var col = Std.parseInt(XMSoul.getAttr(l, "color", "0xFFFFFF"));
                var amb = XMSoul.getFloatAttr(l, "ambient", 0.2);
                var diff = XMSoul.getFloatAttr(l, "diffuse", 0.8);

                if (lType == "point") {
                    var pLight = ModelAPI.createPointLight(
                        XMSoul.getFloatAttr(l, "posX", 0),
                        XMSoul.getFloatAttr(l, "posY", 100),
                        XMSoul.getFloatAttr(l, "posZ", 0),
                        XMSoul.getFloatAttr(l, "radius", 500),
                        col, amb, diff
                    );
                    activeLights.push(pLight);
                } else {
                    var dLight = ModelAPI.createDirectionalLight(
                        XMSoul.getFloatAttr(l, "dirX", 0),
                        XMSoul.getFloatAttr(l, "dirY", -1),
                        XMSoul.getFloatAttr(l, "dirZ", 1),
                        col, amb, diff
                    );
                    activeLights.push(dLight);
                }
            }
            if (activeLights.length > 0) {
                lightPicker = ModelAPI.createLightPicker(activeLights);
            }
        }

        // 3. Meshes (.3soul / .obj / .awd)
        if (access.hasNode.models) {
            for (mNode in access.node.models.nodes.mesh) {
                var mId = XMSoul.getAttr(mNode, "id", "prop");
                var mPath = XMSoul.getAttr(mNode, "model", "");
                var tPath = XMSoul.getAttr(mNode, "texture", "");

                var container = ModelAPI.loadMesh(mPath, tPath, function(mesh:Mesh) {
                    if (lightPicker != null) mesh.material.lightPicker = lightPicker;
                }, false);

                if (container != null) {
                    container.x = XMSoul.getFloatAttr(mNode, "x", 0);
                    container.y = XMSoul.getFloatAttr(mNode, "y", 0);
                    container.z = XMSoul.getFloatAttr(mNode, "z", 0);
                    container.rotationX = XMSoul.getFloatAttr(mNode, "rotX", 0);
                    container.rotationY = XMSoul.getFloatAttr(mNode, "rotY", 0);
                    container.rotationZ = XMSoul.getFloatAttr(mNode, "rotZ", 0);

                    var s = XMSoul.getFloatAttr(mNode, "scale", 1.0);
                    container.scaleX = s;
                    container.scaleY = s;
                    container.scaleZ = s;

                    stageContainer.addChild(container);
                    loadedMeshes.set(mId, container);
                }
            }
        }
    }

    override public function destroy():Void {
        if (skybox != null && Away3DManager.scene != null) {
            Away3DManager.scene.removeChild(skybox);
            skybox.dispose();
        }
        if (stageContainer != null && Away3DManager.scene != null) {
            Away3DManager.scene.removeChild(stageContainer);
            stageContainer.disposeWithChildren();
        }
        activeLights = [];
        loadedMeshes.clear();
        super.destroy();
    }
}