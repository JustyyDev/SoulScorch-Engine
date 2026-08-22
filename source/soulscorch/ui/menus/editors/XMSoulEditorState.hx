package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.xml.Access;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptManager;
import soulscorch.ui.menus.editors.editorui.*;

class XMSoulEditorState extends MusicBeatState {
    public static var instance:XMSoulEditorState;

    public var layoutFile:String;
    public var script:ScriptManager;
    public var widgets:Map<String, Dynamic> = new Map<String, Dynamic>();
    public var windowList:Array<EditorWindow> = [];

    public var camWorld:FlxCamera;
    public var camUI:FlxCamera;

    public var topBar:EditorTopBar;
    public var toast:EditorToast;

    private var isDraggingCamera:Bool = false;
    private var lastMousePos:FlxPoint;

    public function new(layoutFile:String) {
        super();
        this.layoutFile = layoutFile;
    }

    override public function create():Void {
        super.create();
        instance = this;

        lastMousePos = FlxPoint.get();

        camWorld = new FlxCamera();
        camUI = new FlxCamera();
        camUI.bgColor = FlxColor.TRANSPARENT;

        FlxG.cameras.reset(camWorld);
        FlxG.cameras.add(camUI, false);
        FlxG.cameras.setDefaultDrawTarget(camWorld, true);

        toast = new EditorToast();
        toast.cameras = [camUI];
        add(toast);

        var resolvedXml:Access = null;
        var cleanPath = layoutFile;

        var trialPaths = [
            cleanPath,
            'data/$cleanPath',
            'config/$cleanPath',
            'data/config/$cleanPath',
            'config/ui/menus/$cleanPath',
            'data/ui/menus/$cleanPath',
            'assets/preload/data/config/$cleanPath',
            'assets/preload/data/config/ui/menus/$cleanPath'
        ];

        for (p in trialPaths) {
            resolvedXml = XMSoul.parse(p);
            if (resolvedXml != null) {
                Logger.info('Resolved editor layout at: $p', "editor");
                break;
            }
        }

        if (resolvedXml == null) {
            Logger.error('Failed parsing editor layout across all paths: $layoutFile', "editor");
            showToast("Error: Layout file not found!", true);
            return;
        }

        buildLayout(resolvedXml);

        var scriptPath = XMSoul.getAttr(resolvedXml, "script", "");
        if (scriptPath != "") {
            script = new ScriptManager();
            script.loadScript(scriptPath);

            script.setAll("editor", this);
            script.setAll("game", this);
            script.setAll("state", this);
            script.setAll("camWorld", camWorld);
            script.setAll("camUI", camUI);
            script.setAll("FlxG", FlxG);
            script.setAll("FlxSprite", FlxSprite);
            script.setAll("FlxText", FlxText);
            script.setAll("FlxMath", FlxMath);
            script.setAll("FlxPoint", {
                get: function(?x:Float = 0, ?y:Float = 0) return FlxPoint.get(x, y),
                weak: function(?x:Float = 0, ?y:Float = 0) return FlxPoint.weak(x, y)
            });
            script.setAll("FlxTween", FlxTween);
            script.setAll("FlxEase", FlxEase);
            script.setAll("FlxTimer", FlxTimer);
            script.setAll("Paths", Paths);
            script.setAll("showToast", showToast);
            script.setAll("widgets", widgets);

            script.callAll("onCreate", []);
        }

        FlxG.mouse.visible = true;
    }

    public function showToast(msg:String, isError:Bool = false):Void {
        EditorToast.show(msg, isError);
    }

    private function buildLayout(root:Access):Void {
        var topBarTitle = XMSoul.getAttr(root, "title", "SOULSCORCH EDITOR MATRIX");
        topBar = new EditorTopBar(topBarTitle);
        topBar.cameras = [camUI];
        add(topBar);

        for (node in root.elements) {
            switch (node.name.toLowerCase()) {
                case "action":
                    var label = XMSoul.getAttr(node, "label", "Action");
                    var callback = XMSoul.getAttr(node, "onTrigger", "");
                    topBar.addAction(label, function() {
                        if (script != null && callback != "") {
                            script.callAll(callback, []);
                        }
                    });

                case "window":
                    var win = new EditorWindow(
                        XMSoul.getFloatAttr(node, "x", 15),
                        XMSoul.getFloatAttr(node, "y", 45),
                        XMSoul.getIntAttr(node, "width", 300),
                        XMSoul.getIntAttr(node, "height", 300),
                        XMSoul.getAttr(node, "title", "Window")
                    );
                    win.cameras = [camUI];
                    add(win);
                    windowList.push(win);

                    var winId = XMSoul.getAttr(node, "id", "");
                    if (winId != "") widgets.set(winId, win);

                    for (child in node.elements) {
                        var widget = parseWidget(child);
                        if (widget != null) win.addElement(widget);
                    }
            }
        }
    }

    private function parseWidget(node:Access):Dynamic {
        var id = XMSoul.getAttr(node, "id", "");
        var x = XMSoul.getFloatAttr(node, "x", 10);
        var y = XMSoul.getFloatAttr(node, "y", 10);
        var action = XMSoul.getAttr(node, "action", "");

        switch (node.name.toLowerCase()) {
            case "text":
                var txt = new FlxText(x, y, XMSoul.getFloatAttr(node, "width", 280), XMSoul.getAttr(node, "text", ""), XMSoul.getIntAttr(node, "size", 12));
                txt.setFormat(Paths.font("vcr"), XMSoul.getIntAttr(node, "size", 12), FlxColor.fromString(XMSoul.getAttr(node, "color", "0xFFFFFFFF")), LEFT);
                if (id != "") widgets.set(id, txt);
                return txt;

            case "button":
                var btn = new EditorButton(x, y, XMSoul.getIntAttr(node, "width", 130), XMSoul.getIntAttr(node, "height", 26), XMSoul.getAttr(node, "text", "Button"), function() {
                    if (script != null && action != "") script.callAll(action, []);
                });
                if (id != "") widgets.set(id, btn);
                return btn;

            case "checkbox":
                var chk = new EditorCheckbox(x, y, XMSoul.getAttr(node, "label", "Check"), XMSoul.getBoolAttr(node, "checked", false), function(val) {
                    if (script != null && action != "") script.callAll(action, [val]);
                });
                if (id != "") widgets.set(id, chk);
                return chk;

            case "stepper":
                var stp = new EditorNumericStepper(
                    x, y, XMSoul.getIntAttr(node, "width", 140),
                    XMSoul.getAttr(node, "label", "Value"),
                    XMSoul.getFloatAttr(node, "default", 0),
                    XMSoul.getFloatAttr(node, "min", 0),
                    XMSoul.getFloatAttr(node, "max", 100),
                    XMSoul.getFloatAttr(node, "step", 1),
                    XMSoul.getIntAttr(node, "precision", 0),
                    function(val) {
                        if (script != null && action != "") {
                            script.callAll(action, [val]);
                        }
                    }
                );
                if (id != "") widgets.set(id, stp);
                return stp;

            case "input":
                var inp = new EditorInputText(x, y, XMSoul.getIntAttr(node, "width", 280), XMSoul.getAttr(node, "label", "Input"), XMSoul.getAttr(node, "text", ""));
                if (id != "") widgets.set(id, inp);
                return inp;
        }
        return null;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.mouse.pressedMiddle || (FlxG.keys.pressed.SPACE && FlxG.mouse.pressed)) {
            if (!isDraggingCamera) {
                isDraggingCamera = true;
                lastMousePos.set(FlxG.mouse.screenX, FlxG.mouse.screenY);
            } else {
                camWorld.scroll.x -= (FlxG.mouse.screenX - lastMousePos.x) / camWorld.zoom;
                camWorld.scroll.y -= (FlxG.mouse.screenY - lastMousePos.y) / camWorld.zoom;
                lastMousePos.set(FlxG.mouse.screenX, FlxG.mouse.screenY);
            }
        } else {
            isDraggingCamera = false;
        }

        if (FlxG.mouse.wheel != 0 && !isOverUI()) {
            camWorld.zoom = FlxMath.bound(camWorld.zoom + (FlxG.mouse.wheel * 0.1), 0.2, 5.0);
        }

        if (script != null) script.callAll("onUpdate", [elapsed]);
    }

    public function isOverUI():Bool {
        for (win in windowList) {
            if (win.visible && FlxG.mouse.overlaps(win, camUI)) return true;
        }
        return topBar != null && FlxG.mouse.overlaps(topBar, camUI);
    }

    override public function destroy():Void {
        if (lastMousePos != null) lastMousePos.put();
        if (script != null) {
            script.callAll("onDestroy");
            script.clear();
        }
        super.destroy();
    }
}