package soulscorch.gameplay.chart.events;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

using StringTools;

class EventMarker extends FlxSpriteGroup {
    public var time:Float;
    public var eventName:String;
    public var val1:String;
    public var val2:String;
    public var isSelected:Bool = false;

    private var iconBox:FlxSprite;
    private var selectionBorder:FlxSprite;
    private var label:FlxText;

    public function new(time:Float, eventName:String, val1:String = "", val2:String = "") {
        super(0, 0);
        this.time = time;
        this.eventName = (eventName != null) ? eventName : "Event";
        this.val1 = (val1 != null) ? val1 : "";
        this.val2 = (val2 != null) ? val2 : "";

        var markerColor = getEventColor(this.eventName);

        selectionBorder = new FlxSprite(-2, -2).makeGraphic(44, 44, FlxColor.WHITE);
        selectionBorder.visible = false;
        add(selectionBorder);

        iconBox = new FlxSprite(0, 0).makeGraphic(40, 40, markerColor);
        add(iconBox);

        var shortName = getShortName(this.eventName);
        label = new FlxText(0, 10, 40, shortName, 12);
        label.setFormat(Paths.font("vcr"), 12, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        label.borderSize = 1.0;
        add(label);
    }

    public function setSelected(selected:Bool):Void {
        this.isSelected = selected;
        if (selectionBorder != null) {
            selectionBorder.visible = selected;
        }
    }

    private static function getEventColor(name:String):Int {
        if (name == null) return 0xFF506070;
        var clean = name.toLowerCase().trim();
        if (clean.indexOf("camera") != -1 || clean.indexOf("zoom") != -1) {
            return 0xFF22AACC; // Cyan-Blue
        } else if (clean.indexOf("bpm") != -1 || clean.indexOf("speed") != -1) {
            return 0xFFE04040; // Red
        } else if (clean.indexOf("shake") != -1) {
            return 0xFFE08020; // Orange
        } else if (clean.indexOf("flash") != -1 || clean.indexOf("fade") != -1 || clean.indexOf("color") != -1) {
            return 0xFFA030D0; // Purple
        } else if (clean.indexOf("script") != -1 || clean.indexOf("hscript") != -1 || clean.indexOf("anim") != -1) {
            return 0xFF30B040; // Green
        }
        return 0xFF506070; // Slate-Gray
    }

    private static function getShortName(name:String):String {
        if (name == null || name.length == 0) return "EV";
        var parts = name.split(" ");
        if (parts.length > 1 && parts[0] != null && parts[1] != null) {
            return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
        }
        return name.substr(0, 3).toUpperCase();
    }
}