package soulscorch.ui.menus.credits;

typedef CreditMember = {
    var name:String;
    var role:String;
    var desc:String;
}

typedef CreditCategory = {
    var title:String;
    var subtitle:String;
    var members:Array<CreditMember>;
}

class SoulCreditsData {
    public static var categories:Array<CreditCategory> = [
        {
            title: "THE ARCHITECTS",
            subtitle: "Core engine engineering, backend APIs, and custom modding frameworks.",
            members: [
                {
                    name: "Justy (JustifiedJusty)",
                    role: "Lead Engine Architect",
                    desc: "Creator of SoulScorch, HScript sandbox bindings, and native OS integrations."
                }
            ]
        },
        {
            title: "AUDIO & VISUALIZERS",
            subtitle: "Sound spectrum analysis, hardware audio routing, and shader pipelines.",
            members: [
                {
                    name: "Audio Subsystem",
                    role: "FFT Spectrum Bridge",
                    desc: "Powering real-time audio-reactive gameplay and visualizer parameters."
                }
            ]
        },
        {
            title: "FRAMEWORK & INSPIRATIONS",
            subtitle: "Open-source foundations that paved the way for this powerhouse.",
            members: [
                {
                    name: "Codename Engine Crew",
                    role: "UI Architecture Inspiration",
                    desc: "Providing structural reference points for modern FNF-style toolsets."
                },
                {
                    name: "HaxeFlixel Foundation",
                    role: "2D Rendering Core",
                    desc: "The underlying framework rendering the core pixels and states."
                }
            ]
        }
    ];
}