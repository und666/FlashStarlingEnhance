package fse.display
{
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.utils.Dictionary;
	
	import fse.conf.*;
	/**
	 * 状态保存器
	 * 职责：
	 * 1. 集中管理所有对象的状态 (播放、忽略、可见性)
	 * 2. 解决对象在显示列表中移动导致的 Node 重建时的状态丢失问题
	 * 3. 通过 ID 映射实现持久化状态
	 */
	public class StatusSaver
	{
		// [配置库] 存储逻辑状态 (Key: String = FSE_ID)
		// 包含: "xxx_playing", "xxx_ignore", "xxx_visible"
		private static var _settingsMap:Dictionary = new Dictionary();

		// [对象库] 存储当前活跃的 MC 引用 (Key: MovieClip, Value: true) - 弱引用
		// 替代原来的 _allMCs 和 _playingMCs 的部分职能
		public static var activeObjects:Dictionary = new Dictionary(true);

		// [加速库] 忽略判断的快速缓存 (Key: DisplayObject)
		public static var noIgnoreCache:Dictionary = new Dictionary(true);
		
		private static var mID:int = 0;
		/**
		 * [核心] 获取对象的唯一标识符 (FSE_ID)
		 * 策略：
		 * 1. MovieClip -> 动态注入 __fse_guid 属性。伴随对象生命周期，搬运不丢失。
		 * 2. 其他对象 -> 使用 name 属性。
		 */
		public static function getID(target:DisplayObject):String
		{
			
			if (!target) return null;
			
			if (target is MovieClip)
			{
				// 利用 Flash 动态类特性注入变量
				var mc:MovieClip = target as MovieClip;
				if (mc["__fse_guid"] == undefined)
				{
					// 生成唯一 ID (时间戳 + 随机数 + 原始名)
					mc["__fse_guid"] = genID();
				}
				return mc["__fse_guid"];
			}
			else
			{
				// 非 MC 对象使用 name (如用户所愿)
				return target.name;
			}
		}
	
		
		public static function genID():String{
			mID++;
			return "mc_" + new Date().time + "_" +String(mID);
		}
	
		// ========================== 播放状态管理 ==========================

		public static function setPlayState(target:DisplayObject, isPlaying:Boolean):void
		{
			var id:String = getID(target);
			if (id) _settingsMap[id + "_playing"] = isPlaying;
		}

		/**
		 * 检查一个对象是否应该播放
		 * 如果没有记录，默认规则：MovieClip 且总帧数>1 默认为播放(true)
		 */
		public static function isPlaying(target:DisplayObject):Boolean
		{
			var id:String = getID(target);
			if (!id) return false;
			
			// 查表
			if (_settingsMap[id + "_playing"] !== undefined)
			{
				return _settingsMap[id + "_playing"];
			}else{
				return !Config.STOP_ALL;
			}
			
			// 默认行为：如果是 MC 且有多帧，默认为播放
			if (target is MovieClip && (target as MovieClip).totalFrames > 1) return true;
			
			return false;
		}

		// ========================== 忽略状态管理 ==========================

		public static function setIgnore(target:DisplayObject, value:Boolean):void
		{
			var id:String = getID(target);
			if (id) 
			{
				if (value) _settingsMap[id + "_ignore"] = true;
				else delete _settingsMap[id + "_ignore"];
			}
		}

		public static function isIgnore(target:DisplayObject):Boolean
		{
			var id:String = getID(target);
			return id && _settingsMap[id + "_ignore"] === true;
		}

		// ========================== 可见性状态管理 ==========================

		public static function setLogicalVisible(target:DisplayObject, visible:Boolean):void
		{
			var id:String = getID(target);
			if (!id) return;

			if (visible)
			{
				// true 是默认值，删除记录以省内存
				delete _settingsMap[id + "_visible"];
			}
			else
			{
				_settingsMap[id + "_visible"] = false;
			}
		}
		
		public static function getLogicalVisible(target:DisplayObject):Boolean
		{
			var id:String = getID(target);
			// 默认为 true，除非显式记录为 false
			
			if (id && _settingsMap[id + "_visible"] === false) return false;
			return true;
		}
		
		public static function setOriginVisible(target:DisplayObject,visible:Boolean):void
		{
			var id:String = getID(target);
			if (!id) return;
			_settingsMap[id + "_origin_visible"] = visible;
		}
		
		public static function getOriginVisible(target:DisplayObject):Boolean
		{
			var id:String = getID(target);
			// 默认为 true，除非显式记录为 false
			if (id && _settingsMap[id + "_origin_visible"] === false) return false;
			return true;
		}
		public static function hasVisible(target:DisplayObject):Boolean
		{
			var id:String = getID(target);
			if(_settingsMap[id + "_origin_visible"] === undefined)return false;
			return _settingsMap[id + "_origin_visible"];
		}
		
		// ========================== 缓存策略管理 ==========================
		// (可选：如果你想把 cacheConfig 也移过来)
		public static function setCacheConfig(target:DisplayObject, enable:Boolean):void
		{
			var id:String = getID(target);
			if(id) _settingsMap[id + "_cache"] = enable;
		}
		
		public static function getCacheConfig(target:DisplayObject):Boolean
		{
			var id:String = getID(target);
			// 默认 true
			if(id && _settingsMap[id + "_cache"] === false) return false;
			return true;
		}
		
		/**
		 * 清理某个对象的所有状态 (当对象真正销毁时调用)
		 */
		public static function clearState(target:DisplayObject):void
		{
			// 注意：因为我们希望支持“搬运”，所以一般不由 Watcher 轻易调用清理
			// 除非确定对象彻底从内存移除。暂时留空或由外部手动管理。
		}
	}
}