package fse.starling
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.display.StageDisplayState;
	import flash.display.DisplayObjectContainer;
	import flash.utils.setTimeout;
	
	import starling.core.Starling;
	import starling.display.Sprite;
	import starling.events.*;
	
	import fse.conf.*;
	import fse.core.FSE;
	import fse.core.FSE_Kernel;
	
	public class StarlingMain extends flash.display.Sprite
	{
		private var _starling: Starling;
		private var _gameRoot;
		private var _starlingUserRootBack:starling.display.Sprite;
		private var _starlingUserRootFront:starling.display.Sprite;
		private var _stageOriginWidth;
		private var _stageOriginHeight;
		private var _viewK:Number = 1;
		public function StarlingMain(gameRoot:DisplayObjectContainer)
		{
			_gameRoot=gameRoot;
			if (stage)
			{
				init();
			}
			else
			{
				addEventListener(flash.events.Event.ADDED_TO_STAGE, init);
			}
		}
	
	
		private function init(e:flash.events.Event = null): void
		{
			removeEventListener(flash.events.Event.ADDED_TO_STAGE, init);
			//stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
			stage.color = Config.BG_COLOR;
			stage.frameRate = Config.EXT_FPS;
			
			if(Config.TRACE_CORE)trace("Trying start starling....");
			_starling = new Starling(StarlingVO, stage);
			_starling.addEventListener(starling.events.Event.ROOT_CREATED, onRootCreated);
			_starling.showStats = Config.TRACE_DEBUG;
			_starling.start();
			
		}

		private function onRootCreated(event: starling.events.Event, root: StarlingVO)
		{
			//开始;
			Starling.current.nativeStage.frameRate = Config.EXT_FPS; //二次确认
			
			_stageOriginWidth = stage.stageWidth;
			_stageOriginHeight = stage.stageHeight;
			
			_viewK=stage.stageHeight/stage.stageWidth;
			windowResize(); //窗口自适应
			_starling.stage.addEventListener(starling.events.Event.RESIZE, onWindowResize);
			
			_starling.stop(true); 
            if(Config.TRACE_CORE)trace('Starling舞台启动完成! 等待驱动激活...');
			
			
			var userZoomBack:starling.display.Sprite = new starling.display.Sprite();
			root.addChild(userZoomBack);
			_starlingUserRootBack=userZoomBack;
			
			var userZoomFront:starling.display.Sprite = new starling.display.Sprite();
			root.addChild(userZoomFront);
			_starlingUserRootFront=userZoomFront;
			
			kernel.onStarlingReady(root,_starlingUserRootFront,_starlingUserRootBack);
		}
		
		/**
         * [新增] 手动渲染一帧
         * 由 FSE 主循环调用
         */
        public function renderNow():void
        {
            if (_starling)
            {
                _starling.nextFrame(); // 这包含了 update() 和 render()
            }
        }
		private function onWindowResize(e:ResizeEvent):void
		{
			windowResize();
		}
		
		private function windowResize():void
		{
			var now_viewK_height:Number =  stage.stageHeight/_stageOriginHeight;
			var now_viewK_width:Number =  stage.stageWidth/_stageOriginWidth;
			var dt:Number;
			
			//核心自适应代码
			var auto_mode:String = Config.AUTO_ADAPT;
			var alignX:String = "CENTER";
			var alignY:String = "CENTER";
			if(Config.ALIGN_X == "LEFT" || Config.ALIGN_X == "RIGHT"){
				alignX=Config.ALIGN_X;
			}
			if(Config.ALIGN_Y == "TOP" || Config.ALIGN_Y == "BOTTOM"){
				alignY=Config.ALIGN_Y;
			}
			if(auto_mode == "FULL"){
				_gameRoot.scaleX = stage.stageWidth / _stageOriginWidth;
				_gameRoot.scaleY = stage.stageHeight / _stageOriginHeight;
			}
			if(auto_mode == "AUTO"){
				if(_stageOriginHeight/_stageOriginWidth>stage.stageHeight/stage.stageWidth){
					auto_mode = "SYN_HEIGHT";
				}else{
					auto_mode = "SYN_WIDTH";
				}
			}
			if(auto_mode == "SYN_HEIGHT"){
				//LEFT
				dt=0;
				if(alignX == "CENTER"){
					dt = stage.stageWidth/2-_stageOriginWidth/2*now_viewK_height;
				}
				if(alignX == "RIGHT"){
					dt = stage.stageWidth -_stageOriginWidth*now_viewK_height;
				}
				_gameRoot.scaleY = stage.stageHeight / _stageOriginHeight;
				_gameRoot.scaleX=_gameRoot.scaleY;
				
				_gameRoot.x=dt;
				_gameRoot.y=0;
			}
			if(auto_mode == "SYN_WIDTH"){
				//UP
				dt=0;
				if(alignY == "CENTER"){
					dt = stage.stageHeight/2-_stageOriginHeight/2*now_viewK_width;
				}
				if(alignY == "BOTTOM"){
					dt = stage.stageHeight - _stageOriginHeight*now_viewK_width;
				}
				_gameRoot.scaleX = stage.stageWidth / _stageOriginWidth;
				_gameRoot.scaleY=_gameRoot.scaleX;
				_gameRoot.x=0;
				_gameRoot.y=dt;
			}
			
			
			if(_starlingUserRootBack) {
				_starlingUserRootBack.x = _gameRoot.x;
				_starlingUserRootBack.y = _gameRoot.y;
				_starlingUserRootBack.scaleX = _gameRoot.scaleX;
				_starlingUserRootBack.scaleY = _gameRoot.scaleY;
				
				_starlingUserRootFront.x = _gameRoot.x;
				_starlingUserRootFront.y = _gameRoot.y;
				_starlingUserRootFront.scaleX = _gameRoot.scaleX;
				_starlingUserRootFront.scaleY = _gameRoot.scaleY;
			}
			
			//无论如何starling的逻辑舞台总是和stage舞台同步
			_starling.stage.stageWidth = stage.stageWidth;
			_starling.stage.stageHeight = stage.stageHeight;
			//无论如何 starling渲染窗口总是填满视窗
			_starling.viewPort.width = stage.stageWidth;
			_starling.viewPort.height = stage.stageHeight;
			
			//这三者变量是独立的
			if(Config.TRACE_CORE)trace("游戏场景大小", _starling.stage.stageWidth, _starling.stage.stageHeight);
			if(Config.TRACE_CORE)trace("播放器窗口大小", stage.stageWidth, stage.stageHeight);
			if(Config.TRACE_CORE)trace("相较于播放器窗口中的视窗大小", _starling.viewPort.width, _starling.viewPort.height);
		}
	
		// 私有捷径
		private static function get kernel():FSE_Kernel
		{
			return FSE_Kernel.instance;
		}
		
		public function dispose()
		{
			_starling.stop(true);
			setTimeout(shifang, 500);
			function shifang()
			{
				_starling.dispose();
				if(Config.TRACE_CORE)trace('Stage disposed!');
			}
		}

	}
}