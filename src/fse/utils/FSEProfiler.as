package fse.utils
{
import flash.utils.Dictionary;
import flash.utils.getTimer;

public class FSEProfiler
{
	private static var _times:Dictionary = new Dictionary();
	private static var _startMarks:Dictionary = new Dictionary();
	
	// 开始记录
	public static function begin(moduleName:String):void
	{
		_startMarks[moduleName] = getTimer();
	}
	
	// 结束记录并累加时间
	public static function end(moduleName:String):void
	{
		if (_startMarks[moduleName] != undefined) {
			var elapsed:int = getTimer() - _startMarks[moduleName];
			if (_times[moduleName] == undefined) {
				_times[moduleName] = 0;
			}
			_times[moduleName] += elapsed;
		}
	}
	
	// 在应用退出或测试结束时调用，打印耗时排行榜
	public static function dump():void
	{
		trace("========== FSE Profiler 性能报告 ==========");
		var results:Array = [];
		for (var key:String in _times) {
			results.push({name: key, time: _times[key]});
		}
		// 按耗时从高到低排序
		results.sortOn("time", Array.NUMERIC | Array.DESCENDING);
		
		for (var i:int = 0; i < results.length; i++) {
			trace("[" + results[i].name + "] 总耗时: " + results[i].time + " ms");
		}
		trace("==========================================");
	}
}
}