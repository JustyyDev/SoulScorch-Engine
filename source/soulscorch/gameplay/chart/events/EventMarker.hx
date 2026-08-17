package soulscorch.gameplay.chart.events;

import flixel.group.FlxSpriteGroup;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

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
        this.eventName = eventName;
        this.val1 = val1;
        this.val2 = val2;

        var markerColor = getEventColor(eventName);

        // Outer highlight border for selection
        selectionBorder = new FlxSprite(-2, -2).makeGraphic(44, 44, FlxColor.WHITE);
        selectionBorder.visible = false;
        add(selectionBorder);

        // Core marker background
        iconBox = new FlxSprite(0, 0).makeGraphic(40, 40, markerColor);
        add(iconBox);

        // Event name shorthand / acronym label
        var shortName = getShortName(eventName);
        label = new FlxText(0, 10, 40, shortName, 12);
        label.setFormat(Paths.font("vcr"), 12, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        label.borderSize = 1.0;
        add(label);
    }

    public function setSelected(selected:Bool):Void {
        this.isSelected = selected;
        selectionBorder.visible = selected;
    }

    private static function getEventColor(name:String):Int {
        var clean = name.toLowerCase().trim();
        if (clean.indexOf("camera") != -1 || clean.indexOf("zoom") != -1) {
            return 0xFF22AACC; // Cyan-Blue for Camera
        } else if (clean.indexOf("bpm") != -1 || clean.indexOf("speed") != -1) {
            return 0xFFE04040; // Red for Timing & Tempo
        } else if (clean.indexOf("flash") != -1 || clean.indexOf("fade") != -1 || clean.indexOf("color") != -1) {
            return 0xFFA030D0; // Purple for Screen & Visuals
        } else if (clean.indexOf("script") != -1 || clean.indexOf("hscript") != -1) {
            return 0xFF30B040; // Green for Script Triggers
        }
        return 0xFF506070; // Slate-Gray default
    }

    private static function getShortName(name:String):String {
        if (name == null || name.length == 0) return "EV";
        var parts = name.split(" ");
        if (parts.length > 1) {
            return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
        }
        return name.substr(0, 3).toUpperCase();
    }
}