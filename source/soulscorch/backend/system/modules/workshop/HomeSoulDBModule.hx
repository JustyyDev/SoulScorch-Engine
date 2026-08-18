package soulscorch.backend.system.modules.workshop;

import haxe.Http;
import haxe.Json;
import flixel.FlxG;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.NotificationManager;
import soulscorch.backend.system.modules.Module.ModuleBase;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.thread.Thread;
#end

typedef SoulModEntry = {
    var modId:String;
    var title:String;
    var status:String;
    var isWIP:Bool;
    var author:String;
    var description:String;
    var version:String;
    var category:String;
    var downloadUrl:String;
    var teaserUrl:String;
    var bannerUrl:String;
    var bumpCount:Int;
    var streamerScore:Float;
    var lastBumped:Float;
    var tags:Array<String>;
}

class HomeSoulDBModule extends ModuleBase {
    public static var instance:HomeSoulDBModule;

    public static inline var RAW_CATALOG_URL:String = "https://raw.githubusercontent.com/JustyyDev/HomeSoulDB/main/data/catalog.json";
    public static inline var REPO_SUBMIT_URL:String = "https://github.com/JustyyDev/HomeSoulDB/issues/new?template=mod_submission.yml";

    public var catalog:Array<SoulModEntry> = [];
    public var isFetching:Bool = false;
    public var hasFetched:Bool = false;

    public function new(autoFetch:Bool = true) {
        super("homesoul_db");
        instance = this;
        if (autoFetch) {
            initialize();
        }
    }

    override public function initialize():Void {
        #if sys
        fetchCatalog();
        #end
    }

    public function fetchCatalog(?onComplete:Array<SoulModEntry>->Void):Void {
        #if sys
        if (isFetching) return;
        isFetching = true;

        Thread.create(function() {
            try {
                var http = new Http(RAW_CATALOG_URL);
                http.setHeader("User-Agent", "SoulScorch-Engine-Client");

                http.onData = function(data:String) {
                    isFetching = false;
                    hasFetched = true;
                    try {
                        var parsed:Array<Dynamic> = Json.parse(data);
                        catalog = [];

                        for (raw in parsed) {
                            var entry:SoulModEntry = {
                                modId: raw.modId != null ? raw.modId : "unknown_mod",
                                title: raw.title != null ? raw.title : "Untitled Mod",
                                status: raw.status != null ? raw.status : "Released",
                                isWIP: raw.isWIP != null ? raw.isWIP : false,
                                author: raw.author != null ? raw.author : "Anonymous",
                                description: raw.description != null ? raw.description : "",
                                version: raw.version != null ? raw.version : "1.0.0",
                                category: raw.category != null ? raw.category : "Custom Weeks",
                                downloadUrl: raw.downloadUrl != null ? raw.downloadUrl : "",
                                teaserUrl: raw.teaserUrl != null ? raw.teaserUrl : "",
                                bannerUrl: raw.bannerUrl != null ? raw.bannerUrl : "",
                                bumpCount: raw.bumpCount != null ? raw.bumpCount : 0,
                                streamerScore: raw.streamerScore != null ? raw.streamerScore : 1.0,
                                lastBumped: raw.lastBumped != null ? raw.lastBumped : 0.0,
                                tags: raw.tags != null ? cast raw.tags : []
                            };
                            catalog.push(entry);
                        }

                        Logger.info('[HOMESOUL-DB] Loaded ${catalog.length} mods from database.', "workshop");
                        if (EventBus.instance != null) {
                            EventBus.instance.emit("homesouldb/catalogLoaded", catalog);
                        }

                        if (onComplete != null) onComplete(catalog);
                    } catch (e:Dynamic) {
                        Logger.error('[HOMESOUL-DB] Parsing error: $e', "workshop");
                        if (onComplete != null) onComplete(null);
                    }
                };

                http.onError = function(err:String) {
                    isFetching = false;
                    Logger.warn('[HOMESOUL-DB] HTTP Fetch failed: $err', "workshop");
                    if (onComplete != null) onComplete(null);
                };

                http.request(false);
            } catch (e:Dynamic) {
                isFetching = false;
                Logger.error('[HOMESOUL-DB] Network thread failure: $e', "workshop");
                if (onComplete != null) onComplete(null);
            }
        });
        #end
    }

    public function openSubmissionPage():Void {
        #if linux
        Sys.command("xdg-open", [REPO_SUBMIT_URL]);
        #else
        FlxG.openURL(REPO_SUBMIT_URL);
        #end
    }

    public function downloadMod(entry:SoulModEntry, ?onComplete:Bool->Void):Void {
        #if sys
        if (entry.isWIP || entry.downloadUrl == null || entry.downloadUrl.length == 0) {
            if (entry.teaserUrl != null && entry.teaserUrl.length > 0) {
                FlxG.openURL(entry.teaserUrl);
            }
            if (onComplete != null) onComplete(false);
            return;
        }

        Thread.create(function() {
            try {
                var folder = "mods";
                if (!FileSystem.exists(folder)) {
                    FileSystem.createDirectory(folder);
                }

                var filePath = '$folder/${entry.modId}.zip';
                var http = new Http(entry.downloadUrl);
                Logger.info('[HOMESOUL-DB] Downloading "${entry.title}"...', "workshop");

                http.onBytes = function(bytes:haxe.io.Bytes) {
                    File.saveBytes(filePath, bytes);
                    Logger.info('[HOMESOUL-DB] Saved to $filePath', "workshop");

                    if (NotificationManager.instance != null) {
                        NotificationManager.instance.notify("Download Complete", '${entry.title} has been downloaded to /mods!');
                    }
                    if (onComplete != null) onComplete(true);
                };

                http.onError = function(err:String) {
                    Logger.error('[HOMESOUL-DB] Download failed: $err', "workshop");
                    if (onComplete != null) onComplete(false);
                };

                http.request(false);
            } catch (e:Dynamic) {
                Logger.error('[HOMESOUL-DB] Download exception: $e', "workshop");
                if (onComplete != null) onComplete(false);
            }
        });
        #end
    }
}