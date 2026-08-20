package soulscorch.backend.system.modules.github;

import haxe.Http;
import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.thread.Thread;
#end

typedef RemoteModInfo = {
    var name:String;
    var description:String;
    var author:String;
    var downloadUrl:String;
    var version:String;
    var iconUrl:Null<String>;
}

class ModRepositoryAPI {
    public static var defaultIndexUrl:String = "https://raw.githubusercontent.com/JustyyDev/SoulScorch-Engine/main/assets/preload/data/config/modRepository.json";

    public static function loadDefaultRepoUrl():String {
        var access:Access = XMSoul.parse("config/modRepository");
        if (access == null) access = XMSoul.parse("data/config/modRepository");

        if (access != null) {
            var url = XMSoul.getAttr(access, "indexUrl", "");
            if (url.length > 0) defaultIndexUrl = url;
        }
        return defaultIndexUrl;
    }

    public static function fetchModIndex(?indexUrl:String, onSuccess:Array<RemoteModInfo>->Void, ?onError:String->Void):Void {
        #if sys
        var targetUrl = (indexUrl != null && indexUrl.length > 0) ? indexUrl : loadDefaultRepoUrl();

        Thread.create(function() {
            var http = new Http(targetUrl);
            http.setHeader("User-Agent", "SoulScorch-Engine");

            http.onData = function(raw:String) {
                try {
                    var list:Array<RemoteModInfo> = [];

                    if (raw.trim().startsWith("<")) {
                        // Support XML / .xmsoul repository format
                        var xml = new Access(Xml.parse(raw).firstElement());
                        for (modNode in xml.nodes.mod) {
                            list.push({
                                name: XMSoul.getAttr(modNode, "name", "Unnamed Mod"),
                                description: XMSoul.getAttr(modNode, "description", ""),
                                author: XMSoul.getAttr(modNode, "author", "Unknown"),
                                downloadUrl: XMSoul.getAttr(modNode, "downloadUrl", ""),
                                version: XMSoul.getAttr(modNode, "version", "1.0.0"),
                                iconUrl: XMSoul.getAttr(modNode, "iconUrl", null)
                            });
                        }
                    } else {
                        // Standard JSON format
                        var parsed:Array<Dynamic> = Json.parse(raw);
                        for (item in parsed) {
                            list.push({
                                name: item.name != null ? item.name : "Unnamed Mod",
                                description: item.description != null ? item.description : "",
                                author: item.author != null ? item.author : "Unknown",
                                downloadUrl: item.downloadUrl != null ? item.downloadUrl : "",
                                version: item.version != null ? item.version : "1.0.0",
                                iconUrl: item.iconUrl != null ? item.iconUrl : null
                            });
                        }
                    }

                    if (onSuccess != null) onSuccess(list);
                } catch (e:Dynamic) {
                    if (onError != null) onError('Failed parsing mod repository index: $e');
                }
            };

            http.onError = function(err:String) {
                if (onError != null) onError(err);
            };

            http.request(false);
        });
        #end
    }

    public static function downloadModZip(url:String, modFolder:String, onComplete:Bool->Void):Void {
        #if sys
        Thread.create(function() {
            try {
                var http = new Http(url);
                http.setHeader("User-Agent", "SoulScorch-Engine");

                var targetDir = 'mods/$modFolder';
                if (!FileSystem.exists("mods")) FileSystem.createDirectory("mods");
                if (!FileSystem.exists(targetDir)) FileSystem.createDirectory(targetDir);

                var savePath = '$targetDir/package.zip';
                var bytesOutput = new haxe.io.BytesOutput();

                http.customRequest(false, bytesOutput);

                var bytes = bytesOutput.getBytes();
                File.saveBytes(savePath, bytes);

                Logger.info('Mod archive downloaded successfully: $savePath', "github");
                if (onComplete != null) onComplete(true);
            } catch (e:Dynamic) {
                Logger.error('Failed downloading mod package: $e', "github");
                if (onComplete != null) onComplete(false);
            }
        });
        #end
    }
}