package soulscorch.ui.menus.substate;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.replays.ReplayManager;
import soulscorch.gameplay.replays.SoulVidEncoder;
import soulscorch.scripting.ScriptManager;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.editors.editorui.EditorToast;

#if sys
import sys.FileSystem;
#end

using StringTools;

class ReplayGallerySubState extends MusicBeatSubstate {
    private var replays:Array<String> = [];
    private var curSelected:Int = 0;

    private var grpItems:FlxTypedGroup<FlxSpriteGroup>;
    private var itemBgs:Array<FlxSprite> = [];
    private var headerText:FlxText;
    private var infoText:FlxText;
    private var scripts:ScriptManager;

    public function new() {
        super();

        var subCam = new FlxCamera();
        subCam.bgColor = 0xAA000000;
        FlxG.cameras.add(subCam, false);
        cameras = [subCam];

        scripts = new ScriptManager();
        initReplayScripts();

        replays = scanReplayFiles();

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xDD0A0B10);
        add(bg);

        var topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 60, EditorTheme.PANEL_HEADER);
        add(topBar);

        headerText = new FlxText(30, 16, FlxG.width - 60, 'SOULSCORCH REPLAY & SOULVID ARCHIVE (${replays.length} Saved)', 22);
        headerText.setFormat(Paths.font("vcr"), 22, EditorTheme.ACCENT_CYAN, LEFT);
        add(headerText);

        infoText = new FlxText(30, FlxG.height - 45, FlxG.width - 60, "[ENTER] Play Replay  •  [S] Export .soulvid  •  [O] Open Folder  •  [ESC] Back", 16);
        infoText.setFormat(Paths.font("vcr"), 16, EditorTheme.TEXT_MUTED, CENTER);
        add(infoText);

        grpItems = new FlxTypedGroup<FlxSpriteGroup>();
        add(grpItems);

        rebuildList();
        changeSelection(0);

        if (scripts != null) scripts.callAll("onPostCreate");
    }

    private function initReplayScripts():Void {
        var paths = [
            "data/scripts/substates/replays",
            "scripts/substates/replays",
            "data/scripts/replayGallery"
        ];
        for (p in paths) {
            var file = soulscorch.backend.assets.AssetResolver.resolveFile(p, [".soul", ".hx", ".lua", ".py", ".js"]);
            if (file != null) scripts.loadScript(file);
        }
        scripts.setAll("substate", this);
        scripts.callAll("onCreate");
    }

    private function scanReplayFiles():Array<String> {
        var list:Array<String> = [];
        #if sys
        if (FileSystem.exists("replays") && FileSystem.isDirectory("replays")) {
            for (f in FileSystem.readDirectory("replays")) {
                if (f.endsWith(".srpy") || f.endsWith(".soulvid")) {
                    list.push('replays/$f');
                }
            }
        }
        #end
        return list;
    }

    private function rebuildList():Void {
        grpItems.clear();
        itemBgs = [];

        var listWidth = FlxG.width * 0.86;
        var startX = (FlxG.width - listWidth) * 0.5;

        for (i in 0...replays.length) {
            var itemGroup = new FlxSpriteGroup(startX, 90 + (i * 56));

            var rowBg = new FlxSprite(0, 0).makeGraphic(Std.int(listWidth), 50, EditorTheme.PANEL_BG);
            rowBg.alpha = 0.5;
            itemGroup.add(rowBg);
            itemBgs.push(rowBg);

            var path = replays[i];
            var isSoulVid = path.endsWith(".soulvid");
            var cleanName = path.substr(path.lastIndexOf("/") + 1).replace(".srpy", "").replace(".soulvid", "");

            var title = new FlxText(20, 14, listWidth * 0.65, cleanName, 16);
            title.setFormat(Paths.font("vcr"), 16, EditorTheme.TEXT_PRIMARY, LEFT);
            itemGroup.add(title);

            var badge = new FlxText(listWidth - 180, 14, 160, isSoulVid ? "[.SOULVID EMBED]" : "[RAW .SRPY]", 16);
            badge.setFormat(Paths.font("vcr"), 16, isSoulVid ? 0xFF00FFCC : 0xFF888899, RIGHT);
            itemGroup.add(badge);

            grpItems.add(itemGroup);
        }

        if (replays.length == 0) {
            var empty = new FlxText(0, FlxG.height * 0.45, FlxG.width, "No Replays Found in replays/ Directory.", 20);
            empty.setFormat(Paths.font("vcr"), 20, EditorTheme.TEXT_MUTED, CENTER);
            add(empty);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (scripts != null) scripts.callAll("onUpdate", [elapsed]);

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);

        if (FlxG.keys.justPressed.O) {
            #if windows
            Sys.command("explorer", ["replays"]);
            #elseif mac
            Sys.command("open", ["replays"]);
            #elseif linux
            Sys.command("xdg-open", ["replays"]);
            #end
        }

        if (FlxG.keys.justPressed.S && replays.length > 0) {
            var target = replays[curSelected];
            if (target.endsWith(".srpy")) {
                EditorToast.show("Encoding .soulvid video...");
                #if sys
                SoulVidEncoder.encodeToSoulVid(target, function(outPath) {
                    replays = scanReplayFiles();
                    rebuildList();
                    EditorToast.show("Exported " + outPath);
                });
                #end
            } else {
                EditorToast.show("Already a .soulvid package!", false);
            }
        }

        if (Controls.instance.ACCEPT && replays.length > 0) {
            var replayFile = replays[curSelected];
            var loadSuccess = false;

            if (replayFile.endsWith(".soulvid")) {
                #if sys
                var extractedJson = SoulVidEncoder.extractReplayData(replayFile);
                if (extractedJson != null) {
                    loadSuccess = ReplayManager.loadReplayFromJson(extractedJson);
                }
                #end
            } else {
                loadSuccess = ReplayManager.loadReplay(replayFile);
            }

            if (loadSuccess) {
                close();
                FlxG.switchState(new PlayState());
            }
        }

        if (Controls.instance.BACK) {
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            close();
        }

        for (i in 0...grpItems.members.length) {
            var item = grpItems.members[i];
            var isCur = (i == curSelected);
            itemBgs[i].color = isCur ? EditorTheme.BTN_HOVER : EditorTheme.PANEL_BG;
            item.x = FlxMath.lerp(item.x, isCur ? (FlxG.width * 0.08) : (FlxG.width * 0.07), FlxMath.bound(elapsed * 15, 0, 1));
            item.alpha = isCur ? 1.0 : 0.6;
        }
    }

    private function changeSelection(change:Int = 0):Void {
        if (replays.length == 0) return;
        curSelected = FlxMath.wrap(curSelected + change, 0, replays.length - 1);
        if (change != 0) AssetHelper.playSoundSafely("scrollMenu", 0.6);
        if (scripts != null) scripts.callAll("onChangeReplaySelection", [curSelected]);
    }

    override public function destroy():Void {
        if (scripts != null) {
            scripts.callAll("onDestroy");
            scripts.clear();
        }
        super.destroy();
    }
}