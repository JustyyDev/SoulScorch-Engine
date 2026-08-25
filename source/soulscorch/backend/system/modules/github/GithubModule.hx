package soulscorch.backend.system.modules.github;

import haxe.Http;
import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.NotificationManager;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.system.modules.Module.ModuleBase;
import soulscorch.backend.utils.Logger;

#if sys
import sys.thread.Thread;
#end

typedef GitHubRelease = {
    var tagName:String;
    var name:String;
    var body:String;
    var htmlUrl:String;
    var publishedAt:String;
    var isNewer:Bool;
}

class GitHubModule extends ModuleBase {
    public static var instance:GitHubModule;

    public static var repoOwner:String = "JustyyDev";
    public static var repoName:String = "SoulScorch-Engine";
    public static var apiUrl(get, never):String;
    inline static function get_apiUrl():String return 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

    public var latestRelease:GitHubRelease = null;
    public var hasChecked:Bool = false;
    public var autoNotifyOnUpdate:Bool = true;
    public var isChecking(default, null):Bool = false;

    public function new(autoCheck:Bool = true, notifyOnUpdate:Bool = true) {
        super("github");
        instance = this;
        this.autoNotifyOnUpdate = notifyOnUpdate;

        loadConfigFromXMSoul();

        if (autoCheck) {
            initialize();
        }
    }

    public static function loadConfigFromXMSoul():Void {
        repoOwner = "JustyyDev";
        repoName = "SoulScorch-Engine";
        var access:Access = XMSoul.parse("config/github");
        if (access == null) access = XMSoul.parse("data/config/github");

        if (access != null) {
            repoOwner = XMSoul.getAttr(access, "owner", repoOwner);
            repoName = XMSoul.getAttr(access, "repo", repoName);
            if (instance != null) {
                instance.autoNotifyOnUpdate = XMSoul.getBoolAttr(access, "autoNotify", instance.autoNotifyOnUpdate);
            }
            Logger.info('Loaded GitHub configuration from .xmsoul ($repoOwner/$repoName)', "github");
        }
    }

    override public function initialize():Void {
        #if sys
        checkLatestRelease();
        #end
    }

    public function checkLatestRelease(?callback:GitHubRelease->Void):Void {
        #if sys
        if (isChecking) return;
        isChecking = true;

        Thread.create(function() {
            try {
                var http = new Http(apiUrl);
                http.setHeader("User-Agent", 'SoulScorch-Engine/${Version.fullVersion()}');
                http.setHeader("Accept", "application/vnd.github.v3+json");

                http.onData = function(data:String) {
                    isChecking = false;
                    try {
                        var parsed:Dynamic = Json.parse(data);
                        var tag:String = parsed.tag_name != null ? parsed.tag_name : "";
                        var isNewer:Bool = isVersionNewer(tag);

                        latestRelease = {
                            tagName: tag,
                            name: parsed.name != null ? parsed.name : tag,
                            body: parsed.body != null ? parsed.body : "",
                            htmlUrl: parsed.html_url != null ? parsed.html_url : 'https://github.com/$repoOwner/$repoName',
                            publishedAt: parsed.published_at != null ? parsed.published_at : "",
                            isNewer: isNewer
                        };

                        hasChecked = true;

                        if (isNewer) {
                            Logger.info('Newer version found: ${latestRelease.tagName} (Current: v${Version.MAJOR}.${Version.MINOR}.${Version.PATCH})', "github");
                            EventBus.instance.emit("github/updateAvailable", latestRelease);

                            if (autoNotifyOnUpdate && NotificationManager.instance != null) {
                                NotificationManager.instance.notify(
                                    "Update Available!",
                                    'SoulScorch ${latestRelease.tagName} is available on GitHub.'
                                );
                            }
                        } else {
                            Logger.info("Engine is up to date.", "github");
                            EventBus.instance.emit("github/upToDate", latestRelease);
                        }

                        if (callback != null) {
                            callback(latestRelease);
                        }
                    } catch (e:Dynamic) {
                        Logger.error('Failed parsing GitHub API response: $e', "github");
                    }
                };

                http.onError = function(error:String) {
                    isChecking = false;
                    Logger.warn('GitHub API request failed: $error', "github");
                    if (callback != null) {
                        callback(null);
                    }
                };

                http.request(false);
            } catch (e:Dynamic) {
                isChecking = false;
                Logger.error('Could not initiate GitHub update check thread: $e', "github");
                if (callback != null) {
                    callback(null);
                }
            }
        });
        #end
    }

    public static function isVersionNewer(remoteTag:String):Bool {
        if (remoteTag == null || remoteTag.length == 0) return false;

        var cleanTag = StringTools.trim(remoteTag.toLowerCase());
        if (cleanTag.indexOf("v") == 0) cleanTag = cleanTag.substr(1);

        var parts = cleanTag.split(".");
        if (parts.length < 3) return false;

        var rMajor = Std.parseInt(parts[0]);
        var rMinor = Std.parseInt(parts[1]);
        var rPatch = Std.parseInt(parts[2]);

        if (rMajor == null || rMinor == null || rPatch == null) return false;

        if (rMajor > Version.MAJOR) return true;
        if (rMajor == Version.MAJOR && rMinor > Version.MINOR) return true;
        if (rMajor == Version.MAJOR && rMinor == Version.MINOR && rPatch > Version.PATCH) return true;

        return false;
    }

    public static function openReleasePage(?url:String):Void {
        var targetUrl = url != null ? url : 'https://github.com/$repoOwner/$repoName/releases';
        #if linux
        Sys.command("xdg-open", [targetUrl]);
        #else
        flixel.FlxG.openURL(targetUrl);
        #end
    }
}