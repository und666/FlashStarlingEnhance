package cmpt {
    import flash.display.DisplayObject;
    import flash.events.Event;
    import flash.utils.Dictionary;
    
    import fse.core.FSE;
    import fse.events.FSE_Event;

    /**
     * 果冻效果管理器 (指令式)
     * 用法: Jelly.pop(myMovieClip);
     */
    public class Jelly {
        
        // 使用弱引用字典，防止内存泄漏 (如果对象被销毁，这里会自动释放)
        private static var _activeEffects:Dictionary = new Dictionary(true);

        /**
         * 立即让目标对象像果冻一样弹动一次
         * @param target 要弹动的显示对象
         * @param power 弹性强度 (0.1 ~ 1.0)，值越大变形越夸张
         */
        public static function pop(target:DisplayObject, power:Number = 0.2):void {
            if (!target) return;

            var effector:JellyEffector = _activeEffects[target];
            
            // 如果这个对象之前没在弹，或者弹完了，创建一个新的控制器
            if (effector == null) {
                effector = new JellyEffector(target);
                _activeEffects[target] = effector;
            }
            
            // 给它一脚，让它开始动 (重置为被积压的状态)
            effector.punch(power);
        }
    }
}

// ========================================================================
//  内部辅助类 (外部不可见，专门处理物理计算)
// ========================================================================
import flash.display.DisplayObject;
import flash.events.Event;
import flash.display.Sprite;
import fse.core.FSE;
import fse.events.FSE_Event;

class JellyEffector {
    public var target:DisplayObject;
    
    // 原始比例 (基准值)
    private var _baseScaleX:Number;
    private var _baseScaleY:Number;
    
    // 物理变量
    private var _vx:Number = 0;
    private var _vy:Number = 0;
    
    // 物理常量
    private const FRICTION:Number = 0.85; // 摩擦力
    private const ELASTICITY:Number = 0.3; // 弹性系数

    public function JellyEffector(t:DisplayObject) {
        this.target = t;
        // 记录初始状态，以当前状态为准
        this._baseScaleX = t.scaleX;
        this._baseScaleY = t.scaleY;
    }

    /**
     * 施加外力 (这里表现为瞬间形变)
     */
    public function punch(power:Number):void {
        // 瞬间压扁 (模拟受力)
        // 只要修改当前的 scale，物理引擎就会自动想办法把它拉回 baseScale
        target.scaleX = _baseScaleX * (1 - power);
        target.scaleY = _baseScaleY * (1 - power); // 也可以做成 * (1+power) 做拉伸效果
        
        // 确保监听器在运行 (防止重复添加)
        FSE.removeEventListener(target,FSE_Event.FIX_ENTER_FRAME, update);
        FSE.addEventListener(target,FSE_Event.FIX_ENTER_FRAME, update);
    }

    private function update(e:Event):void {
        if (!target || !target.stage) {
            stop();
            return;
        }

        // 1. Hooke's Law (虎克定律): 力 = 距离 * 系数
        var dx:Number = _baseScaleX - target.scaleX;
        var dy:Number = _baseScaleY - target.scaleY;

        // 2. 速度叠加加速度
        _vx += dx * ELASTICITY;
        _vy += dy * ELASTICITY;

        // 3. 摩擦力损耗
        _vx *= FRICTION;
        _vy *= FRICTION;

        // 4. 应用位移
        target.scaleX += _vx;
        target.scaleY += _vy;

        // 5. 休眠检测 (当动能非常小时停止，节省 CPU)
        if (Math.abs(_vx) < 0.001 && Math.abs(_vy) < 0.001 && 
            Math.abs(dx) < 0.001 && Math.abs(dy) < 0.001) {
            
            // 强制归位，消除误差
            target.scaleX = _baseScaleX;
            target.scaleY = _baseScaleY;
            stop();
        }
    }

    private function stop():void {
        FSE.removeEventListener(target,FSE_Event.FIX_ENTER_FRAME, update);
        // 不从字典移除，保留 effector 实例以便下次复用 baseScale 信息
        // 如果需要极致内存优化，也可以在这里 callback 通知主类移除
    }
}