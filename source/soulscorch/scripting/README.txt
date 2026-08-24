SoulScorch scripting
====================

Song scripts may use .hx, .hscript, .soul, .lua, or .py. HScript, Iris, and SoulScript run in-process. Lua is available for desktop C++ builds with LUA_ALLOWED. Python callbacks run as external processes and should be reserved for infrequent hooks.

Core lifecycle callbacks
------------------------
onCreate(), onPostCreate(), onSongStart(), onUpdate(elapsed), onUpdatePost(elapsed), onBeatHit(beat), onStepHit(step), onDestroy()

Gameplay callbacks
------------------
onCountdownTick(index)
onSectionChange(section, mustHitSection)
onNoteSpawn(note)
onNoteHit(note)
onOpponentNoteHit(note)
onPlayerMiss(direction)
onKeyPress(direction), onKeyRelease(direction), onGhostTap(direction)
onHealthChange(health, maxHealth)
onEvent(name, value1, value2)

Cancellable callbacks
---------------------
Return false from onBeforeNoteHit(note), onBeforeOpponentNoteHit(note), onBeforePlayerMiss(direction), onBeforeEvent(name, value1, value2), onBeforePause(), or onBeforeGameOver() to suppress the engine's default action. Every active script still receives the callback.

Runtime helpers
---------------
spawnNote(time, direction, mustPress, type, sustainLength)
queueEvent(time, name, value1, value2)
triggerEvent(name, value1, value2)
getGameplayFlag(name, fallback), setGameplayFlag(name, value)

ScriptTools
-----------
ScriptTools.screenToWorld(x, y, camera)
ScriptTools.worldToScreen(x, y, camera)
ScriptTools.placeAtScreen(object, x, y, camera)
ScriptTools.placeAtScreenCenter(object, camera, offsetX, offsetY)
ScriptTools.centerAtWorld(object, x, y)
ScriptTools.fitToCamera(sprite, camera, cover)
ScriptTools.setCameraAnchor(x, y, immediate)
ScriptTools.addToStageLayer(object, layerName)
ScriptTools.getStageSprite(name)
ScriptTools.getProperty(root, path), ScriptTools.setProperty(root, path, value)
ScriptTools.after(seconds, callback), ScriptTools.every(seconds, callback, loops)
ScriptTools.cancelTweens(object), ScriptTools.removeCamera(camera, destroy)

Lua exposes equivalent screenToWorldX/Y, worldToScreenX/Y, setCameraAnchor, addToStageLayer, and fitObjectToCamera callbacks.
