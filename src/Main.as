package {

import flash.display.MovieClip;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import cmpt.Jelly; //弹性效果控制类

public class Main extends Sprite {
    
    //一个正方形
    private var square:MovieClip;
    private var mouse_status:Boolean = false;
    
    public function Main() {
        // 建议加上这一步判断，确保 Stage 已经准备好
        if (stage) {
            init();
        } else {
            addEventListener(Event.ADDED_TO_STAGE, init);
        }
    }
    
    private function init(e:Event = null):void {
        removeEventListener(Event.ADDED_TO_STAGE, init);
        
        // 1. 初始化 FSE 框架
        // 第二个参数传递 this (即 Object(root))
        fse.init(stage, this);
        fse.setKeyRole(square);
        
        // 2. 创建专业样式的方块
        createProfessionalSquare();
        addChild(square);
        
        
        
        // 3. 绑定事件监听
        addEventListener(Event.ENTER_FRAME, update);
        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDownHandler);
        stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUpHandler);
        
        // 初始位置居中
        square.x = stage.stageWidth / 2;
        square.y = stage.stageHeight / 2;
    }
    
    /**
     * 创建一个带有科技感的线框正方形 MovieClip
     */
    private function createProfessionalSquare():void {
        square = new MovieClip();
        
        // --- 样式定义 ---
        // 笔触：3像素宽，科技青色 (Cyan)，100%不透明度
        square.graphics.lineStyle(1, 0x00E5FF, 1, true);
        // 填充：深空灰，90%不透明度 (半透明显得更有质感)
        square.graphics.beginFill(0x263238, 0.9);
        
        // 绘制正方形
        // 注意：这里使用 (-25, -25, 50, 50) 是为了让注册点(0,0)位于正方形中心
        // 这样 Jelly.pop 缩放时会从中心向外弹动，而不是从左上角
        square.graphics.drawRect(-25, -25, 50, 50);
        
        // 额外细节：画一个小十字瞄准心，增加“调试模式”的感觉
        square.graphics.lineStyle(1, 0xFFFFFF, 0.5);
        square.graphics.moveTo(-5, 0); square.graphics.lineTo(5, 0);
        square.graphics.moveTo(0, -5); square.graphics.lineTo(0, 5);
        
        square.graphics.endFill();
    }
    
    /**
     * 帧循环逻辑
     */
    private function update(e:Event):void {
        if (mouse_status) {
            square.x = mouseX;
            square.y = mouseY;
        }
    }
    
    /**
     * 鼠标按下
     */
    private function onMouseDownHandler(e:MouseEvent):void {
        mouse_status = true;
        
        // 立即更新位置，防止瞬移延迟
        square.x = mouseX;
        square.y = mouseY;
        
        // 触发果冻弹跳效果
        Jelly.pop(square);
    }
    
    /**
     * 鼠标抬起
     */
    private function onMouseUpHandler(e:MouseEvent):void {
        mouse_status = false;
    }
}
}