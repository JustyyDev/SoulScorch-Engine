package soulscorch.gameplay.chart.events;

typedef QueuedEvent = {
    var time:Float;
    var name:String;
    var val1:String;
    var val2:String;
    var ?data:Dynamic;
    var fired:Bool;
}

typedef EventDefinition = {
    var name:String;
    var description:String;
    var ?defaultVal1:String;
    var ?defaultVal2:String;
    var ?color:Int;
}

class SongEvents {
    public static var registeredEvents:Map<String, EventDefinition> = [
        "Camera Movement" => {
            name: "Camera Movement",
            description: "Pans the camera to opponent (0) or player (1) as used in Codename/Psych charts.",
            defaultVal1: "1",
            defaultVal2: "0.4",
            color: 0xFF22AACC
        },
        "Camera Pan" => {
            name: "Camera Pan",
            description: "Pans the game camera to a target character (bf/dad/gf/stage).",
            defaultVal1: "dad",
            defaultVal2: "0.4",
            color: 0xFF22AACC
        },
        "Camera Zoom" => {
            name: "Camera Zoom",
            description: "Smoothly tweens the camera base zoom.",
            defaultVal1: "1.0",
            defaultVal2: "0.3",
            color: 0xFF22AACC
        },
        "Camera Bump" => {
            name: "Camera Bump",
            description: "Adds an instant zoom bump that decays over time.",
            defaultVal1: "0.05",
            defaultVal2: "",
            color: 0xFF22AACC
        },
        "Flash" => {
            name: "Flash",
            description: "Flashes the camera screen with a color.",
            defaultVal1: "0.35",
            defaultVal2: "#FFFFFF",
            color: 0xFFA030D0
        },
        "Fade" => {
            name: "Fade",
            description: "Fades the screen to a specific color.",
            defaultVal1: "0.5",
            defaultVal2: "#000000",
            color: 0xFFA030D0
        },
        "Play Animation" => {
            name: "Play Animation",
            description: "Forces a character to play an animation by name.",
            defaultVal1: "singUP",
            defaultVal2: "dad",
            color: 0xFF30B040
        }
    ];

    public static inline function getDefinition(name:String):Null<EventDefinition> {
        if (name == null) return null;
        return registeredEvents.get(name);
    }
}