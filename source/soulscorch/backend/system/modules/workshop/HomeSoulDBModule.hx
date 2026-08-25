package soulscorch.backend.system.modules.workshop;

import haxe.Http;
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.zip.Reader;
import haxe.zip.Entry;
import flixel.FlxG;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.NotificationManager;
import soulscorch.backend.system.modules.Module.ModuleBase;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.thread.Thread;
#end

using StringTools;

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
    public static inline var CACHE_PATH:String = "mods/.homesouldb_catalog_cache.json";

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
                        catalog = parseCatalog(data);
                        saveCatalogCache(data);

                        Logger.info('[HOMESOUL-DB] Loaded ${catalog.length} mods from database.', "workshop");
                        if (EventBus.instance != null) {
                            EventBus.instance.emit("homesouldb/catalogLoaded", catalog);
                        }

                        if (onComplete != null) onComplete(catalog);
                    } catch (e:Dynamic) {
                        Logger.error('[HOMESOUL-DB] Parsing error: $e', "workshop");
                        if (onComplete != null) onComplete(loadCachedCatalog());
                    }
                };

                http.onError = function(err:String) {
                    isFetching = false;
                    Logger.warn('[HOMESOUL-DB] HTTP Fetch failed: $err', "workshop");
                    if (onComplete != null) onComplete(loadCachedCatalog());
                };

                http.request(false);
            } catch (e:Dynamic) {
                isFetching = false;
                Logger.error('[HOMESOUL-DB] Network thread failure: $e', "workshop");
                if (onComplete != null) onComplete(loadCachedCatalog());
            }
        });
        #end
    }

    private function parseCatalog(data:String):Array<SoulModEntry> {
        var parsed:Array<Dynamic> = Json.parse(data);
        var result:Array<SoulModEntry> = [];

        for (raw in parsed) {
            result.push({
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
            });
        }

        return result;
    }

    #if sys
    private function saveCatalogCache(data:String):Void {
        try {
            if (!FileSystem.exists("mods")) FileSystem.createDirectory("mods");
            File.saveContent(CACHE_PATH, data);
        } catch (e:Dynamic) {
            Logger.warn('[HOMESOUL-DB] Could not save catalog cache: $e', "workshop");
        }
    }

    private function loadCachedCatalog():Array<SoulModEntry> {
        try {
            if (FileSystem.exists(CACHE_PATH)) {
                catalog = parseCatalog(File.getContent(CACHE_PATH));
                hasFetched = true;
                Logger.info('[HOMESOUL-DB] Loaded ${catalog.length} mods from cached catalog.', "workshop");
                return catalog;
            }
        } catch (e:Dynamic) {
            Logger.warn('[HOMESOUL-DB] Could not load cached catalog: $e', "workshop");
        }
        return null;
    }
    #else
    private function saveCatalogCache(data:String):Void {}
    private function loadCachedCatalog():Array<SoulModEntry> return null;
    #end

    public function openSubmissionPage():Void {
        #if linux
        Sys.command("xdg-open", [REPO_SUBMIT_URL]);
        #else
        FlxG.openURL(REPO_SUBMIT_URL);
        #end
    }

    public function downloadMod(entry:SoulModEntry, ?onProgress:Float->Void, ?onComplete:Bool->Void):Void {
        #if sys
        if (entry.isWIP || entry.downloadUrl == null || entry.downloadUrl.trim().length == 0) {
            if (entry.teaserUrl != null && entry.teaserUrl.trim().length > 0) {
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

                var zipPath = '$folder/${entry.modId}.zip';
                var targetExtractedFolder = '$folder/${sanitizePathSegment(entry.modId)}';

                var http = new Http(entry.downloadUrl);
                http.setHeader("User-Agent", "SoulScorch-Engine-Client");
                Logger.info('[HOMESOUL-DB] Downloading "${entry.title}"...', "workshop");

                http.onBytes = function(bytes:haxe.io.Bytes) {
                    try {
                        File.saveBytes(zipPath, bytes);
                        Logger.info('[HOMESOUL-DB] Package downloaded to $zipPath. Unpacking...', "workshop");

                        // Extract ZIP contents directly into target mod folder
                        uncompressZip(bytes, targetExtractedFolder);

                        // Clean up temporary downloaded zip archive
                        if (FileSystem.exists(zipPath)) {
                            FileSystem.deleteFile(zipPath);
                        }

                        // Hot-reload active registry
                        ModManager.reloadMods();

                        Logger.info('[HOMESOUL-DB] Successfully installed package: ${entry.title}', "workshop");

                        if (NotificationManager.instance != null) {
                            NotificationManager.instance.notify("Installation Complete", '${entry.title} is now active!');
                        }
                        if (onComplete != null) onComplete(true);
                    } catch (e:Dynamic) {
                        Logger.error('[HOMESOUL-DB] Extraction error: $e', "workshop");
                        if (onComplete != null) onComplete(false);
                    }
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

    #if sys
    private function uncompressZip(bytes:Bytes, targetDir:String):Void {
        if (!FileSystem.exists(targetDir)) {
            FileSystem.createDirectory(targetDir);
        }

        var input = new BytesInput(bytes);
        var entries = Reader.readZip(input);
        var rootPrefix = detectSingleRootPrefix(entries);

        for (record in entries) {
            var fileName = sanitizeZipPath(record.fileName, rootPrefix);
            if (fileName.length == 0) continue;

            if (fileName.endsWith("/")) {
                var dirPath = '$targetDir/$fileName';
                if (!FileSystem.exists(dirPath)) FileSystem.createDirectory(dirPath);
                continue;
            }

            var filePath = '$targetDir/$fileName';
            var fileDir = haxe.io.Path.directory(filePath);
            if (!FileSystem.exists(fileDir)) {
                FileSystem.createDirectory(fileDir);
            }

            var data = Reader.unzip(record);
            File.saveBytes(filePath, data);
        }
    }

    private function sanitizePathSegment(value:String):String {
        if (value == null || value.trim().length == 0) return "unknown_mod";
        return ~/[^A-Za-z0-9_.-]/g.replace(value.trim(), "_");
    }

    private function detectSingleRootPrefix(entries:List<Entry>):String {
        var root:String = null;
        for (record in entries) {
            var clean = record.fileName.replace("\\", "/");
            while (clean.startsWith("/")) clean = clean.substr(1);
            if (clean.length == 0 || clean.indexOf("../") != -1 || clean.startsWith("..")) continue;
            var slash = clean.indexOf("/");
            if (slash <= 0) return "";
            var candidate = clean.substr(0, slash + 1);
            if (root == null) root = candidate;
            else if (root != candidate) return "";
        }
        return root != null ? root : "";
    }

    private function sanitizeZipPath(raw:String, rootPrefix:String):String {
        if (raw == null) return "";
        var clean = raw.replace("\\", "/");
        while (clean.startsWith("/")) clean = clean.substr(1);
        if (rootPrefix != null && rootPrefix.length > 0 && clean.startsWith(rootPrefix)) {
            clean = clean.substr(rootPrefix.length);
        }
        if (clean.length == 0 || clean == "." || clean.indexOf("../") != -1 || clean.startsWith("..") || clean.indexOf(":") != -1) {
            Logger.warn('[HOMESOUL-DB] Skipped unsafe zip entry: $raw', "workshop");
            return "";
        }
        return clean;
    }
    #end
}