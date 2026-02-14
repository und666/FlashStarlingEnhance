package fse.cache
{
	import flash.display.BitmapData;
	import flash.geom.Rectangle;
	import starling.display.BlendMode;
	import starling.display.Image;
	import starling.display.Quad;
	import starling.textures.RenderTexture;
	import starling.textures.SubTexture;
	import starling.textures.Texture;

	/**
	 * 单个图集页面 (修复版：Guillotine算法 + 自动擦除)
	 * 解决：纹理重叠、残影、画面错乱问题
	 */
	public class AtlasPage
	{
		private var _rootTexture:RenderTexture; 
		private var _freeRects:Vector.<Rectangle>; 
		private var _usedRects:Object; 
		
		private var _width:int;
		private var _height:int;

		// 纹理间隔 (防出血)
		private static const PADDING:int = 2;
		
		// 橡皮擦工具 (复用以节省性能)
		private var _eraserHelper:Quad;

		public function AtlasPage(width:int = 2048, height:int = 2048)
		{
			_width = width;
			_height = height;
			_freeRects = new Vector.<Rectangle>();
			_usedRects = {};
			
			// 初始化橡皮擦 (黑色，BlendMode.ERASE)
			_eraserHelper = new Quad(32, 32, 0x0);
			_eraserHelper.blendMode = BlendMode.ERASE;
			
			_freeRects.push(new Rectangle(0, 0, width, height));
			
			_rootTexture = new RenderTexture(width, height, true);
		}

		public function insert(bmd:BitmapData, key:String):SubTexture
		{
			var w:int = bmd.width;
			var h:int = bmd.height;
			
			var neededW:int = w + PADDING;
			var neededH:int = h + PADDING;
			
			// --- 1. 寻找空位 (Best-Fit) ---
			var bestRect:Rectangle = null;
			var bestShortSideFit:int = int.MAX_VALUE;
			var bestRectIndex:int = -1;

			for (var i:int = 0; i < _freeRects.length; i++)
			{
				var free:Rectangle = _freeRects[i];
				if (free.width >= neededW && free.height >= neededH)
				{
					var leftoverHoriz:int = Math.abs(free.width - neededW);
					var leftoverVert:int = Math.abs(free.height - neededH);
					var shortSideFit:int = Math.min(leftoverHoriz, leftoverVert);

					if (shortSideFit < bestShortSideFit)
					{
						bestRect = free;
						bestShortSideFit = shortSideFit;
						bestRectIndex = i;
					}
				}
			}

			if (bestRect == null) return null;

			// 锁定区域
			var placedRect:Rectangle = new Rectangle(bestRect.x, bestRect.y, neededW, neededH);
			
			// --- 2. [关键修复] 橡皮擦操作 ---
			// 在画新图之前，必须先把这块区域原本的像素擦除！
			// 否则如果这块区域以前被用过，就会出现"鬼影"或叠加
			_eraserHelper.width = placedRect.width;
			_eraserHelper.height = placedRect.height;
			_eraserHelper.x = placedRect.x;
			_eraserHelper.y = placedRect.y;
			_rootTexture.draw(_eraserHelper); // 擦除！
			
			// --- 3. 绘制新图 ---
			var tempTex:Texture = Texture.fromBitmapData(bmd, false);
			var img:Image = new Image(tempTex);
			img.x = placedRect.x;
			img.y = placedRect.y;
			
			_rootTexture.draw(img); // 绘制！
			
			img.dispose();
			tempTex.dispose();
			
			// --- 4. [关键修复] 空间切割 (Guillotine Split) ---
			// 之前的简易算法会导致空闲矩形重叠，导致后续分配错乱
			// 现在使用 Guillotine 策略：将剩余空间切成"右边"和"下边"两块，绝不重叠
			
			// 先从列表中移除旧的大块
			_freeRects.splice(bestRectIndex, 1);
			
			// 执行不重叠切割
			performGuillotineSplit(bestRect, placedRect);
			
			_usedRects[key] = placedRect;

			// 返回
			var subRegion:Rectangle = new Rectangle(placedRect.x, placedRect.y, w, h);
			return new SubTexture(_rootTexture, subRegion);
		}

		public function release(key:String):void
		{
			var rect:Rectangle = _usedRects[key];
			if (rect)
			{
				_freeRects.push(rect); 
				delete _usedRects[key];
				// 优化：尝试合并相邻的 freeRects (为了代码稳定性，暂不实现，靠大图集硬抗)
			}
		}
		
		public function get isEmpty():Boolean
		{
			for (var k:String in _usedRects) return false;
			return true;
		}

		public function dispose():void
		{
			if (_rootTexture) _rootTexture.dispose();
			if (_eraserHelper) _eraserHelper.dispose();
			_freeRects = null;
			_usedRects = null;
		}
		
		/**
		 * [核心修复] Guillotine (断头台) 切割算法
		 * 这种切法保证产生的两个新矩形绝对不会重叠
		 */
		private function performGuillotineSplit(freeRect:Rectangle, placedRect:Rectangle):void
		{
			// 剩余宽度和高度
			var wRemain:int = freeRect.width - placedRect.width;
			var hRemain:int = freeRect.height - placedRect.height;
			
			// 策略：选择切分出较大的矩形，减少碎片
			// 这里使用"较短边优先"或者"面积最大优先"，为了稳定我们用简单的水平/垂直切割选择
			
			if (wRemain > hRemain)
			{
				// 垂直切割 (Vertical Split) - 右边一块大的，下边一块仅限于放置区域宽度的
				// New Right (大)
				if (wRemain > 0)
					_freeRects.push(new Rectangle(freeRect.x + placedRect.width, freeRect.y, wRemain, freeRect.height));
				
				// New Bottom (窄)
				if (hRemain > 0)
					_freeRects.push(new Rectangle(freeRect.x, freeRect.y + placedRect.height, placedRect.width, hRemain));
			}
			else
			{
				// 水平切割 (Horizontal Split) - 下边一块大的，右边一块仅限于放置区域高度的
				// New Bottom (大)
				if (hRemain > 0)
					_freeRects.push(new Rectangle(freeRect.x, freeRect.y + placedRect.height, freeRect.width, hRemain));
					
				// New Right (窄)
				if (wRemain > 0)
					_freeRects.push(new Rectangle(freeRect.x + placedRect.width, freeRect.y, wRemain, placedRect.height));
			}
		}
	}
}