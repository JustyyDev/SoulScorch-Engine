package soulscorch.backend.system.modules.github;

import haxe.Json;
import haxe.Http;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.NotificationManager;
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

    public static inline var REPO_OWNER:String = "JustyyDev";
    public static inline var REPO_NAME:String = "SoulScorch-Engine";
    public static inline var API_URL:String = 'https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest';

    public var latestRelease:GitHubRelease = null;
    public var hasChecked:Bool = false;
    public var autoNotifyOnUpdate:Bool = true;

    public function new(autoCheck:Bool = true, notifyOnUpdate:Bool = true) {
        super("github");
        instance = this;
        this.autoNotifyOnUpdate = notifyOnUpdate;

        if (autoCheck) {
            initialize();
        }
    }

    override public function initialize():Void {
        #if sys
        checkLatestRelease();
        #end
    }

    /**
     * Asynchronously queries the GitHub API for the newest repository release tag.
     */
    public function checkLatestRelease(?callback:GitHubRelease->Void):Void {
        #if sys
        Thread.create(function() {
            try {
                var http = new Http(API_URL);
                // GitHub REST API requires a User-Agent header
                http.setHeader("User-Agent", 'SoulScorch-Engine/${Version.fullVersion()}');

                http.onData = function(data:String) {
                    try {
                        var parsed:Dynamic = Json.parse(data);
                        var tag:String = parsed.tag_name != null ? parsed.tag_name : "";
                        var isNewer:Bool = isVersionNewer(tag);

                        latestRelease = {
                            tagName: tag,
                            name: parsed.name != null ? parsed.name : tag,
                            body: parsed.body != null ? parsed.body : "",
                            htmlUrl: parsed.html_url != null ? parsed.html_url : 'https://github.com/$REPO_OWNER/$REPO_NAME',
                            publishedAt: parsed.published_at != null ? parsed.published_at : "",
                            isNewer: isNewer
                        };

                        hasChecked = true;

                        if (isNewer) {
                            Logger.info('Newer version found: ${latestRelease.tagName} (Current: v${Version.MAJOR}.${Version.MINOR}.${Version.PATCH})', "github");
                            EventBus.emit("github/updateAvailable", latestRelease);

                            if (autoNotifyOnUpdate && NotificationManager.instance != null) {
                                NotificationManager.instance.notify(
                                    "Update Available!",
                                    'SoulScorch ${latestRelease.tagName} is available on GitHub.'
                                );
                            }
                        } else {
                            Logger.info("Engine is up to date.", "github");
                            EventBus.emit("github/upToDate", latestRelease);
                        }

                        if (callback != null) {
                            callback(latestRelease);
                        }
                    } catch (e:Dynamic) {
                        Logger.error('Failed parsing GitHub API response: $e', "github");
                    }
                };

                http.onError = function(error:String) {
                    Logger.warn('GitHub API request failed: $error', "github");
                };

                http.request(false);
            } catch (e:Dynamic) {
                Logger.error('Could not initiate GitHub update check thread: $e', "github");
            }
        });
        #end
    }

    /**
     * Compares a semantic tag (e.g. "v0.7.0" or "0.7.0") against the local Version constants.
     */
    public static function isVersionNewer(remoteTag:String):Bool {
        var cleanTag = remoteTag.toLowerCase().trim();
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

    /**
     * Opens the repository or target release page directly in the default web browser.
     */
    public static function openReleasePage(?url:String):Void {
        var targetUrl = url != null ? url : 'https://github.com/$REPO_OWNER/$REPO_NAME/releases';
        #if linux
        Sys.command("xdg-open", [targetUrl]);
        #else
        flixel.FlxG.openURL(targetUrl);
        #end
    }
}