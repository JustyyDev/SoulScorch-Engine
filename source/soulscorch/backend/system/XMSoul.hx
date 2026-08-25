package soulscorch.backend.system;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import haxe.xml.Access;
import lime.app.Application;
import openfl.Lib;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.ColorUtil;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

// ==========================================
// Strongly-Typed XMSoul Models & Data Schemas
// ==========================================

typedef XMSoulWindowConfig = {
    var title:String;
    var width:Int;
    var height:Int;
    var fullscreen:Bool;
    var resizable:Bool;
    var borderless:Bool;
    var vsync:Bool;
    var fps:Int;
    var backgroundColor:FlxColor;
}

typedef XMSoulModConfig = {
    var id:String;
    var name:String;
    var version:String;
    var author:String;
    var apiVersion:String;
    var description:String;
    var folders:Map<String, String>;
    var scripts:Array<{path:String, isGlobal:Bool}>;
    var flags:Map<String, Dynamic>;
}

typedef XMSoulNoteSkinConfig = {
    var name:String;
    var sprite:String;
    var scale:Float;
    var antialiasing:Bool;
    var receptors:Array<{lane:Int, staticAnim:String, pressedAnim:String, confirmAnim:String}>;
    var tapNotes:Array<{lane:Int, anim:String}>;
    var sustains:{alpha:Float, width:Float, holds:Array<{lane:Int, body:String, end:String}>};
}

typedef XMSoulSplashSkinConfig = {
    var name:String;
    var sprite:String;
    var scale:Float;
    var alpha:Float;
    var antialiasing:Bool;
    var lanes:Map<Int, Array<{name:String, prefix:String, x:Float, y:Float, fps:Int}>>;
}

typedef XMSoulFreeplaySong = {
    var id:String;
    var name:String;
    var icon:String;
    var color:FlxColor;
    var bpm:Float;
    var previewTime:Float;
    var difficulties:Array<String>;
    var category:String;
}

typedef XMSoulJudgment = {
    var name:String;
    var threshold:Float;
    var score:Int;
    var health:Float;
    var accuracy:Float;
    var noteSplash:Bool;
    var graphic:String;
}

typedef XMSoulJudgmentConfig = {
    var safeZoneOffset:Float;
    var judgments:Array<XMSoulJudgment>;
}

typedef XMSoulComboPopup = {
    var offsetX:Float;
    var offsetY:Float;
    var scale:Float;
    var alphaFadeDuration:Float;
    var antialiasing:Bool;
    var ratingVelocity:{xMin:Float, xMax:Float, yMin:Float, yMax:Float, gravity:Float};
    var numberVelocity:{xMin:Float, xMax:Float, yMin:Float, yMax:Float, gravity:Float, spacing:Float, scale:Float};
}

typedef XMSoulDiscordConfig = {
    var enabled:Bool;
    var clientID:String;
    var defaultLargeKey:String;
    var defaultLargeText:String;
}

typedef XMSoulGithubConfig = {
    var owner:String;
    var repo:String;
    var autoNotify:Bool;
}

typedef XMSoulTransitionConfig = {
    var type:String;
    var duration:Float;
    var ease:String;
    var color:FlxColor;
    var sound:String;
}

typedef XMSoulSceneConfig = {
    var defaultZoom:Float;
    var antialiasing:Bool;
    var bgColor:FlxColor;
    var beatTracking:Bool;
}

typedef XMSoulStageObject = {
    var id:String;
    var image:String;
    var x:Float;
    var y:Float;
    var scaleX:Float;
    var scaleY:Float;
    var scrollX:Float;
    var scrollY:Float;
    var zIndex:Int;
    var alpha:Float;
    var antialiasing:Bool;
}

typedef XMSoulStageConfig = {
    var name:String;
    var defaultZoom:Float;
    var camPos:Array<Float>;
    var positions:Map<String, Array<Float>>;
    var objects:Array<XMSoulStageObject>;
}

typedef XMSoulCharacterConfig = {
    var image:String;
    var icon:String;
    var isPlayer:Bool;
    var isGF:Bool;
    var flipX:Bool;
    var scale:Float;
    var antialiasing:Bool;
    var cameraOffset:Array<Float>;
    var positionOffset:Array<Float>;
    var healthColor:FlxColor;
    var animations:Array<{name:String, prefix:String, fps:Int, loop:Bool, indices:Array<Int>, offset:Array<Float>}>;
}

typedef XMSoulDialogueLine = {
    var portrait:String;
    var box:String;
    var text:String;
    var speed:Float;
    var sound:String;
    var side:String;
}

typedef XMSoulSongModifiers = {
    var scrollSpeedMultiplier:Float;
    var ghostTapping:Bool;
    var healthDrain:Float;
    var drainFloor:Float;
    var maxHealth:Float;
}

typedef XMSoulIconConfig = {
    var frameCount:Int;
    var normalFrame:Int;
    var losingFrame:Int;
    var winningFrame:Int;
    var targetSize:Float;
    var minScale:Float;
    var maxScale:Float;
    var antialiasing:Bool;
    var bopIntensity:Float;
    var bopSpeed:Float;
    var rotationBop:Float;
    var offsetX:Float;
    var offsetY:Float;
    var pulseOnLowHealth:Bool;
    var scale:Float;
}

class XMSoul {
    private static var cache:Map<String, Access> = new Map<String, Access>();

    public static function parse(path:String, useCache:Bool = true, warnOnFail:Bool = true):Null<Access> {
        if (path == null || path.trim().length == 0) return null;
        var clean = path.trim().replace("\\", "/");
        while (clean.startsWith("/")) clean = clean.substr(1);

        if (useCache && cache.exists(clean)) {
            return cache.get(clean);
        }

        var rawText:String = null;
        var isAbsolutePath:Bool = clean.indexOf(":") != -1 || StringTools.startsWith(clean, "/");

        if (!isAbsolutePath) {
            var resolved = AssetResolver.resolveFile(clean, [".xmsoul", ".xml", ""]);
            if (resolved != null) {
                try {
                    rawText = AssetResolver.getText(resolved);
                } catch (e:Dynamic) {}
            }
        }

        #if sys
        if (rawText == null && FileSystem.exists(clean) && !FileSystem.isDirectory(clean)) {
            try { rawText = File.getContent(clean); } catch (e:Dynamic) {}
        }
        #end

        if (rawText == null && isAbsolutePath) {
            var resolved = AssetResolver.resolveFile(clean, [".xmsoul", ".xml", ""]);
            if (resolved != null) {
                rawText = AssetResolver.getText(resolved);
            }
        }

        if (rawText != null && rawText.trim().length > 0) {
            try {
                var sanitizedXml = sanitizeXml(rawText.trim());
                var rawXml = Xml.parse(sanitizedXml);
                var firstElem:Xml = null;

                for (elem in rawXml.elements()) {
                    firstElem = elem;
                    break;
                }

                if (firstElem == null) {
                    if (warnOnFail) Logger.warn('XMSoul parser found empty XML structure in: $clean', "xmsoul");
                    return null;
                }

                var access = new Access(firstElem);
                if (useCache) cache.set(clean, access);
                return access;
            } catch (e:Dynamic) {
                // Secondary recovery attempt with raw text
                try {
                    var fallbackXml = Xml.parse(rawText.trim());
                    var firstElem:Xml = null;
                    for (elem in fallbackXml.elements()) {
                        firstElem = elem;
                        break;
                    }
                    if (firstElem != null) {
                        var access = new Access(firstElem);
                        if (useCache) cache.set(clean, access);
                        return access;
                    }
                } catch (err:Dynamic) {
                    if (warnOnFail) {
                        Logger.warn('XMSoul Parse Failure [$clean]: $err', "xmsoul");
                    }
                }
            }
        }

        return null;
    }

    public static function sanitizeXml(xmlContent:String):String {
        if (xmlContent == null || xmlContent.length == 0) return xmlContent;

        var lines = xmlContent.split("\n");
        var output:Array<String> = [];
        var attrRegex = ~/([a-zA-Z0-9_:]+)\s*=\s*(['"])(.*?)\2/g;

        for (line in lines) {
            var trimmed = line.trim();
            if (!trimmed.startsWith("<") || trimmed.startsWith("<!--") || trimmed.startsWith("<?")) {
                output.push(line);
                continue;
            }

            var tagEnd = trimmed.indexOf(" ");
            if (tagEnd == -1) tagEnd = trimmed.indexOf(">");
            if (tagEnd == -1) {
                output.push(line);
                continue;
            }

            var tagName = trimmed.substring(1, tagEnd);
            var isSelfClosing = trimmed.endsWith("/>");

            var seenAttrs:Map<String, Bool> = new Map<String, Bool>();
            var cleanedAttrs:Array<String> = [];
            var textToScan = trimmed;

            while (attrRegex.match(textToScan)) {
                var attrName = attrRegex.matched(1);
                var fullAttr = attrRegex.matched(0);

                if (!seenAttrs.exists(attrName)) {
                    seenAttrs.set(attrName, true);
                    cleanedAttrs.push(fullAttr);
                }

                textToScan = attrRegex.matchedRight();
            }

            if (cleanedAttrs.length > 0) {
                output.push('\t<$tagName ' + cleanedAttrs.join(" ") + (isSelfClosing ? "/>" : ">"));
            } else {
                output.push(line);
            }
        }

        return output.join("\n");
    }

    // ==========================================
    // Core Attribute Accessors
    // ==========================================

    public static function getAttr(node:Access, name:String, defaultVal:String = ""):String {
        if (node == null) return defaultVal;
        return (node.has.resolve(name)) ? node.att.resolve(name) : defaultVal;
    }

    public static function getFloatAttr(node:Access, name:String, defaultVal:Float = 0.0):Float {
        if (node == null || !node.has.resolve(name)) return defaultVal;
        var val = Std.parseFloat(node.att.resolve(name));
        return Math.isNaN(val) ? defaultVal : val;
    }

    public static function getIntAttr(node:Access, name:String, defaultVal:Int = 0):Int {
        if (node == null || !node.has.resolve(name)) return defaultVal;
        var val = Std.parseInt(node.att.resolve(name));
        return val == null ? defaultVal : val;
    }

    public static function getBoolAttr(node:Access, name:String, defaultVal:Bool = false):Bool {
        if (node == null || !node.has.resolve(name)) return defaultVal;
        var v = node.att.resolve(name).toLowerCase().trim();
        return (v == "true" || v == "1" || v == "yes");
    }

    public static function getColorAttr(node:Access, name:String, defaultColor:FlxColor = FlxColor.WHITE):FlxColor {
        if (node == null || !node.has.resolve(name)) return defaultColor;
        return ColorUtil.fromHexSafe(node.att.resolve(name), defaultColor);
    }

    public static function getArrayAttr(node:Access, name:String, delimiter:String = ","):Array<String> {
        if (node == null || !node.has.resolve(name)) return [];
        var raw = node.att.resolve(name);
        var result:Array<String> = [];
        for (item in raw.split(delimiter)) {
            var trimmed = item.trim();
            if (trimmed.length > 0) result.push(trimmed);
        }
        return result;
    }

    public static function getFloatArrayAttr(node:Access, name:String, delimiter:String = ","):Array<Float> {
        var strArr = getArrayAttr(node, name, delimiter);
        var floatArr:Array<Float> = [];
        for (s in strArr) {
            var v = Std.parseFloat(s);
            if (!Math.isNaN(v)) floatArr.push(v);
        }
        return floatArr;
    }

    public static function loadIconConfig(path:String):Null<XMSoulIconConfig> {
        var doc = parse(path, true, false);
        if (doc == null) return null;
        var iconNode = doc.hasNode.resolve("icon") ? doc.node.resolve("icon") : doc;

        var frames = getIntAttr(iconNode, "frames", getIntAttr(iconNode, "frameCount", 0));
        var defaultNormal = frames >= 3 ? 1 : 0;
        var defaultLosing = frames >= 3 ? 2 : (frames == 2 ? 1 : 0);
        return {
            frameCount: frames,
            normalFrame: getIntAttr(iconNode, "normalFrame", getIntAttr(iconNode, "normal", defaultNormal)),
            losingFrame: getIntAttr(iconNode, "losingFrame", getIntAttr(iconNode, "losing", defaultLosing)),
            winningFrame: getIntAttr(iconNode, "winningFrame", getIntAttr(iconNode, "winning", 0)),
            targetSize: getFloatAttr(iconNode, "targetSize", 150.0),
            minScale: getFloatAttr(iconNode, "minScale", 0.5),
            maxScale: getFloatAttr(iconNode, "maxScale", 2.0),
            antialiasing: getBoolAttr(iconNode, "antialiasing", true),
            bopIntensity: getFloatAttr(iconNode, "bopIntensity", 1.2),
            bopSpeed: getFloatAttr(iconNode, "bopSpeed", 12.0),
            rotationBop: getFloatAttr(iconNode, "rotationBop", 4.0),
            offsetX: getFloatAttr(iconNode, "offsetX", 0.0),
            offsetY: getFloatAttr(iconNode, "offsetY", 0.0),
            pulseOnLowHealth: getBoolAttr(iconNode, "pulseOnLowHealth", true),
            scale: getFloatAttr(iconNode, "scale", 1.0)
        };
    }

    // ==========================================
    // Window System
    // ==========================================

    public static function loadWindowConfig(path:String = "window.xmsoul"):XMSoulWindowConfig {
        var doc = parse(path, true, false);
        return {
            title: getAttr(doc, "title", "SoulScorch Engine"),
            width: getIntAttr(doc, "width", 1280),
            height: getIntAttr(doc, "height", 720),
            fullscreen: getBoolAttr(doc, "fullscreen", false),
            resizable: getBoolAttr(doc, "resizable", true),
            borderless: getBoolAttr(doc, "borderless", false),
            vsync: getBoolAttr(doc, "vsync", false),
            fps: getIntAttr(doc, "fps", 120),
            backgroundColor: getColorAttr(doc, "bgColor", FlxColor.BLACK)
        };
    }

    public static function applyWindowSettings(path:String = "window.xmsoul"):Void {
        var conf = loadWindowConfig(path);
        var win = Lib.application != null ? Lib.application.window : Application.current.window;
        if (win != null) {
            win.title = conf.title;
            win.resizable = conf.resizable;
            win.borderless = conf.borderless;

            if (conf.width > 0 && conf.height > 0) {
                win.resize(conf.width, conf.height);
            }

            if (conf.fullscreen) {
                win.fullscreen = true;
            }
        }

        if (conf.fps > 0) {
            FlxG.updateFramerate = conf.fps;
            FlxG.drawFramerate = conf.fps;
        }

        Logger.info('Applied native window settings: "${conf.title}" (${conf.width}x${conf.height}, ${conf.fps} FPS)', "main");
    }

    // ==========================================
    // Mod & Package Configs
    // ==========================================

    public static function loadModConfig(path:String):Null<XMSoulModConfig> {
        var doc = parse(path, true, false);
        if (doc == null) return null;

        var config:XMSoulModConfig = {
            id: getAttr(doc, "id", "mod"),
            name: getAttr(doc, "name", "Mod"),
            version: getAttr(doc, "version", "1.0.0"),
            author: getAttr(doc, "author", "Unknown"),
            apiVersion: getAttr(doc, "apiVersion", "1.0.0"),
            description: doc.hasNode.resolve("description") ? getAttr(doc.node.resolve("description"), "text", "") : "",
            folders: new Map<String, String>(),
            scripts: [],
            flags: new Map<String, Dynamic>()
        };

        if (doc.hasNode.resolve("assets")) {
            for (folder in doc.node.resolve("assets").nodes.resolve("folder")) {
                config.folders.set(getAttr(folder, "path"), getAttr(folder, "target"));
            }
        }

        if (doc.hasNode.resolve("scripts")) {
            for (script in doc.node.resolve("scripts").nodes.resolve("script")) {
                config.scripts.push({
                    path: getAttr(script, "path"),
                    isGlobal: getBoolAttr(script, "global", false)
                });
            }
        }

        if (doc.hasNode.resolve("flags")) {
            for (flag in doc.node.resolve("flags").nodes.resolve("flag")) {
                var name = getAttr(flag, "name");
                var rawVal = getAttr(flag, "value");
                if (rawVal == "true" || rawVal == "false") {
                    config.flags.set(name, rawVal == "true");
                } else if (!Math.isNaN(Std.parseFloat(rawVal))) {
                    config.flags.set(name, Std.parseFloat(rawVal));
                } else {
                    config.flags.set(name, rawVal);
                }
            }
        }

        return config;
    }

    // ==========================================
    // Note Skin & Splash Skin Parsers
    // ==========================================

    public static function loadNoteSkin(path:String):Null<XMSoulNoteSkinConfig> {
        var doc = parse(path, true, false);
        if (doc == null || doc.name != "noteSkin") return null;

        var skin:XMSoulNoteSkinConfig = {
            name: getAttr(doc, "name", "default"),
            sprite: getAttr(doc, "sprite", "NOTE_assets"),
            scale: getFloatAttr(doc, "scale", 0.7),
            antialiasing: getBoolAttr(doc, "antialiasing", true),
            receptors: [],
            tapNotes: [],
            sustains: {alpha: 0.7, width: 50, holds: []}
        };

        if (doc.hasNode.resolve("strums")) {
            for (r in doc.node.resolve("strums").nodes.resolve("strum")) {
                skin.receptors.push({
                    lane: getIntAttr(r, "lane", 0),
                    staticAnim: getAttr(r, "static", ""),
                    pressedAnim: getAttr(r, "press", getAttr(r, "pressed", "")),
                    confirmAnim: getAttr(r, "confirm", "")
                });
            }
        }

        if (doc.hasNode.resolve("notes")) {
            for (t in doc.node.resolve("notes").nodes.resolve("note")) {
                skin.tapNotes.push({
                    lane: getIntAttr(t, "lane", 0),
                    anim: getAttr(t, "anim", "")
                });
            }
        }

        if (doc.hasNode.resolve("sustains")) {
            var sus = doc.node.resolve("sustains");
            skin.sustains.alpha = getFloatAttr(sus, "alpha", 0.7);
            skin.sustains.width = getFloatAttr(sus, "width", 50);

            for (h in sus.nodes.resolve("hold")) {
                skin.sustains.holds.push({
                    lane: getIntAttr(h, "lane", 0),
                    body: getAttr(h, "piece", getAttr(h, "body", "")),
                    end: getAttr(h, "end", "")
                });
            }
        }

        return skin;
    }

    public static function loadSplashSkin(path:String):Null<XMSoulSplashSkinConfig> {
        var doc = parse(path, true, false);
        if (doc == null) return null;

        var splash:XMSoulSplashSkinConfig = {
            name: getAttr(doc, "name", "default"),
            sprite: getAttr(doc, "sprite", "ui/game/noteskins/splashes/default"),
            scale: getFloatAttr(doc, "scale", 1.0),
            alpha: getFloatAttr(doc, "alpha", 0.6),
            antialiasing: getBoolAttr(doc, "antialiasing", true),
            lanes: new Map<Int, Array<{name:String, prefix:String, x:Float, y:Float, fps:Int}>>()
        };

        if (doc.hasNode.resolve("lanes")) {
            var lanesNode = doc.node.resolve("lanes");
            var defaultFps = getIntAttr(lanesNode, "fps", 24);

            for (lane in lanesNode.nodes.resolve("lane")) {
                var laneId = getIntAttr(lane, "id", 0);
                var anims:Array<{name:String, prefix:String, x:Float, y:Float, fps:Int}> = [];

                for (anim in lane.nodes.resolve("anim")) {
                    anims.push({
                        name: getAttr(anim, "name", "splash"),
                        prefix: getAttr(anim, "prefix", ""),
                        x: getFloatAttr(anim, "x", 0.0),
                        y: getFloatAttr(anim, "y", 0.0),
                        fps: getIntAttr(anim, "fps", defaultFps)
                    });
                }
                splash.lanes.set(laneId, anims);
            }
        }

        return splash;
    }

    public static function loadFreeplayList(path:String = "data/freeplayList.xmsoul"):Array<XMSoulFreeplaySong> {
        var doc = parse(path, true, false);
        if (doc == null) return [];

        var list:Array<XMSoulFreeplaySong> = [];
        for (song in doc.nodes.resolve("song")) {
            list.push({
                id: getAttr(song, "id"),
                name: getAttr(song, "name"),
                icon: getAttr(song, "icon", "face"),
                color: getColorAttr(song, "color", FlxColor.fromRGB(165, 0, 77)),
                bpm: getFloatAttr(song, "bpm", 100),
                previewTime: getFloatAttr(song, "previewTime", 0),
                difficulties: getArrayAttr(song, "difficulties", ","),
                category: getAttr(song, "category", "Main")
            });
        }
        return list;
    }

    public static function loadJudgments(path:String = "data/judgments.xmsoul"):XMSoulJudgmentConfig {
        var doc = parse(path, true, false);
        var list:Array<XMSoulJudgment> = [];
        var safeOffset = getFloatAttr(doc, "safeZoneOffset", 166.6);

        if (doc != null) {
            for (j in doc.nodes.resolve("judgment")) {
                list.push({
                    name: getAttr(j, "name"),
                    threshold: getFloatAttr(j, "threshold"),
                    score: getIntAttr(j, "score"),
                    health: getFloatAttr(j, "health"),
                    accuracy: getFloatAttr(j, "accuracy"),
                    noteSplash: getBoolAttr(j, "noteSplash", false),
                    graphic: getAttr(j, "graphic")
                });
            }
        }
        return {safeZoneOffset: safeOffset, judgments: list};
    }

    public static function loadComboPopup(path:String = "data/comboPopup.xmsoul"):XMSoulComboPopup {
        var doc = parse(path, true, false);
        var def:XMSoulComboPopup = {
            offsetX: getFloatAttr(doc, "offsetX", 0.55),
            offsetY: getFloatAttr(doc, "offsetY", -40),
            scale: getFloatAttr(doc, "scale", 0.7),
            alphaFadeDuration: getFloatAttr(doc, "alphaFadeDuration", 0.2),
            antialiasing: getBoolAttr(doc, "antialiasing", true),
            ratingVelocity: {xMin: -10, xMax: 0, yMin: -175, yMax: -140, gravity: 550},
            numberVelocity: {xMin: -5, xMax: 5, yMin: -150, yMax: -120, gravity: 550, spacing: 28, scale: 0.55}
        };

        if (doc != null) {
            if (doc.hasNode.resolve("ratingVelocity")) {
                var r = doc.node.resolve("ratingVelocity");
                def.ratingVelocity = {
                    xMin: getFloatAttr(r, "xMin", -10),
                    xMax: getFloatAttr(r, "xMax", 0),
                    yMin: getFloatAttr(r, "yMin", -175),
                    yMax: getFloatAttr(r, "yMax", -140),
                    gravity: getFloatAttr(r, "gravity", 550)
                };
            }
            if (doc.hasNode.resolve("numberVelocity")) {
                var n = doc.node.resolve("numberVelocity");
                def.numberVelocity = {
                    xMin: getFloatAttr(n, "xMin", -5),
                    xMax: getFloatAttr(n, "xMax", 5),
                    yMin: getFloatAttr(n, "yMin", -150),
                    yMax: getFloatAttr(n, "yMax", -120),
                    gravity: getFloatAttr(n, "gravity", 550),
                    spacing: getFloatAttr(n, "spacing", 28),
                    scale: getFloatAttr(n, "scale", 0.55)
                };
            }
        }
        return def;
    }

    public static function loadDiscordConfig(path:String = "data/discord.xmsoul"):XMSoulDiscordConfig {
        var doc = parse(path, true, false);
        return {
            enabled: getBoolAttr(doc, "enabled", true),
            clientID: getAttr(doc, "clientID", ""),
            defaultLargeKey: getAttr(doc, "defaultLargeKey", "icon"),
            defaultLargeText: getAttr(doc, "defaultLargeText", "SoulScorch Engine")
        };
    }

    public static function loadGithubConfig(path:String = "data/github.xmsoul"):XMSoulGithubConfig {
        var doc = parse(path, true, false);
        return {
            owner: getAttr(doc, "owner", "JustyyDev"),
            repo: getAttr(doc, "repo", "SoulScorch-Engine"),
            autoNotify: getBoolAttr(doc, "autoNotify", true)
        };
    }

    public static function loadTransitions(path:String = "data/transitions.xmsoul"):XMSoulTransitionConfig {
        var doc = parse(path, true, false);
        return {
            type: getAttr(doc, "type", "fade"),
            duration: getFloatAttr(doc, "duration", 0.35),
            ease: getAttr(doc, "ease", "quartOut"),
            color: getColorAttr(doc, "color", FlxColor.BLACK),
            sound: getAttr(doc, "sound", "scrollMenu")
        };
    }

    public static function loadScene(path:String = "data/scene.xmsoul"):XMSoulSceneConfig {
        var doc = parse(path, true, false);
        return {
            defaultZoom: getFloatAttr(doc, "defaultZoom", 1.0),
            antialiasing: getBoolAttr(doc, "antialiasing", true),
            bgColor: getColorAttr(doc, "bgColor", FlxColor.BLACK),
            beatTracking: getBoolAttr(doc, "beatTracking", true)
        };
    }

    public static function loadIntroLines(path:String = "data/intros.xmsoul"):Array<String> {
        var doc = parse(path, true, false);
        var lines:Array<String> = [];
        if (doc != null) {
            for (line in doc.nodes.resolve("line")) {
                lines.push(getAttr(line, "text"));
            }
        }
        return lines;
    }

    public static function loadStage(path:String):Array<XMSoulStageObject> {
        var conf = loadStageConfig(path);
        return conf != null ? conf.objects : [];
    }

    public static function loadStageConfig(path:String):Null<XMSoulStageConfig> {
        var doc = parse(path, true, false);
        if (doc == null) return null;

        var stageConf:XMSoulStageConfig = {
            name: getAttr(doc, "name", "Stage"),
            defaultZoom: getFloatAttr(doc, "defaultZoom", 1.0),
            camPos: [getFloatAttr(doc, "startCamPosX", 0.0), getFloatAttr(doc, "startCamPosY", 0.0)],
            positions: new Map<String, Array<Float>>(),
            objects: []
        };

        if (doc.hasNode.resolve("camera")) {
            var c = doc.node.resolve("camera");
            stageConf.defaultZoom = getFloatAttr(c, "zoom", stageConf.defaultZoom);
            stageConf.camPos = [getFloatAttr(c, "x", stageConf.camPos[0]), getFloatAttr(c, "y", stageConf.camPos[1])];
        }

        if (doc.hasNode.resolve("positions")) {
            var posNode = doc.node.resolve("positions");
            for (elem in posNode.elements) {
                stageConf.positions.set(elem.name.toLowerCase(), [getFloatAttr(elem, "x", 0.0), getFloatAttr(elem, "y", 0.0)]);
            }
        }

        if (doc.hasNode.resolve("objects")) {
            for (node in doc.node.resolve("objects").nodes.resolve("sprite")) {
                var obj:XMSoulStageObject = {
                    id: getAttr(node, "id", "prop_" + stageConf.objects.length),
                    image: getAttr(node, "image", ""),
                    x: getFloatAttr(node, "x", 0.0),
                    y: getFloatAttr(node, "y", 0.0),
                    scaleX: getFloatAttr(node, "scaleX", getFloatAttr(node, "scale", 1.0)),
                    scaleY: getFloatAttr(node, "scaleY", getFloatAttr(node, "scale", 1.0)),
                    scrollX: getFloatAttr(node, "scrollX", getFloatAttr(node, "scroll", 1.0)),
                    scrollY: getFloatAttr(node, "scrollY", getFloatAttr(node, "scroll", 1.0)),
                    zIndex: getIntAttr(node, "zIndex", stageConf.objects.length),
                    alpha: getFloatAttr(node, "alpha", 1.0),
                    antialiasing: getBoolAttr(node, "antialiasing", true)
                };
                stageConf.objects.push(obj);
            }
        }

        return stageConf;
    }

    public static function loadCharacter(path:String):Null<XMSoulCharacterConfig> {
        var doc = parse(path, true, false);
        if (doc == null) return null;

        var char:XMSoulCharacterConfig = {
            image: getAttr(doc, "image", ""),
            icon: getAttr(doc, "icon", "face"),
            isPlayer: getBoolAttr(doc, "isPlayer", false),
            isGF: getBoolAttr(doc, "isGF", false),
            flipX: getBoolAttr(doc, "flipX", false),
            scale: getFloatAttr(doc, "scale", 1.0),
            antialiasing: getBoolAttr(doc, "antialiasing", true),
            cameraOffset: getFloatArrayAttr(doc, "cameraOffset"),
            positionOffset: getFloatArrayAttr(doc, "positionOffset"),
            healthColor: getColorAttr(doc, "healthColor", 0xFFA1A1A1),
            animations: []
        };

        if (doc.hasNode.resolve("animations")) {
            for (anim in doc.node.resolve("animations").nodes.resolve("anim")) {
                var indicesStr = getAttr(anim, "indices", "");
                var indices:Array<Int> = [];
                if (indicesStr.length > 0) {
                    for (i in indicesStr.split(",")) {
                        var parsed = Std.parseInt(i.trim());
                        if (parsed != null) indices.push(parsed);
                    }
                }

                var offsets = getFloatArrayAttr(anim, "offsets");
                if (offsets.length == 0) offsets = getFloatArrayAttr(anim, "offset");

                char.animations.push({
                    name: getAttr(anim, "name"),
                    prefix: getAttr(anim, "prefix"),
                    fps: getIntAttr(anim, "fps", 24),
                    loop: getBoolAttr(anim, "loop", false),
                    indices: indices,
                    offset: offsets
                });
            }
        }

        return char;
    }

    public static function loadDialogue(path:String):Array<XMSoulDialogueLine> {
        var doc = parse(path, true, false);
        if (doc == null) return [];

        var lines:Array<XMSoulDialogueLine> = [];
        for (line in doc.nodes.resolve("line")) {
            lines.push({
                portrait: getAttr(line, "portrait", "bf"),
                box: getAttr(line, "box", "default"),
                text: getAttr(line, "text", ""),
                speed: getFloatAttr(line, "speed", 0.05),
                sound: getAttr(line, "sound", "dialogue"),
                side: getAttr(line, "side", "left")
            });
        }
        return lines;
    }

    public static function loadModifiers(path:String):XMSoulSongModifiers {
        var doc = parse(path, true, false);
        return {
            scrollSpeedMultiplier: getFloatAttr(doc, "scrollSpeedMultiplier", 1.0),
            ghostTapping: getBoolAttr(doc, "ghostTapping", true),
            healthDrain: getFloatAttr(doc, "healthDrain", 0.0),
            drainFloor: getFloatAttr(doc, "drainFloor", getFloatAttr(doc, "minHealthDrainLimit", 0.1)),
            maxHealth: getFloatAttr(doc, "maxHealth", 2.0)
        };
    }

    public static function clearCache():Void {
        cache.clear();
    }
}