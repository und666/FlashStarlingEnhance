package fse.starling
{
	import flash.utils.Dictionary;
	import flash.display.DisplayObjectContainer;
	import flash.utils.setTimeout;
	import flash.filters.BitmapFilter;
	import flash.filters.GlowFilter; // 消除歧义，这是Flash原本的
	import flash.filters.BlurFilter;
	import flash.filters.DropShadowFilter;
	import flash.utils.getQualifiedClassName;

	import fse.core.FSE_Manager;

	import fse.display.Node;
	import fse.core.FSE_Kernel;
	import fse.cache.CacheManager;
	import fse.conf.*;
	
    import starling.display.Sprite;
    import starling.display.Image;
    import starling.display.DisplayObject;
    import starling.display.DisplayObjectContainer;
    import starling.textures.Texture;
	import starling.events.Event;
    import starling.core.Starling;
	// [新增] 引入 Starling 滤镜
	import starling.filters.FragmentFilter;
	import starling.filters.BlurFilter;
	import starling.filters.GlowFilter;
	import starling.filters.DropShadowFilter;
	import starling.filters.FilterChain; // 如果有多个滤镜需要串联
	

    public class StarlingManager
    {
        private var _rootLayer:Sprite;
		private var _starlingUserRootFront:Sprite;
		private var _starlingUserRootBack:Sprite;
		private var _viewKeyMap:Dictionary;
		
		// [新增] 存储视图对象的逻辑层级值 (View -> int)
        private var _viewZIndexMap:Dictionary; 
        // [新增] 脏容器列表，记录哪些父容器需要重排 (Container -> boolean)
        private var _dirtyContainers:Dictionary;
		
		// [新增] 就绪标记
		private var _isReady:Boolean = false;
		// [新增] 等待队列：存储那些在 Starling 初始化完成前就创建了的 Node
		private var _pendingNodes:Vector.<Node>;
		
        public function StarlingManager()
        {
			
			// [新增] 初始化排序相关字典
            _viewZIndexMap = new Dictionary(true);
            _dirtyContainers = new Dictionary(true);
			
            // 注入工厂方法，当 Node 初始化时会调用此方法创建对应的 Starling 对象
			_viewKeyMap = new Dictionary(true); // 弱引用 Key
			_pendingNodes = new Vector.<Node>();
			
            Node.onCreateRenderer = createViewForNode;
        }
		
		/**
		 * [新增] 激活 Starling (当 StarlingMain 初始化完成后调用)
		 */
		public function activate(rootLayer:Sprite,rootStarlingUserLayerFront:Sprite,rootStarlingUserLayerBack:Sprite):void
		{
			if(Config.TRACE_CORE)trace("[StarlingManager] 🚀 渲染层激活，开始处理积压任务...");
			_rootLayer = rootLayer;
			_starlingUserRootFront = rootStarlingUserLayerFront;
			setDepth(_starlingUserRootFront,-99999,false);
			_starlingUserRootBack = rootStarlingUserLayerBack;
			setDepth(_starlingUserRootBack,99999,false);
			_isReady = true;
			
			// [新增] 监听 Starling 的 EnterFrame 或 Render 事件，在渲染前统一排序
            // 注意：这里挂载到 rootLayer 所在的 stage 或者 starling 实例上
            if (Starling.current) {
                Starling.current.stage.addEventListener(Event.ENTER_FRAME, onFrameLoop);
            }
			
			// 处理所有积压的 Node
			// 因为 Watcher 是从父到子扫描的，所以队列里的顺序也是父->子，直接遍历创建是安全的
			for each (var node:Node in _pendingNodes)
			{
				// 再次检查节点是否还存活（防止等待期间已经被销毁了）
				if (node.source) 
				{
					createViewForNode(node);
				}
			}
			
			// 清空队列，释放内存
			_pendingNodes = null;
		}
		
		/**
         * [新增] 帧循环：每一帧渲染前，处理所有等待排序的容器
         */
        private function onFrameLoop(e:Event):void
        {
            processSorting();
        }
	
		/**
         * [核心优化] 批量处理排序
         * 遍历所有被标记为“脏”的容器，对其子对象进行一次性排序
         */
        private function processSorting():void
        {
            var hasDirty:Boolean = false;
            
            for (var key:Object in _dirtyContainers)
            {
                var container:starling.display.DisplayObjectContainer = key as starling.display.DisplayObjectContainer;
				
                // 确保容器还存在且未被销毁
                if (container && container.numChildren > 1) 
                {
                    // 调用 Starling 的 sortChildren，传入我们的自定义比较函数
                    container.sortChildren(compareZIndex);
                }
                
                // 处理完后移除标记
                delete _dirtyContainers[key];
            }
        }
		
		/**
         * [排序算法] 比较函数
         * A 和 B 谁大谁就在上面 (Index 越大越靠后绘制)
         */
        private function compareZIndex(a:DisplayObject, b:DisplayObject):int
        {
            var zA:int = _viewZIndexMap[a]; // 默认为 0 (如果字典里没有)
            var zB:int = _viewZIndexMap[b];
            
            if (zA > zB) return 1;
            if (zA < zB) return -1;
            return 0; // 相等则保持原顺序
        }
	
	
	
        /**
         * [工厂模式] 创建 Starling 视图并绑定到 Node
         */
        private function createViewForNode(node:Node):void
        {
			// [关键逻辑] 如果 Starling 还没好，先加入等待队列，然后直接返回
			//node.enableCache=false;
			if (!_isReady)
			{
				_pendingNodes.push(node);
				return;
			}
            var view:DisplayObject;
			//MD5.getMD5(Hash.getHashFromDisplayObject(a))
			
            // 1. 创建视图对象
            if (node.bitmapData)
            {
                // 是叶子节点 (Shape/Bitmap/TextField) -> 创建 Image
                // 此时 bitmapData 应该已经在 Node 构造函数里生成好了
                var tex:Texture;
				
                // [逻辑分支]
                if (node.enableCache)
                {
                    // 1. 正常流程：走缓存管理器
                    var result:Object = CacheManager.instance.getTexture(node.bitmapData);
                    tex = result.texture;
                    
                    // 绑定到 Image
                    var img:Image = new Image(tex);
                    view = img;
                    
                    // [记录] 这是一个缓存纹理，记录它的 Key
                    _viewKeyMap[view] = result.key;
                }
                else
                {
                    // 2. 特例流程：强制新建，不入库
                    if(Config.TRACE_CACHE)trace("[StarlingManager] ⚠️ 特例对象，跳过缓存: " + node.getName());
                    tex = Texture.fromBitmapData(node.bitmapData, false);
                    view = new Image(tex);
                    // 显式不记录 Key (或者 delete)，表示这是私有纹理
                    delete _viewKeyMap[view];
                }
				(view as Image).pivotX = node.pivotX;
				(view as Image).pivotY = node.pivotY;
				
				(view as Image).textureSmoothing = Config.TEXTURE_SMOOTHING;
            }
            else
            {
                // 是容器节点 (MovieClip/Sprite) -> 创建 Sprite
                view = new Sprite();
            }
		
            // 2. 双向绑定
            node.renderer = view;        // 让 Node 持有 Starling 对象 (用于 dispose)
            node.onUpdate = onNodeUpdate; // 让 Node 能回调 Manager (用于 sync)
            node.onDisposeRenderer = onNodeDisposeRenderer;// 让Node 能回调清理函数
			
			// 初始化 Z-Index (默认为 0 或者 node 当前的 index)
            _viewZIndexMap[view] = node.childIndex;
            // 3. 初始属性同步 (确保刚创建出来位置就是对的)
            syncTransform(node, view);
			syncFilters(node, view);
            // 4. 构建层级树 (挂载到父节点)
            if (node.parentNode && node.parentNode.renderer)
            {
                var parentView:Sprite = node.parentNode.renderer as Sprite;
                parentView.addChild(view);
				// [新增] 新加入子对象，标记父容器需要排序
                markParentDirty(parentView);
            }
            else
            {
                // 没有父节点，说明是根对象，直接上舞台
                _rootLayer.addChild(view);
				// 根容器也可能需要排序
                markParentDirty(_rootLayer);
            }
        }
	
		// 新增清理函数
		private function onNodeDisposeRenderer(node:Node):void
		{
			var view:DisplayObject = node.renderer as DisplayObject;
			// [新增] 清理排序数据
            if (view) {
                delete _viewZIndexMap[view];
                // 如果父容器还在，可能需要移除标记(或不处理，Starling会自动移除child)
            }
			if (view && _viewKeyMap[view])
			{
				var key:String = _viewKeyMap[view];
				setTimeout(delTex,1000,node.getName(),key);
				delete _viewKeyMap[view];
				
			}
		}
		private function delTex(nodeName:String,key:String){
			CacheManager.instance.releaseTexture(key);
			if(Config.TRACE_NODE)trace("[StarlingManager] ♻️ 节点"+nodeName+"销毁，归还引用: " + key.substr(0,6));
		}
        /**
         * [核心回调] 响应 Node 的属性变化
         * @param node 发起更新的节点
         * @param type 更新类型字符串 (Node.UPDATE_PROP 等)
         */
        private function onNodeUpdate(node:Node, type:String):void
        {
            var view:DisplayObject = node.renderer as DisplayObject;
            if (!view) return;

            // 根据你的 Node.as 定义的字符串常量进行判断
            if (type == Node.UPDATE_PROP)
            {
                syncTransform(node, view);
            }
            else if (type == Node.UPDATE_TEXTURE)
            {
                syncTexture(node, view);
            }
            else if (type == Node.UPDATE_HIERARCHY)
            {
                syncDepth(node, view);
            }
			else if (type == Node.UPDATE_FILTER)
			{
				syncFilters(node, view);
			}
        }
		
		/**
		 * [新增] 同步滤镜
		 * 策略：将 Flash 滤镜映射为 Starling 滤镜，遇到不支持的输出警告
		 */
		private static const BLUR_SCALE:Number = 0.18;
		private function syncFilters(node:Node, view:DisplayObject):void
		{
			if (!node.source) return;
			
			var flashFilters:Array = node.source.filters;
			
			// 1. 如果 Flash 端没有滤镜，清理 Starling 滤镜
			if (!flashFilters || flashFilters.length == 0)
			{
				if (view.filter) {
					view.filter.dispose();
					view.filter = null;
				}
				return;
			}
			
			// 2. 构建 Starling 滤镜列表
			var starlingFilters:Vector.<FragmentFilter> = new Vector.<FragmentFilter>();
			
			for each (var f:Object in flashFilters)
			{
				var sFilter:FragmentFilter = null;
				var isInner:Boolean = false;
				var isKnockout:Boolean = false;
				
				// --- 模糊滤镜 ---
				if (f is flash.filters.BlurFilter)
				{
					var bf:flash.filters.BlurFilter = f as flash.filters.BlurFilter;
					sFilter = new starling.filters.BlurFilter(bf.blurX*BLUR_SCALE, bf.blurY*BLUR_SCALE);
				}
				// --- 发光滤镜 ---
				else if (f is flash.filters.GlowFilter)
				{
					var gf:flash.filters.GlowFilter = f as flash.filters.GlowFilter;
					isInner = gf.inner;
					isKnockout = gf.knockout;
					// Starling Glow: color, alpha, blur, strength
					sFilter = new starling.filters.GlowFilter(gf.color, gf.alpha, gf.blurX*BLUR_SCALE, gf.strength);
				}
				// --- 投影滤镜 ---
				else if (f is flash.filters.DropShadowFilter)
				{
					var df:flash.filters.DropShadowFilter = f as flash.filters.DropShadowFilter;
					isInner = df.inner;
					isKnockout = df.knockout;
					// Starling DropShadow: distance, angle, color, alpha, blur, strength
					sFilter = new starling.filters.DropShadowFilter(df.distance, deg2rad(df.angle), df.color, df.alpha, df.blurX, df.strength);
				}
				// --- 其他复杂滤镜 ---
				else
				{
					if(Config.TRACE_CORE) trace("[FSE Warning] ⚠️ 忽略不支持的 GPU 滤镜: " + flash.utils.getQualifiedClassName(f));
				}
				
				// --- 应用通用参数 ---
				if (sFilter)
				{
					// [处理 Inner] Starling 原生不支持内发光，降级为外发光并警告
					if (isInner)
					{
						if(Config.TRACE_CORE) trace("[FSE Warning] ⚠️ Starling 不支持内发光(Inner)，已降级为外发光: " + node.getName());
					}
					
					// [处理 Knockout] 对应 Starling 的 REPLACE 模式 (即挖空)
					if (isKnockout)
					{
						// FragmentFilterMode.REPLACE = 替换原图
						// FragmentFilterMode.BELOW = 下方绘制 (默认)
						// 只要是继承自 FragmentFilter 的标准滤镜都有 mode 属性
						try {
							sFilter["mode"] = "replace";
						} catch(e:Error) {
							// 防止个别自定义滤镜没有 mode 属性报错
						}
					}
					
					starlingFilters.push(sFilter);
				}
			}
			
			// 3. 应用到 Starling 对象
			if (starlingFilters.length > 0)
			{
				// 清理旧滤镜引用
				if (view.filter) view.filter.dispose();
				
				if (starlingFilters.length == 1)
				{
					// 单滤镜直接赋值
					view.filter = starlingFilters[0];
				}
				else
				{
					// [修复] 多滤镜使用 FilterChain，必须手动 addFilter
					var chain:FilterChain = new FilterChain();
					for (var i:int = 0; i < starlingFilters.length; i++)
					{
						chain.addFilter(starlingFilters[i]);
					}
					view.filter = chain;
				}
			}
			else
			{
				// 全是无效滤镜，清理
				if (view.filter) {
					view.filter.dispose();
					view.filter = null;
				}
			}
		}
		
        /**
         * 同步基础变换属性 (x, y, scale, rotation, alpha, visible)
         */
        private function syncTransform(node:Node, view:DisplayObject):void
        {
            // 直接从 Flash 源对象读取最新值
            // 如果担心线程问题，也可以读取 node._lastX 等私有变量(需改为public)
			if(!node.source)return;
			view.x = node.source.x;
            view.y = node.source.y;
            view.rotation = deg2rad(node.source.rotation);
            view.alpha = node.source.alpha;
			if(node.source is flash.display.DisplayObjectContainer){
				view.scaleX = node.source.scaleX;
				view.scaleY = node.source.scaleY;
			}else{
				view.width = node.source.width;
				view.height = node.source.height;
			}
            // 使用 Node 的逻辑可见性 (由 Controller 控制)
		
            view.visible = node.getLogicalVisible();
			if(FSE_Manager.keyRole == node.source.name){
				kernel.starlingHelpDraw();
			}
        }
        
        /**
         * 同步纹理 (用于 TextField 变化或 Shape 重绘)
         */
        private function syncTexture(node:Node, view:DisplayObject):void
        {
            var img:Image = view as Image;
            // 只有 Image 且 Node 有新位图数据时才更新
            if (!img || !node.bitmapData) return;
            
			// --- 1. 释放旧纹理 ---
            var oldKey:String = _viewKeyMap[img];
            if (oldKey)
            {
                // 如果旧纹理是来自缓存的 -> 归还引用计数
                CacheManager.instance.releaseTexture(oldKey);
                delete _viewKeyMap[img];
            }
            else
            {
                // 如果旧纹理不是缓存的 (是特例) -> 直接物理销毁
                if (img.texture) img.texture.dispose();
            }
			
            // --- 2. 获取新纹理 ---
            var newTex:Texture;
            if (node.enableCache)
            {
                // 走缓存
                var result:Object = CacheManager.instance.getTexture(node.bitmapData);
                newTex = result.texture;
                _viewKeyMap[img] = result.key; // 记录新 Key
            }
            else
            {
                // 不走缓存
                newTex = Texture.fromBitmapData(node.bitmapData, false);
                // 确保 Map 里没有 Key
                delete _viewKeyMap[img];
            }
            
            // 3. 应用
			img.texture = newTex;
			img.textureSmoothing = Config.TEXTURE_SMOOTHING;
            img.readjustSize(); 
            img.pivotX = node.pivotX;
            img.pivotY = node.pivotY;
			
			if(FSE_Manager.keyRole == node.source.name){
				kernel.starlingHelpDraw();
			}
        }
        
        /**
         * 同步层级 (ChildIndex)
         */
        private function syncDepth(node:Node, view:starling.display.DisplayObject):void
        {
			setDepth(view,node.childIndex);
        }
		
		/**
		 * 设置层级 (ChildIndex)
		 */
		private function setDepth(view:starling.display.DisplayObject,key:int,flush:Boolean = true):void
		{
			// 1. 更新字典里的 Z-Index
			// node.childIndex 这里被当作一个排序权重值 (int)，可以是 0, 1, 100, -5 等
			_viewZIndexMap[view] = key;
			
			// 2. 标记父容器为 "脏" (需要排序)
			if (flush && view.parent)
			{
				markParentDirty(view.parent as starling.display.DisplayObjectContainer);
			}
		}
		/**
         * 辅助：标记容器需要重排
         */
        private function markParentDirty(container:starling.display.DisplayObjectContainer):void
        {
            // 使用 Dictionary 自动去重
            _dirtyContainers[container] = true;
        }
	
		// 私有捷径
		private static function get kernel():FSE_Kernel
		{
			return FSE_Kernel.instance;
		}
	
		private function deg2rad(deg:Number):Number
		{
			return deg / 180.0 * Math.PI;   
		}
    }
}