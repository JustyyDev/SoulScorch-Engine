package soulscorch.gameplay.cutscenes;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.XMSoul;
import soulscorch.graphics.FunkinSprite;

using StringTools;

typedef DialogueLine = {
    var char:String;
    var expression:String;
    var side:String; // "left", "right", or "center"
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

    private var bgShade:FlxSprite;
    private var boxSprite:FunkinSprite;
    private var portraitLeft:FunkinSprite;
    private var portraitRight:FunkinSprite;
    private var textDisplay:FlxText;
    private var nameDisplay:FlxText;

    private var curDisplayString:String = "";
    private var targetString:String = "";
    private var isTyping:Bool = false;
    private var typeCharIndex:Int = 0;
    private var typeInterval:Float = 0.04;
    private var typeAccumulator:Float = 0.0;
    private var typeSound:String = "";
    
    private var boxDialogueAnim:String = "normal";
    private var isBoxVisible:Bool = false;

    public function new(rawXmlOrSoul:String, onFinish:Void->Void) {
        super();
        this.onFinish = onFinish;
        this.persistentUpdate = true;
        this.persistentDraw = true;

        parseDialogueData(rawXmlOrSoul);
    }

    private function parseDialogueData(content:String):Void {
        try {
            // Check if it's structured XMSoul or standard XML
            var xml = Xml.parse(content);
            var root = new Access(xml.firstElement());

            if (root.name.toLowerCase() == "dialogue" || root.name.toLowerCase() == "dialogues") {
                if (root.has.box) {
                    boxDialogueAnim = root.att.box;
                }

                for (lineNode in root.nodes.resolve("line")) {
                    var charName = XMSoul.getAttr(lineNode, "char", XMSoul.getAttr(lineNode, "speaker", "senpai"));
                    var expr = XMSoul.getAttr(lineNode, "expression", XMSoul.getAttr(lineNode, "anim", "talk"));
                    var sidePos = XMSoul.getAttr(lineNode, "side", XMSoul.getAttr(lineNode, "position", "left"));
                    var speedVal = XMSoul.getFloatAttr(lineNode, "speed", 0.04);
                    var pSnd = XMSoul.getAttr(lineNode, "playSound", "");
                    var tSnd = XMSoul.getAttr(lineNode, "textSound", XMSoul.getAttr(lineNode, "talkSound", ""));
                    var bubbleType = XMSoul.getAttr(lineNode, "bubble", "normal");
                    var textContent = lineNode.innerData != null ? lineNode.innerData.trim() : "";

                    lines.push({
                        char: charName,
                        expression: expr,
                        side: sidePos.toLowerCase(),
                        text: textContent,
                        speed: speedVal,
                        playSound: pSnd,
                        textSound: tSnd,
                        bubble: bubbleType
                    });
                }
            }
        } catch (e:Dynamic) {
            // Fallback plain string parsing if XML format fails
            lines.push({
                char: "dad",
                expression: "talk",
                side: "left",
                text: content,
                speed: 0.04,
                playSound: "",
                textSound: "",
                bubble: "normal"
            });
        }
    }

    override public function create():Void {
        super.create();

        bgShade = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bgShade.alpha = 0.0;
        bgShade.scrollFactor.set();
        add(bgShade);

        FlxTween.tween(bgShade, {alpha: 0.55}, 0.5, {ease: FlxEase.quadOut});

        portraitLeft = new FunkinSprite(80, FlxG.height * 0.25);
        portraitLeft.alpha = 0.0;
        add(portraitLeft);

        portraitRight = new FunkinSprite(FlxG.width - 450, FlxG.height * 0.25);
        portraitRight.alpha = 0.0;
        add(portraitRight);

        // Dialogue Box Container
        boxSprite = new FunkinSprite(90, FlxG.height * 0.58);
        var boxLoaded = boxSprite.loadSprite('ui/game/dialogue/dialogueBox-$boxDialogueAnim');
        if (!boxLoaded) {
            boxLoaded = boxSprite.loadSprite('ui/game/dialogue/dialogueBox');
        }
        if (!boxLoaded) {
            boxSprite.makeGraphic(FlxG.width - 180, 210, 0xEE000000);
        }
        boxSprite.alpha = 0.0;
        boxSprite.scrollFactor.set();
        add(boxSprite);

        nameDisplay = new FlxText(140, FlxG.height * 0.61, 400, "", 22);
        nameDisplay.setFormat(Paths.font("vcr"), 22, 0xFFFF3366, LEFT, OUTLINE, FlxColor.BLACK);
        nameDisplay.borderSize = 1.5;
        nameDisplay.scrollFactor.set();
        add(nameDisplay);

        textDisplay = new FlxText(140, FlxG.height * 0.67, FlxG.width - 280, "", 20);
        textDisplay.setFormat(Paths.font("vcr"), 20, FlxColor.WHITE, LEFT);
        textDisplay.scrollFactor.set();
        add(textDisplay);

        startNextLine();
    }

    private function startNextLine():Void {
        if (curLineIdx >= lines.length) {
            endDialogue();
            return;
        }

        var curLine = lines[curLineIdx];

        // Fade in box if first line
        if (!isBoxVisible) {
            isBoxVisible = true;
            FlxTween.tween(boxSprite, {alpha: 1.0}, 0.4, {ease: FlxEase.cubeOut});
        }

        nameDisplay.text = curLine.char.toUpperCase();

        if (curLine.playSound != null && curLine.playSound.length > 0) {
            AssetHelper.playSoundSafely(curLine.playSound, 0.85);
        }

        // Handle Portraits based on side
        updatePortraits(curLine);

        targetString = curLine.text;
        curDisplayString = "";
        textDisplay.text = "";
        isTyping = true;
        typeCharIndex = 0;
        typeInterval = curLine.speed > 0 ? curLine.speed : 0.04;
        typeAccumulator = 0.0;
        typeSound = curLine.textSound != null ? curLine.textSound : "";
    }

    private function updatePortraits(line:DialogueLine):Void {
        var charKey = line.char.toLowerCase().trim();
        var portraitPath = 'ui/game/dialogue/portraits/$charKey';

        if (line.side == "right") {
            portraitRight.visible = true;
            portraitLeft.visible = false;
            
            var loaded = portraitRight.loadSprite(portraitPath);
            if (loaded) {
                portraitRight.playAnim(line.expression);
                if (portraitRight.alpha == 0) {
                    portraitRight.alpha = 1.0;
                    portraitRight.x = FlxG.width - 350 + 30;
                    FlxTween.tween(portraitRight, {x: FlxG.width - 350}, 0.3, {ease: FlxEase.backOut});
                }
            }
        } else {
            portraitLeft.visible = true;
            portraitRight.visible = false;

            var loaded = portraitLeft.loadSprite(portraitPath);
            if (loaded) {
                portraitLeft.playAnim(line.expression);
                if (portraitLeft.alpha == 0) {
                    portraitLeft.alpha = 1.0;
                    portraitLeft.x = 120 - 30;
                    FlxTween.tween(portraitLeft, {x: 120}, 0.3, {ease: FlxEase.backOut});
                }
            }
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (isTyping) {
            typeAccumulator += elapsed;
            while (isTyping && typeAccumulator >= typeInterval) {
                typeAccumulator -= typeInterval;
                if (typeCharIndex < targetString.length) {
                    curDisplayString += targetString.charAt(typeCharIndex);
                    textDisplay.text = curDisplayString;

                    if (typeSound.length > 0 && (typeCharIndex % 2 == 0)) {
                        AssetHelper.playSoundSafely(typeSound, 0.5);
                    }
                    typeCharIndex++;
                } else {
                    isTyping = false;
                }
            }
        }

        if (Controls.instance.ACCEPT) {
            if (isTyping) {
                typeCharIndex = targetString.length;
                textDisplay.text = targetString;
                isTyping = false;
            } else {
                curLineIdx++;
                startNextLine();
            }
        }
    }

    private function endDialogue():Void {
        isTyping = false;

        FlxTween.tween(bgShade, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
        FlxTween.tween(boxSprite, {alpha: 0}, 0.3, {ease: FlxEase.quadIn});
        FlxTween.tween(portraitLeft, {alpha: 0}, 0.3);
        FlxTween.tween(portraitRight, {alpha: 0}, 0.3);
        FlxTween.tween(textDisplay, {alpha: 0}, 0.3);
        FlxTween.tween(nameDisplay, {alpha: 0}, 0.3, {
            onComplete: function(_) {
                close();
                if (onFinish != null) onFinish();
            }
        });
    }

    override public function destroy():Void {
        super.destroy();
    }
}