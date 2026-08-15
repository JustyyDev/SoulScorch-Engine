package haxe;

#if !lime_cffi
/*
 * Copyright (C)2005-2018 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
class Timer {
	#if (flash || js)
	private var id:Null<Int>;
	#elseif java
	private var timer:java.util.Timer;
	private var task:java.util.TimerTask;
	#elseif (haxe_ver >= "3.4.0")
	private var event:MainLoop.MainEvent;
	#end

	public function new(time_ms:Int) {
		#if flash
		var me = this;
		id = untyped __global__["flash.utils.setInterval"](function() {
			me.run();
		}, time_ms);
		#elseif js
		var me = this;
		id = untyped setInterval(function() me.run(), time_ms);
		#elseif java
		timer = new java.util.Timer();
		timer.scheduleAtFixedRate(task = new TimerTask(this), haxe.Int64.ofInt(time_ms), haxe.Int64.ofInt(time_ms));
		#elseif (haxe_ver >= "3.4.0")
		var dt = time_ms / 1000;
		event = MainLoop.add(function() {
			@:privateAccess event.nextRun += dt;
			run();
		});
		event.delay(dt);
		#end
	}

	public function stop():Void {
		#if (flash || js)
		if (id == null) return;
		#if flash
		untyped __global__["flash.utils.clearInterval"](id);
		#elseif js
		untyped clearInterval(id);
		#end
		id = null;
		#elseif java
		if (timer != null) {
			timer.cancel();
			timer = null;
		}
		task = null;
		#elseif (haxe_ver >= "3.4.0")
		if (event != null) {
			event.stop();
			event = null;
		}
		#end
	}

	public dynamic function run():Void {}

	public static function delay(f:Void->Void, time_ms:Int):Timer {
		var t = new haxe.Timer(time_ms);
		t.run = function() {
			t.stop();
			f();
		};
		return t;
	}

	public static function measure<T>(f:Void->T, ?pos:PosInfos):T {
		var t0 = stamp();
		var r = f();
		Log.trace((stamp() - t0) + "s", pos);
		return r;
	}

	public static function stamp():Float {
		#if flash
		return flash.Lib.getTimer() / 1000;
		#elseif (neko || php)
		return Sys.time();
		#elseif js
		return Date.now().getTime() / 1000;
		#elseif cpp
		return untyped __global__.__time_stamp();
		#elseif python
		return Sys.cpuTime();
		#elseif sys
		return Sys.time();
		#else
		return 0;
		#end
	}
}

#if java
@:nativeGen
private class TimerTask extends java.util.TimerTask {
	var timer:Timer;

	public function new(timer:Timer):Void {
		super();
		this.timer = timer;
	}

	@:overload override public function run():Void {
		timer.run();
	}
}
#end

#else

import lime.system.System;

class Timer {
	public static var sRunningTimers:Array<Timer> = [];

	public var mTime:Float;
	public var mFireAt:Float;
	public var mRunning:Bool;

	public function new(time:Float) {
		mTime = time;
		sRunningTimers.push(this);
		mFireAt = getMS() + mTime;
		mRunning = true;
	}

	public static function delay(f:Void->Void, time:Int):Timer {
		var t = new Timer(time);
		t.run = function() {
			t.stop();
			f();
		};
		return t;
	}

	private static function getMS():Float {
		return System.getTimer();
	}

	public static function measure<T>(f:Void->T, ?pos:PosInfos):T {
		var t0 = stamp();
		var r = f();
		Log.trace((stamp() - t0) + "s", pos);
		return r;
	}

	dynamic public function run():Void {}

	public static function stamp():Float {
		var timer = System.getTimer();
		return (timer > 0 ? timer / 1000 : 0);
	}

	public function stop():Void {
		mRunning = false;
	}

	@:noCompletion public function __check(inTime:Float):Void {
		if (inTime >= mFireAt) {
			mFireAt += mTime;
			run();
		}
	}
}
#end