SoulScorch scripting
====================

Song scripts may use .hx, .hscript, .soul, .lua, .py, or .js. HScript, Iris, SoulScript, and desktop/mobile C++ Lua run in-process. Python and JavaScript callbacks run as external processes and should be reserved for infrequent hooks. JavaScript uses the `node` executable and receives `{callback, args, context}` as its third argument JSON payload.

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

Shared engine API
-----------------
Every in-process script context receives ScriptAPI and the same helpers. This includes song scripts, global scripts, scripted states, scripted substates, scripted sprites, and mod states.

createShader(name), addShaderToCam(name, camera), removeShaderFromCam(name, camera)
setShaderFloat(name, uniform, value), setShaderFloatArray(name, uniform, values)
setShaderInt(name, uniform, value), setShaderBool(name, uniform, value)
setSpriteShader(sprite, name), clearCameraShaders(camera)
setDiscordPresence(details, state, largeImageKey, smallImageKey)
setDiscordEnabled(enabled), reloadDiscordConfig(), checkGitHubUpdates()
setChartEditorPresence(song, step, bpm), setScriptDebuggingPresence(script)
setLobbyPresence(name, players, maxPlayers, partyId)
setAchievementsPresence(unlocked, total), setMusicPlayerPresence(track, artist)
getColor(value, fallback)

Python scripts run in a separate process. They can use the same lifecycle callbacks and return JSON or text to the engine, but cannot directly hold live Haxe objects. Use HScript, SoulScript, or Lua for real-time object and camera control.

SoulScript beginner syntax
---------------------------
SoulScript uses indentation for small, readable scripts. Beat and step blocks run once when that beat or step is reached, rather than once per frame.

on create:
	play sound "confirmMenu" at 0.8

every 4 beats:
	camera shake 0.01 for 0.15s

at beat 8:
	play music "breakfast" at 0.7

on update:
	if health < 0.5:
		camera flash RED for 0.2s
	else if health > 1.5:
		setFlag "feelingGood" to true

Useful beginner commands include play sound, play music, camera shake, camera flash, wait, getFlag, and setFlag. Regular HScript expressions can still be used when a mod needs more control.

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
