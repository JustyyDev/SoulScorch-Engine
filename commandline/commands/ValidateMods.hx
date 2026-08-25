package commands;

import soulscorch.scripting.mod.ModValidator;
import soulscorch.scripting.mod.SoulModParser;

#if sys
import sys.FileSystem;
#end

class ValidateMods {
    public static function main(args:Array<String>):Void {
        #if sys
        var root = args.length > 0 ? args[0] : "mods";
        if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) {
            Sys.println('No mods directory found at: $root');
            return;
        }

        var folders = [];
        for (folder in FileSystem.readDirectory(root)) {
            var full = '$root/$folder';
            if (FileSystem.isDirectory(full) && !folder.startsWith(".") && !folder.startsWith("_")) {
                folders.push(folder);
            }
        }

        var foundWarnings = 0;
        for (folder in folders) {
            var full = '$root/$folder';
            var data = SoulModParser.parseFolder(full, folder);
            var warnings = ModValidator.validateFolder(full, folder, data, folders);
            if (warnings.length == 0) {
                Sys.println('[OK] $folder');
            } else {
                foundWarnings += warnings.length;
                Sys.println('[WARN] $folder');
                for (warning in warnings) Sys.println('  - $warning');
            }
        }

        Sys.println('Checked ${folders.length} mod(s). Warnings: $foundWarnings');
        if (foundWarnings > 0) Sys.exit(1);
        #else
        Sys.println("Mod validation requires a sys target.");
        #end
    }
}
