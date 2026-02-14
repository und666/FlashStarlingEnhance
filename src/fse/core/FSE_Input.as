package fse.core
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Stage;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.display.InteractiveObject;
	
	/**
	 * FSE (Flash Starling Enhance) Input Manager
	 * 核心功能：接管Stage鼠标输入，手动对隐藏的CPU层显示列表进行碰撞检测并转发事件
	 */
	public class FSE_Input
	{
		private static var _stage: Stage;
		private static var _isInit: Boolean = false;
		// 【新增】记录鼠标按下的位置
		private static var _downPoint: Point = new Point();
		// 【新增】点击容差（像素），超过这个距离视为拖拽，不触发 Click
		// 你可以根据需要调整这个值，通常 3-5 像素比较合适
		private static const CLICK_TOLERANCE: Number = 3.0;
		/**
		 * 初始化输入管理器
		 * @param stage Flash原生舞台 (flash.display.Stage)
		 */
		public static function init(stage: Stage): void
		{
			if (_isInit) return;
			_stage = stage;
			_isInit = true;

			// 【关键修改 1】使用 int.MAX_VALUE (2147483647) 确保此监听器拥有最高优先级
			// 这样保证 FSE_Input 永远是第一个处理点击的，比用户写的 stage.addEventListener 先执行
			_stage.addEventListener(MouseEvent.CLICK, onStageMouseEvent, false, int.MAX_VALUE, true);
			_stage.addEventListener(MouseEvent.MOUSE_DOWN, onStageMouseEvent, false, int.MAX_VALUE, true);
			_stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseEvent, false, int.MAX_VALUE, true);
		}

		/**
		 * 统一处理 Stage 上的鼠标事件
		 */
		private static function onStageMouseEvent(e: MouseEvent): void
		{
			// 【重要】防止死循环
			// 如果事件的目标(target)不是Stage，说明这是我们刚刚手动派发出去并冒泡上来的事件
			// 我们忽略它，只处理用户真实的物理点击（此时 target 必定是 Stage，因为其他东西都隐藏了）
			if (e.target != _stage)
			{
				return;
			}
			// 【新增逻辑】处理按下坐标记录
			if (e.type == MouseEvent.MOUSE_DOWN)
			{
				_downPoint.x = e.stageX;
				_downPoint.y = e.stageY;
			}

			// 【新增逻辑】处理点击时的位移判断
			if (e.type == MouseEvent.CLICK)
			{
				// 计算按下点和释放点(当前点)的距离
				var dx: Number = e.stageX - _downPoint.x;
				var dy: Number = e.stageY - _downPoint.y;
				var dist: Number = Math.sqrt(dx * dx + dy * dy);

				// 如果移动距离超过容差，视为拖拽操作
				if (dist > CLICK_TOLERANCE)
				{
					// 阻止此事件继续传播（拦截掉本次 Click）
					e.stopImmediatePropagation();
					return; // 直接退出，不执行后面的 scan 和 dispatchEvent
				}
			}
			// 开始从舞台顶层向下递归扫描目标
			var hitObject: DisplayObject = scan(_stage, e.stageX, e.stageY);

			// 如果扫到了某个肉节点
			if (hitObject)
			{
				e.stopImmediatePropagation();

				// 【修复 Error #1034 的核心逻辑】
				// 如果命中的是 Shape 或 Bitmap，它们不是 InteractiveObject。
				// 我们需要向上遍历，找到最近的一个 InteractiveObject (通常是它的父容器 Sprite/MovieClip)
				// 只要当前对象存在，且它不是 InteractiveObject，就往上找
				while (hitObject && !(hitObject is InteractiveObject))
				{
					hitObject = hitObject.parent;
				}

				// 如果找了一圈发现全是 Shape (虽然不太可能，除非直接addChild到Stage且Stage都不算? Stage本身是InteractiveObject)，判空一下
				if (hitObject)
				{
					// 此时 hitObject 必定是 Sprite, MovieClip 或 Stage 等可交互对象
					// 我们基于这个新的对象计算本地坐标
					var localP: Point = hitObject.globalToLocal(new Point(e.stageX, e.stageY));

					var relatedObj: InteractiveObject = e.relatedObject as InteractiveObject;

					var simulatedEvent: FSE_MouseEvent = new FSE_MouseEvent(
						e.type,
						true,
						e.cancelable,
						localP.x,
						localP.y,
						e.stageX,
						e.stageY,
						relatedObj,
						e.ctrlKey,
						e.altKey,
						e.shiftKey,
						e.buttonDown,
						e.delta
					);
					
					// 现在派发事件的对象保证是 InteractiveObject，FocusManager 不会再报错了
					hitObject.dispatchEvent(simulatedEvent);
				}
			}
		}

		/**
		 * 核心扫描算法
		 * @param container 当前扫描的容器
		 * @param x 全局鼠标X
		 * @param y 全局鼠标Y
		 * @return 命中的叶子节点，如果未命中返回null
		 */
		private static function scan(container: DisplayObjectContainer, x: Number, y: Number): DisplayObject
		{
			// 按照 Flash 渲染层级，索引越大越在顶层
			// 所以我们需要从 numChildren - 1 开始递减遍历 (由顶到底)
			for (var i: int = container.numChildren - 1; i >= 0; i--)
			{
				var child: DisplayObject = container.getChildAt(i);

				// 即使对象是 visible=false，只要它在显示列表中，我们就进行逻辑判断

				// 1. 如果是容器 (DisplayObjectContainer)
				// 按照你的要求：继续对其列表进行遍历扫描
				if (child is DisplayObjectContainer)
				{
					// 递归调用
					var result: DisplayObject = scan(child as DisplayObjectContainer, x, y);
					// 如果在子级中找到了目标，立即停止扫描并返回，不再检查当前层级更下层的对象
					if (result)
					{
						return result;
					}
				}
				// 2. 如果是肉节点 (非容器，如 Shape, Bitmap 等)
				else
				{
					// 获取该对象在 Stage 坐标系下的包围盒 (剧情框)
					var bounds: Rectangle = child.getBounds(_stage);

					// 比对鼠标是否在剧情框内
					if (bounds.contains(x, y))
					{
						// 命中！停止全部扫描，返回该对象
						return child;
					}
				}
			}
			return null;
		}
	}
}


import flash.events.Event;
import flash.events.MouseEvent;
// 【关键修正1】必须导入这个类，否则编译器不认识 InteractiveObject
import flash.display.InteractiveObject;

class FSE_MouseEvent extends MouseEvent
{

	private var _overrideStageX: Number;
	private var _overrideStageY: Number;

	public function FSE_MouseEvent(type: String,
		bubbles: Boolean = true,
		cancelable: Boolean = false,
		localX: Number = 0,
		localY: Number = 0,
		stageX: Number = 0,
		stageY: Number = 0,
		// 【关键修正2】这里必须严格定义为 InteractiveObject，不能写 Object
		relatedObject: InteractiveObject = null,
		ctrlKey: Boolean = false,
		altKey: Boolean = false,
		shiftKey: Boolean = false,
		buttonDown: Boolean = false,
		delta: int = 0)
	{

		// 现在这里不会报错了，因为传入的类型完全匹配父类要求
		super(type, bubbles, cancelable, localX, localY, relatedObject, ctrlKey, altKey, shiftKey, buttonDown, delta);

		_overrideStageX = stageX;
		_overrideStageY = stageY;
	}

	override public function get stageX(): Number
	{
		return _overrideStageX;
	}

	override public function get stageY(): Number
	{
		return _overrideStageY;
	}

	override public function clone(): Event
	{
		return new FSE_MouseEvent(type, bubbles, cancelable, localX, localY, _overrideStageX, _overrideStageY, relatedObject, ctrlKey, altKey, shiftKey, buttonDown, delta);
	}
}