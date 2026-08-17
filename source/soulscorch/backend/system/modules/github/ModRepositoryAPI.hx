package soulscorch.backend.system.modules.github;

import haxe.Http;
import haxe.Json;
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
}

class ModRepositoryAPI {
    /**
     * Fetches a structured list of community mods from a raw GitHub JSON index.
     */
    public static function fetchModIndex(indexUrl:String, onSuccess:Array<RemoteModInfo>->Void, ?onError:String->Void):Void {
        #if sys
        Thread.create(function() {
            var http = new Http(indexUrl);
            http.setHeader("User-Agent", "SoulScorch-Engine");

            http.onData = function(raw:String) {
                try {
                    var parsed:Array<Dynamic> = Json.parse(raw);
                    var list:Array<RemoteModInfo> = [];

                    for (item in parsed) {
                        list.push({
                            name: item.name != null ? item.name : "Unnamed Mod",
                            description: item.description != null ? item.description : "",
                            author: item.author != null ? item.author : "Unknown",
                            downloadUrl: item.downloadUrl != null ? item.downloadUrl : "",
                            version: item.version != null ? item.version : "1.0.0"
                        });
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

    /**
     * Downloads a remote `.zip` mod archive directly into the local `mods/` directory.
     */
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