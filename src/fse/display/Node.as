package fse.display
{
import flash.display.BitmapData;
import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import flash.display.MovieClip;
import flash.filters.*;
import flash.geom.Matrix;
import flash.geom.Rectangle;
import flash.text.TextField;
import flash.utils.getQualifiedClassName;

import fse.conf.*;
import fse.core.FSE;
import fse.core.FSE_Manager;
import fse.utils.FSEProfiler;
import fse.utils.Hash;

/**
	 * 场景树节点 (Shadow Node) - 简化版
	 * 策略：
	 * 1. 容器节点 (MovieClip/Sprite): 仅负责结构和属性同步，不生成 BitmapData。
	 * 2. 叶子节点 (Shape/Bitmap): 负责生成 BitmapData，是实际的渲染内容。
	 */
	public class Node
	{
		
		public var source:DisplayObject;
		public var children:Vector.<Node>;
		
		// 只有叶子节点(Shape)会有这个数据，容器节点为null
		public var bitmapData:BitmapData;
		public var pivotX:Number = 0;
		public var pivotY:Number = 0;
		
		// ------ 上一帧的状态缓存 ------
		
		private var _lastX:Number;
		private var _lastY:Number;
		private var _lastScaleX:Number;
		private var _lastScaleY:Number;
		private var _lastRotation:Number;
		private var _lastAlpha:Number;
		private var _lastFrame:int = -1;
		// [新增] 当前的层级索引 (Visual Index)
		public var childIndex:int = -1;
		private var _lastChildIndex:int = -1; // 用于比对
		// [新增] 记录文本内容
		private var _lastText:String = null;
		// [新增] 记录可见性
		private var _lastVisible:Boolean;
		// [新增] 用于 O(1) 极速对比子节点数量，防止休眠时漏掉子节点增删
		public var lastNumChildren:int = -1;
		
		//位图哈希
		private var hash:String;
		
		private var nodeEnabled:Boolean = true;
		
		//回调
		private var _onDisposeArgs:Function;
		public var onDisposeRenderer:Function;
		
		
		// 定义操作类型常量
        public static const UPDATE_PROP:String = "prop";   // 属性变化(x,y,alpha...) 这一项将被分解
		public static const UPDATE_PROP_POS:String = "position";   // 属性变化(x,y)
		public static const UPDATE_PROP_SCALE:String = "scale";   // 属性变化(scale)
		public static const UPDATE_PROP_ROTA:String = "rotation";   // 属性变化(rotation)
		public static const UPDATE_PROP_ALPHA:String = "alpha";   // 属性变化(alpha)
		public static const UPDATE_PROP_VISIBLE:String = "visible";   // 属性变化(alpha)
		
        public static const UPDATE_TEXTURE:String = "texture"; // 纹理内容变化(重绘)
        public static const UPDATE_HIERARCHY:String = "hierarchy"; // 层级/父子关系变化
		public static const UPDATE_FILTER:String = "filter"; //滤镜更新常量
		private var _lastFilters:Array = null; // 上一次的滤镜签名
		
		// [新增] 持有 Starling 层的对应显示对象
        // 使用 Object 类型以避免在 fse.display 包中引入 starling 包造成强耦合
        public var renderer:Object;
		
        // [新增] 钩子函数：当 Node 初始化完成需要创建视图时调用
        public static var onCreateRenderer:Function;
		
		// [新增] 渲染层回调，由 StarlingManager 注入
        // 签名: function(node:Node, type:String):void
        public var onUpdate:Function;
		
		public var parentNode:Node;
		
		public var _coldTime:int=0;
		public var _coldTimeMax:int=0;
		
		// [新增] 缓存开关：默认为 true (参与 Hash 缓存)
        // 如果设为 false，则每次都会生成全新的 Texture，且不通过 CacheManager 管理
        public var enableCache:Boolean = true;
		
		public function Node(src:DisplayObject, parentNode:Node , disposeCallback:Function , enableCache:Boolean = true)
		{
			
			this.parentNode = parentNode;
			this.source = src;
			this.children = new Vector.<Node>();
			this._onDisposeArgs = disposeCallback;
			this.enableCache=enableCache;
			
			if(src){
				if(!StatusSaver.hasVisible(src)){
					//初始逻辑可见性配置
					//setLogicalVisible(src.visible);
					setLogicalVisible(true);
					setOriginVisible(src.visible);
				}
				
				if(src.parent){
					//初始层级索引配置
					childIndex=src.parent.getChildIndex(src);
					_lastChildIndex=childIndex;
					//if(!(src is DisplayObjectContainer) && FSE.isIgnore(parentNode.source)){
				}
			}
			
			// 1. 记录初始状态
			recordState();
			
			// 2. 尝试生成快照 (只有 Shape 等叶子节点才会真正生成)
			updateSnapshot();
			
			if(FSE_Manager.watcher.isIgnore(src)){
				nodeEnabled=false;
				//死节点
				return;
			}
			
			if (onCreateRenderer != null) {
				// 将自己传出去，工厂创建完 Starling 对象后赋值给 this.renderer
				onCreateRenderer(this);
			}
		}
		public function enable():Boolean{
			return nodeEnabled;
		}
		
		
		/**
		 * [新增] 设置逻辑可见性 (由 Watcher 调用)
		 * 这使得 Node 知道 Controller 希望它显示还是隐藏
		 */
		
		public function restoreVisible():void{
			if(source){
				source.visible = getOriginVisible();
				trace(source.name)
			}
			for(var i:uint=0;i<children.length;i++){
				children[i].restoreVisible();
			}
		}
		
		public function setLogicalVisible(v:Boolean):void
		{
			if(source)StatusSaver.setLogicalVisible(source,v);
		}
	
		public function getLogicalVisible():Boolean
		{
			if(source)return StatusSaver.getLogicalVisible(source);
			trace("获取visible错误");
			return true;
		}
		public function setOriginVisible(v:Boolean):void
		{
			if(source)StatusSaver.setOriginVisible(source,v);
		}
	
		public function getOriginVisible():Boolean
		{
			if(source){
				return StatusSaver.getOriginVisible(source);
			}
			trace("获取OriginVisible错误");
			return true;
		}
		/**
		 * [简化版] 生成纹理快照
		 * 规则：容器不画，只有叶子节点画
		 */
		public function updateSnapshot():void
		{
			
			if(!source)return;
			
			
			// 先清理旧纹理
			if (this.bitmapData) {
				this.bitmapData.dispose();
				this.bitmapData = null;
			}
			
			
			// [新规则] 如果是容器 (MovieClip, Sprite)，直接跳过
			// 它的"肉"存在于它的子 Shape 节点中，不由它自己负责渲染
			if(source is DisplayObjectContainer)return;
			if(FSE_Manager.watcher.isIgnore(source)){
				return;
			}
			
			// --- 下面只针对 Shape / Bitmap 等非容器对象 ---
		
			// [新增] 现场保护：记录原始可见性
			// 无论 Flash 里这个对象是否隐藏，我们为了截图必须临时让它"可见"
			// 这样能保证 getBounds 和 draw 100% 正常工作
			
			// 强制开启显示 (有些特殊情况 alpha=0 也画不出来，视需求而定，这里只处理 visible)
		
			//var vis_temp:Boolean = source.visible;
			//source.visible = true;
			
			var bounds:Rectangle = source.getBounds(source);
			// 检查是否有内容
			if (!FSE.noGPU && !FSE.isIgnore(source) && bounds.width >= 1 && bounds.height >= 1)
			{
				try {
					//热点代码---------------------------------------------------
					var w:int = Math.ceil(bounds.width);
					var h:int = Math.ceil(bounds.height);
					
					var bmd:BitmapData = new BitmapData(w, h, true, 0x00000000);
					var mat:Matrix = new Matrix();
					mat.translate(-bounds.x, -bounds.y);
					
					bmd.draw(source, mat);
					//----------------------------------------------------------
					this.pivotX = -bounds.x;
					this.pivotY = -bounds.y;
					
					var now_hash:String = Hash.getFastHash(bmd);
					
					if(hash != now_hash){
						hash = now_hash;
						//真正意义上的位图更新
						this.bitmapData = bmd;
						if(Config.TRACE_NODE)trace("[Node] 生成Shape纹理: " + getName());
						if(onUpdate != null)onUpdate(this,UPDATE_TEXTURE);
					}
				}
				catch (e:Error) {
					if(Config.TRACE_NODE)trace("[Error] 纹理生成失败: " + getName());
				}
			}
			//source.visible = vis_temp;
		}
		
		/**
		 * 检查属性是否发生变化
		 */
		
		
		public function checkDiff():Boolean
		{
			if (!source) return false;
			// 缓存引用查找
			if (FSE_Manager.watcher.isIgnore(source)) return false;
			
			var isChanged:Boolean = false;
			
			// --- 1. 基础变换属性 (合并判断，干掉 Array，干掉 width/height) ---
			// 只要有任何一个变换属性改变，直接派发一次 UPDATE_PROP 即可
			
			FSEProfiler.begin("Node_dif");
			FSEProfiler.begin("Node_dif_1");
			if (source.x != _lastX || source.y != _lastY){
				isChanged = true;
				if (onUpdate != null)onUpdate(this, UPDATE_PROP_POS);
			}
			if (source.scaleX != _lastScaleX || source.scaleY != _lastScaleY){
				isChanged = true;
				if (onUpdate != null)onUpdate(this, UPDATE_PROP_SCALE);
			}
			if (source.rotation != _lastRotation){
				isChanged = true;
				if (onUpdate != null)onUpdate(this, UPDATE_PROP_ROTA);
			}
			if (source.alpha != _lastAlpha){
				isChanged = true;
				if (onUpdate != null)onUpdate(this, UPDATE_PROP_ALPHA);
			}
			if (getLogicalVisible() != _lastVisible){
				isChanged = true;
				if (onUpdate != null)onUpdate(this, UPDATE_PROP_VISIBLE);
			}
			FSEProfiler.end("Node_dif_1");
			
			FSEProfiler.begin("Node_dif_2");
			// --- 2. 层级变化检查 ---
			if (source.parent) {
				if (_lastChildIndex == -1) {
					_lastChildIndex = childIndex;
				}
				if (childIndex != _lastChildIndex) {
					isChanged = true;
					if (onUpdate != null) onUpdate(this, UPDATE_HIERARCHY);
				}
			}
			
			// --- 3. 容器帧变化处理 ---
			if (source is MovieClip) {
				var mc:MovieClip = source as MovieClip;
				if (mc.currentFrame != _lastFrame) {
					updateFrame();
				}
			}
			
			
			// --- 4. 文本内容变化处理 ---
			if (source is TextField) {
				var tf:TextField = source as TextField;
				if (tf.text != _lastText) {
					isChanged = true;
					updateSnapshot();
				}
			}
			
			// --- 5. 滤镜变化检查 (由于读取 filters 会产生 GC，放到最后执行) ---
			// --- 5. 滤镜变化比对 ---
			var currentFilters:Array = source.filters;
			if (checkFiltersChanged(currentFilters)) {
				isChanged = true;
				if (onUpdate != null) onUpdate(this, UPDATE_FILTER);
			}
			
			// --- 6. 统一记录状态 ---
			if (isChanged) {
				_coldTimeMax = -2;
				// 原来的 recordState 会把当前属性直接赋值给 _lastX 等，非常高效
				recordState();
			}
			FSEProfiler.end("Node_dif_2");
			FSEProfiler.end("Node_dif");
			return isChanged;
		}
		
		/**
		 * [优化版] 检查滤镜是否发生变化 (零字符串拼接，零 GC)
		 */
		private function checkFiltersChanged(currentFilters:Array):Boolean
		{
			var noCurrent:Boolean = (!currentFilters || currentFilters.length == 0);
			var noLast:Boolean = (!this._lastFilters || this._lastFilters.length == 0);
			
			// 1. 数量或有无发生变化
			if (noCurrent && noLast) return false;
			if (noCurrent != noLast) return true;
			if (currentFilters.length != this._lastFilters.length) return true;
			
			// 2. 逐个比对具体属性
			var len:int = currentFilters.length;
			for (var i:int = 0; i < len; i++) {
				var f1:* = currentFilters[i];
				var f2:* = this._lastFilters[i];
				
				// 构造函数不同，说明换了滤镜类型 (比 getQualifiedClassName 快得多)
				if (f1.constructor !== f2.constructor) return true;
				
				if (f1 is GlowFilter) {
					if (f1.color != f2.color || f1.alpha != f2.alpha || f1.blurX != f2.blurX || f1.blurY != f2.blurY || f1.strength != f2.strength || f1.quality != f2.quality || f1.inner != f2.inner || f1.knockout != f2.knockout) return true;
				} else if (f1 is BlurFilter) {
					if (f1.blurX != f2.blurX || f1.blurY != f2.blurY || f1.quality != f2.quality) return true;
				} else if (f1 is DropShadowFilter) {
					if (f1.distance != f2.distance || f1.angle != f2.angle || f1.color != f2.color || f1.alpha != f2.alpha || f1.blurX != f2.blurX || f1.blurY != f2.blurY || f1.strength != f2.strength || f1.inner != f2.inner || f1.knockout != f2.knockout) return true;
				} else {
					// 对于不支持的特殊滤镜，为了安全起见默认视为已改变
					return true;
				}
			}
			
			return false;
		}
		
		//###############
		public function updateFrame():void
		{
			var mc:MovieClip = source as MovieClip;
			if (mc && mc.currentFrame != _lastFrame)
			{
				updateShapeChildren();
				_lastFrame = mc.currentFrame;
			}
		}
		
		private function updateShapeChildren():void
		{
			for (var i:int = children.length - 1; i >= 0; i--)
			{
				var childNode:Node = children[i];
				if (!(childNode.source is DisplayObjectContainer))
				{
					childNode.checkDiff();
					childNode.updateSnapshot();
				}
			}
		}
		
		/**
		 * 移除所有的 Shape/叶子 类型子节点
		 */
		private function removeShapeChildren():void
		{
			for (var i:int = children.length - 1; i >= 0; i--)
			{
				var childNode:Node = children[i];
				
				// 如果子节点不是容器（即它是 Shape/Bitmap 等内容节点）
				if (!(childNode.source is DisplayObjectContainer))
				{
					// trace("[Node] 帧清理: 移除旧 Shape 节点");
					childNode.dispose();
					children.splice(i, 1);
				}
			}
		}
	
		private function recordState():void
		{
			if(source){
				_lastX = source.x;
				_lastY = source.y;
				_lastScaleX = source.scaleX;
				_lastScaleY = source.scaleY;
				_lastRotation = source.rotation;
				_lastAlpha = source.alpha;
				_lastFilters = source.filters;
			}
			
			_lastVisible = getLogicalVisible();
			_lastChildIndex = childIndex;
			
			
			if (source is TextField)
			{
				_lastText = (source as TextField).text;
			}
			
			
			//if(Config.TRACE_NODE)trace("[Node] -> 对象: " + source.name, ' 属性刷新 ');
		}
		
		
		/**
		 * [新增] 生成滤镜签名字符串
		 * 格式示例: "Glow_0xFF0000_1_10_10|Blur_5_5|"
		 */
		private function getFilterSignature(filters:Array):String
		{
			if (!filters || filters.length == 0) return "";
			
			var sig:String = "";
			var len:int = filters.length;
			
			for (var i:int = 0; i < len; i++) {
				var f:* = filters[i];
				// 仅针对支持的滤镜生成详细签名，其他滤镜只记录类名
				if (f is GlowFilter) {
					sig += "Glow_" + f.color + "_" + f.alpha + "_" + f.blurX + "_" + f.blurY + "_" + f.strength + "_" + f.quality + "_" + f.inner + "_" + f.knockout + "|";
				} else if (f is BlurFilter) {
					sig += "Blur_" + f.blurX + "_" + f.blurY + "_" + f.quality + "|";
				} else if (f is DropShadowFilter) {
					sig += "Drop_" + f.distance + "_" + f.angle + "_" + f.color + "_" + f.alpha + "_" + f.blurX + "_" + f.blurY + "_" + f.strength + "_" + f.inner + "_" + f.knockout + "|";
				} else {
					// 对于不支持的复杂滤镜，直接记录类名。
					// 这样如果用户把复杂滤镜移除了，我们能检测到变化并清空。
					sig += "Other_" + getQualifiedClassName(f) + "|";
				}
			}
			return sig;
		}
		
		public function getName():String
		{
			return source.name;
		}
		
		public function dispose():void
		{
			if (_onDisposeArgs != null && source != null)
			{
				_onDisposeArgs(source);
				_onDisposeArgs = null;
			}
			// [新增] 核心修改：利用递归顺便销毁 Starling 对象
            if (renderer)
            {
				if (onDisposeRenderer != null)
				{
					onDisposeRenderer(this);
				}
			
                if (renderer.hasOwnProperty("dispose"))
                {
					renderer["removeFromParent"](false); // 从 Starling 舞台移除并 dispose
					// 或者直接 renderer["dispose"](); 视你的 Starling 版本而定
                }
                renderer = null;
            }
			if (children)
			{
				for (var j:int = children.length - 1; j >= 0; j--)
				{
					children[j].dispose();
				}
				children = null;
			}
			
			if (bitmapData){
				bitmapData.dispose();
				bitmapData = null;
			}
			source = null;
			onUpdate = null;
		}
	}
}