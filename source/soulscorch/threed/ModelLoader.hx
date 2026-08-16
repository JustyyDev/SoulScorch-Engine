package soulscorch.threed;

import soulscorch.modding.ModManager;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class ModelLoader {
    public static function loadOBJ(modelName:String):Null<Mesh3D> {
        var path:String = ModManager.getPath(modelName.indexOf(".") >= 0 ? modelName : "models/" + modelName + ".obj");
        #if sys
        if (path == null || !FileSystem.exists(path)) return null;
        return parseOBJ(File.getContent(path));
        #else
        return null;
        #end
    }
    public static function parseOBJ(source:String):Mesh3D {
        var positions:Array<Float> = []; var normals:Array<Float> = []; var uvs:Array<Float> = []; var outVertices:Array<Float> = []; var outNormals:Array<Float> = []; var outUvs:Array<Float> = []; var indices:Array<Int> = [];
        if (source == null) return new Mesh3D();
        for (line in source.split("\n")) {
            var clean:String = StringTools.trim(line); var parts:Array<String> = clean.split(" "); if (parts.length == 0) continue;
            switch (parts[0]) {
                case "v": if (parts.length >= 4) for (i in 1...4) positions.push(Std.parseFloat(parts[i]));
                case "vn": if (parts.length >= 4) for (i in 1...4) normals.push(Std.parseFloat(parts[i]));
                case "vt": if (parts.length >= 3) { uvs.push(Std.parseFloat(parts[1])); uvs.push(Std.parseFloat(parts[2])); }
                case "f": if (parts.length >= 4) for (i in 1...parts.length) { var face:Array<String> = parts[i].split("/"); var vi:Int = Std.parseInt(face[0]) - 1; if (vi >= 0 && vi * 3 + 2 < positions.length) { outVertices.push(positions[vi * 3]); outVertices.push(positions[vi * 3 + 1]); outVertices.push(positions[vi * 3 + 2]); indices.push(Std.int(outVertices.length / 3) - 1); } }
            }
        }
        var mesh:Mesh3D = new Mesh3D(); mesh.setGeometry(outVertices, indices, outNormals, outUvs); return mesh;
    }
}
