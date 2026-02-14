package fse.core
{
	import fse.events.FSE_Event;
	import fse.conf.Config;
	import flash.display.Stage;
	import flash.display.DisplayObjectContainer;
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.events.Event;
	import starling.display.Sprite;

	public class FSE
	{
		
		private static var isInit:Boolean = false;
		
		// ------------------------------------------------
		// 公共 API (给用户用的)
		// ------------------------------------------------
		
		/**
		* 初始化 FSE 框架
		*/
		public static function init(stageRef:Stage, gameRoot:DisplayObjectContainer, takeOver:Boolean=true):void
		{
			FSE_Kernel.instance.init(stageRef, gameRoot, takeOver);
			isInit=true;
		}
		
		// ------------------------------------------------
		// 控制类 API
		// ------------------------------------------------

		public static function play(mc:MovieClip):void
		{
			
			if (kernel.managerAvailable) kernel.manager.playMC(mc);
			else mc.play();
		}

		public static function stop(mc:MovieClip):void
		{
			if (kernel.managerAvailable)kernel.manager.stopMC(mc);
			else mc.stop();
		}
		public static function gotoAndStop(mc:MovieClip,frame:uint):void
		{
			if (kernel.managerAvailable)kernel.manager.gotoAndStopMC(mc,frame);
			else mc.gotoAndStop(frame);
		}
		public static function gotoAndPlay(mc:MovieClip,frame:uint):void
		{
			if (kernel.managerAvailable)kernel.manager.gotoAndPlayMC(mc,frame);
			else mc.gotoAndPlay(frame);
		}
		public static function visible(mc:DisplayObject, value:Boolean):void
		{
			if (kernel.managerAvailable) kernel.manager.setVisible(mc, value);
			else mc.visible=value;
		}
		
		public static function getVisible(mc:DisplayObject):Boolean
		{
			return kernel.managerAvailable ? kernel.manager.getVisible(mc) : mc.visible;
		}
		
		// ------------------------------------------------
		// 高级设置 API
		// ------------------------------------------------

		public static function get noGPU():Boolean
		{
			return FSE_Manager.noGPU;
		}

		public static function ban(target:Object):void
		{
			if (kernel.managerAvailable && target is DisplayObject) kernel.manager.ignoreObject(target);
		}

		public static function noBan(target:Object):void
		{
			if (kernel.managerAvailable && target is DisplayObject) kernel.manager.no_ignoreObject(target);
		}

		public static function gpu(target:Object):void { noBan(target); }
		public static function cpu(target:Object):void { ban(target); }

		
		public static function isIgnore(target:Object):Boolean
		{
			return (kernel.managerAvailable && target is DisplayObject) ? kernel.manager.is_ignoreObject(target) : false;
		}
		
		
		public static function setNodeCached(mc:MovieClip, useCache:Boolean):void
		{
			if (kernel.managerAvailable) kernel.manager.setCacheEnabled(mc, useCache);
		}

		public static function gpuClear():void
		{
			if (kernel.managerAvailable) kernel.manager.clearGPU();
		}
		public static function get starlingRoot():Sprite{
			return FSE_Kernel.starlingRoot;
		}
		public static function get starlingRootBack():Sprite{
			return FSE_Kernel.starlingRootBack;
		}
		// ------------------------------------------------
		// 事件与核心逻辑监听
		// ------------------------------------------------
		
		public static function loop(listener:Function):void{
			if(kernel.stage){
				addLoop(kernel.stage,listener);
			}else{
				trace("错误：请在添加循环之前初始化FSE框架");
			}
		}
		public static function stopLoop(listener:Function):void{
			if(kernel.stage){
				removeLoop(kernel.stage,listener);
			}else{
				trace("错误：请在卸载循环之前初始化FSE框架");
			}
		}
		public static function addLoop(scope:Object,listener:Function):void{
			addEventListener(scope,FSE_Event.FIX_ENTER_FRAME, listener);
		}
		
		public static function removeLoop(scope:Object,listener:Function):void{
			removeEventListener(scope,FSE_Event.FIX_ENTER_FRAME, listener);
		}
		
		public static function addEventListener(scope:Object,EventType:String, listener:Function):void
		{
			if (EventType == FSE_Event.FIX_ENTER_FRAME)
			{
				if (kernel.managerAvailable)
					kernel.manager.addLogicListener(scope, listener);
				else
					scope.addEventListener(Event.ENTER_FRAME, listener);
			}
		}

		public static function removeEventListener(scope:Object, EventType:String, listener:Function):void
		{
			if (EventType == FSE_Event.FIX_ENTER_FRAME)
			{
				if (kernel.managerAvailable)
					kernel.manager.removeLogicListener(scope, listener);
				else
					scope.removeEventListener(Event.ENTER_FRAME, listener);
			}
		}

		// ------------------------------------------------
		// 杂项
		// ------------------------------------------------

		public static function setKeyRole(mc:MovieClip):void
		{
			FSE_Manager.keyRole = mc ? mc.name : '';
		}

		public static function noKeyRole():void
		{
			FSE_Manager.keyRole = '';
		}
		
		public static function get keyRole():String
		{
			return FSE_Manager.keyRole;
		}
		
		public static function get gameRoot():DisplayObjectContainer
		{
			return kernel.gameRoot;
		}
		
		// 私有捷径
		private static function get kernel():FSE_Kernel
		{
			return FSE_Kernel.instance;
		}
	}
}