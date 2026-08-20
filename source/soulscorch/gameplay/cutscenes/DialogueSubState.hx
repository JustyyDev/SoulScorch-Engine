package soulscorch.gameplay.cutscenes;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.xml.Access;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.graphics.FunkinSprite;

using StringTools;

typedef DialogueLine = {
    var char:String;
    var text:String;
    var speed:Float;
    var playSound:String;
    var textSound:String;
    var bubble:String;
}

class DialogueSubState extends MusicBeatSubstate {
    private var lines:Array<DialogueLine> = [];
    private var curLineIdx:Int = 0;
    private var onFinish:Void->Void;

    private var boxSprite:FlxSprite;
    private var portraitLeft:FunkinSprite;
    private var portraitRight:FunkinSprite;
    private var textDisplay:FlxText;

    private var curDisplayString:String = "";
    private var targetString:String = "";
    private var typingTimer:FlxTimer;
    private var isTyping:Bool = false;

    public function new(rawXml:String, onFinish:Void->Void) {
        super();
        this.onFinish = onFinish;
        this.persistentUpdate = true;
        this.persistentDraw = true;

        parseDialogueXml(rawXml);
    }

    private function parseDialogueXml(xmlStr:String):Void {
        try {
            var xml = Xml.parse(xmlStr);
            var root = new Access(xml.firstElement());

            for (lineNode in root.nodes.line) {
                var charName = lineNode.has.char ? lineNode.att.char : "senpai";
                var speedVal = lineNode.has.speed ? Std.parseFloat(lineNode.att.speed) : 0.04;
                var pSnd = lineNode.has.playSound ? lineNode.att.playSound : "";
                var tSnd = lineNode.has.textSound ? lineNode.att.textSound : "";
                var bubbleType = lineNode.has.bubble ? lineNode.att.bubble : "normal";
                var textContent = lineNode.innerData.trim();

                lines.push({
                    char: charName,
                    text: textContent,
                    speed: speedVal,
                    playSound: pSnd,
                    textSound: tSnd,
                    bubble: bubbleType
                });
            }
        } catch (e:Dynamic) {}
    }

    override public function create():Void {
        super.create();

        portraitLeft = new FunkinSprite(120, FlxG.height * 0.3);
        add(portraitLeft);

        portraitRight = new FunkinSprite(FlxG.width - 350, FlxG.height * 0.3);
        add(portraitRight);

        boxSprite = new FlxSprite(100, FlxG.height * 0.65).makeGraphic(FlxG.width - 200, 180, 0xDD000000);
        add(boxSprite);

        textDisplay = new FlxText(140, FlxG.height * 0.68, FlxG.width - 280, "", 20);
        textDisplay.setFormat(Paths.font("vcr"), 20, FlxColor.WHITE, LEFT);
        add(textDisplay);

        startNextLine();
    }

    private function startNextLine():Void {
        if (curLineIdx >= lines.length) {
            close();
            if (onFinish != null) onFinish();
            return;
        }

        var curLine = lines[curLineIdx];
        if (curLine.playSound != null && curLine.playSound.length > 0) {
            AssetHelper.playSoundSafely(curLine.playSound, 0.85);
        }

        targetString = curLine.text;
        curDisplayString = "";
        textDisplay.text = "";
        isTyping = true;

        if (typingTimer != null) typingTimer.cancel();

        var charIndex = 0;
        typingTimer = new FlxTimer().start(curLine.speed, function(tmr:FlxTimer) {
            if (charIndex < targetString.length) {
                curDisplayString += targetString.charAt(charIndex);
                textDisplay.text = curDisplayString;

                if (curLine.textSound.length > 0 && charIndex % 2 == 0) {
                    AssetHelper.playSoundSafely(curLine.textSound, 0.4);
                }
                charIndex++;
            } else {
                isTyping = false;
                tmr.cancel();
            }
        }, targetString.length);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (Controls.instance.ACCEPT) {
            if (isTyping) {
                if (typingTimer != null) typingTimer.cancel();
                textDisplay.text = targetString;
                isTyping = false;
            } else {
                curLineIdx++;
                startNextLine();
            }
        }
    }
}