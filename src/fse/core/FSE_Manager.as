package fse.core
{
import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import flash.display.MovieClip;
import flash.display.Stage;
import flash.utils.Dictionary;

import fse.cache.CacheManager;
import fse.display.*;
import fse.starling.StarlingManager;

import starling.display.Sprite;

/**
	* FSE 内部管理器
	* 职责：存储数据、管理对象列表、处理层级快照
 	* 这个类是整个FSE框架对象影子树部分的总管,他持有多个控制器对象 其他类只需要找他就可以访问到对应的组件类
	*/
	public class FSE_Manager
	{
		// 存储逻辑帧监听列表
		// 结构: Key = scope (MovieClip), Value = Vector.<Function>
		private var _logicListeners:Dictionary;
		
		//FSE全局配置相关
		public static var keyRole:String;
		public static var noGPU:Boolean = false;
		//监控器
		public static var watcher:Watcher;
		//动画控制器
		public static var controller:Controller;
		//扫描器
		public static var scanner:Scanner;
		
		
		//持有 Stage 引用，以便传递给 Watcher
		private var _stageRef:Stage;
		private var _scanRoot:DisplayObjectContainer;
		private var _rootRef:DisplayObjectContainer;

		// [新增] 持有引用
		private var _starlingManager:StarlingManager;

		public function FSE_Manager(stageRef:Stage,scanRoot:DisplayObjectContainer)
		{
			_stageRef = stageRef;
			_scanRoot = scanRoot;

			// [新增] 立即实例化 StarlingManager (此时它处于未就绪状态)
			if (! FSE.noGPU)
			{
				_starlingManager = new StarlingManager();
			}

			_logicListeners = new Dictionary(true);

			// 初始化控制器和扫描器
			controller = new Controller();
			scanner = new Scanner();
			
			// 初始化监控器和扫描器
			watcher = new Watcher(controller,scanner); //将动画控制器传给监控器操作
			
			
			
		}


		public function activateStarling(rootLayer:Sprite,rootStarlingUserLayerBack:Sprite,rootStarlingUserLayerFront:Sprite):void
		{
			if (_starlingManager)
			{
				_starlingManager.activate(rootLayer,rootStarlingUserLayerFront,rootStarlingUserLayerBack);
			}
		}


		/**
		* [新增] 设置某个对象的缓存策略
		*/
		public function setCacheEnabled(target:DisplayObject,value:Boolean):void
		{
			if (watcher)
			{
				watcher.setNodeCacheConfig(target,value);
			}
		}

		/**
		* [新增] 强制清理 GPU 缓存
		*/
		public function clearGPU():void
		{
			CacheManager.instance.purge();
		}


		/**
		* [新增] 延迟设置扫描根节点
		*/
		public function setScanRoot(target:DisplayObjectContainer):void
		{
			_scanRoot = target;
			// 立即扫描一次，建立初始画面
			if (watcher)
			{
				watcher.scan(_scanRoot);
			}
		}

		public function ignoreObject(target:Object):void
		{
			if ((watcher && target is DisplayObject))
			{
				watcher.addIgnore((target as DisplayObject));
			}
		}

		public function no_ignoreObject(target:Object):void
		{
			if ((watcher && target is DisplayObject))
			{
				watcher.removeIgnore((target as DisplayObject));
			}
		}

		public function is_ignoreObject(target:Object):Boolean
		{
			if ((watcher && target is DisplayObject))
			{
				return watcher.isIgnore((target as DisplayObject));
			}
			return false;
		}
		
		public function setVisible(mc:DisplayObject,value:Boolean):void
		{
			if (controller)
			{
				controller.setVisible(mc,value);
			}
		}

		public function getVisible(mc:DisplayObject):Boolean
		{
			if (controller)
			{
				return controller.isVisible(mc);
			}
			return false;
		}

		/**
		* 添加逻辑帧监听
		* @param scope 上下文对象 (通常是 this)
		* @param listener 回调函数
		*/
		public function addLogicListener(scope:Object,listener:Function):void
		{
			if (! _logicListeners[scope])
			{
				_logicListeners[scope] = new Vector.<Function >;
			}

			// 简单的查重，防止重复添加
			var list:Vector.<Function >  = _logicListeners[scope];
			if (list.indexOf(listener) == -1)
			{
				list.push(listener);
			}
		}

		// 在 FSE_Manager 类中添加以下方法

		/**
		 * 移除逻辑帧监听
		 */
		public function removeLogicListener(scope:Object,listener:Function):void
		{
			// 如果这个对象本身就没监听过，直接返回
			if (! _logicListeners[scope])
			{
				return;
			}

			var list:Vector.<Function >  = _logicListeners[scope];
			var index:int = list.indexOf(listener);

			// 如果在列表中找到了这个函数，将其移除
			if ((index != -1))
			{
				list.splice(index,1);
			}

			// 内存优化：如果这个对象已经没有任何监听函数了，清理掉它的 Dictionary Key
			if (list.length == 0)
			{
				delete _logicListeners[scope];
			}
		}

		/**
		* 执行一次逻辑帧 (由 FSE 调用)
		* 遍历所有监听者并执行回调
		*/
		
		public function executeLogicStep():void
		{
			//稳定60帧触发
			// 触发用户写的 loop 逻辑
			for (var scope:Object in _logicListeners)
			{
				var list:Vector.<Function >  = _logicListeners[scope];
				for each (var func:Function in list)
				{
					// 执行用户的 loop
					if (func.length == 0)
					{
						func();
					}
					if (func.length == 1)
					{
						func(null);
					}
				}
			}
			// 1. 驱动动画控制 (计算下一帧应该是第几帧)
			if (controller)
			{
				controller.advanceTime();
			}
		
			
		}
		public function Update():void
		{
			//超高帧触发
			// 驱动注册的动画剪辑 (场景监控)
			if ((watcher && _scanRoot))
			{
				watcher.scan(_scanRoot);
			}
		}
		// [新增] 暴露 API 给 FSE 静态类调用
		public function playMC(mc:MovieClip):void
		{
			controller.play(mc);
		}
		public function stopMC(mc:MovieClip):void
		{
			controller.stop(mc);
		}
		public function gotoAndStopMC(mc:MovieClip,frame:uint):void
		{
			controller.gotoAndStop(mc,frame);
		}
		public function gotoAndPlayMC(mc:MovieClip,frame:uint):void
		{
			controller.gotoAndPlay(mc,frame);
		}
	}
}