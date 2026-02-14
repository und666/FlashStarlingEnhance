package fse.core
{
	import flash.display.Stage;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.utils.getTimer;
	import flash.display.StageDisplayState;
	
	import fse.conf.Config;
	import fse.starling.StarlingMain;
	import starling.display.Sprite;

	/**
	 * FSE 核心引擎 (内部单例)
	 * 职责：持有状态、驱动主循环、处理底层回调
	 * 用户不应直接访问此类
	 */
	public class FSE_Kernel
	{
		private static var _instance:FSE_Kernel;
		
		public var manager:FSE_Manager;
		public var stage:Stage;
		public var gameRoot:DisplayObjectContainer;
		public var starlingMain:StarlingMain;
		
		// 核心状态
		private var _isRunning:Boolean = false;
		private var _lastTime:int = 0;
		private var _accumulator:Number = 0;
		private var _selfRender:Boolean = true; // 是否自动渲染下一帧
		private static var _starlingRoot:Sprite;
		private static var _starlingRootBack:Sprite;
		
		public static function get instance():FSE_Kernel
		{
			if (!_instance) _instance = new FSE_Kernel();
			return _instance;
		}
	
		public static function get starlingRoot():Sprite
		{
			//这里_starlingRoot 就是 _starlingRootFront
			if(!_starlingRoot)trace("错误，starling还没有完成初始化");
			return _starlingRoot;
		}
		
		public static function get starlingRootBack():Sprite
		{
			if(!_starlingRootBack)trace("错误，starling还没有完成初始化");
			return _starlingRootBack;
		}
		
	
		public function FSE_Kernel()
		{
			if (_instance) throw new Error("FSE_Kernel is Singleton");
		}

		/**
		 * 核心初始化逻辑 (从 FSE 移入)
		 */
		public function init(stageRef:Stage, rootRef:DisplayObjectContainer, takeOver:Boolean):void
		{
			if (this.stage) return; // 防止重复

			if (!takeOver)
			{
				if (Config.TRACE_CORE) trace("[FSE] 仅提升帧率,不进行监控树GPU渲染！");
				FSE_Manager.noGPU = true;
			}
			
			this.stage = stageRef;
			this.gameRoot = rootRef;
			FSE_Input.init(stageRef);
		
			if (Config.FULL_SCREEN)
			{
				this.stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
			}
			this.stage.showDefaultContextMenu = false;

			// 创建管理器
			this.manager = new FSE_Manager(stage, gameRoot);
			
			if (gameRoot is MovieClip && FSE_Manager.controller)
			{
				FSE_Manager.controller.register(gameRoot as MovieClip);
			}

			// 启动 Starling
			starlingMain = new StarlingMain(gameRoot);
			stage.addChild(starlingMain);
			manager.ignoreObject(starlingMain);

			// 启动心跳
			_lastTime = getTimer();
			_isRunning = true;
			stage.addEventListener(Event.ENTER_FRAME, onDriverUpdate);

			if (Config.TRACE_CORE) trace("[FSE] 核心逻辑已启动，等待渲染层就绪...");
		}

		/**
		 * 接收 Starling 准备就绪的回调
		 * (原来 FSE.onStarlingReady 的逻辑)
		 */
		public function onStarlingReady(rootStarlingLayer:Sprite,rootStarlingUserLayerFront:Sprite,rootStarlingUserLayerBack:Sprite):void
		{
			if (FSE_Manager.noGPU) return;
			if (Config.TRACE_CORE) trace("[FSE] Starling Context Ready! Linking Manager...");
			
			if (manager)
			{
				manager.activateStarling(rootStarlingLayer,rootStarlingUserLayerFront,rootStarlingUserLayerBack);
			}
			_starlingRoot=rootStarlingUserLayerFront;
			_starlingRootBack=rootStarlingUserLayerBack;
		}
		
		/**
		 * 核心驱动循环 (从 FSE 移入)
		 */
		private function onDriverUpdate(e:Event):void
		{
			if (!_isRunning) return;

			// 1. 渲染
			performStarlingDraw();

			// 2. 时间步计算
			var currentTime:int = getTimer();
			var deltaTime:int = currentTime - _lastTime;
			_lastTime = currentTime;
			_accumulator += deltaTime;

			if (_accumulator > Config.maxAccumulator)
			{
				_accumulator = Config.maxAccumulator;
			}

			// 3. 逻辑更新 (稳定 60 FPS)
			while (_accumulator >= Config.logicTimestep)
			{
				manager.executeLogicStep();
				_accumulator -= Config.logicTimestep;
			}
			
			// 4. 树结构扫描 (超高频)
			manager.Update();
		}

		private function performStarlingDraw():void
		{
			if (_selfRender && starlingMain)
			{
				starlingMain.renderNow();
			}
			else
			{
				_selfRender = true; // 重置标记
			}
		}

		/**
		 * 辅助渲染 (内部调用)
		 */
		public function starlingHelpDraw():void
		{
			performStarlingDraw();
			_selfRender = false;
		}

		// --- 简单的 Getters/Setters ---
	
		

		public function get managerAvailable():Boolean { return manager != null; }
	}
}