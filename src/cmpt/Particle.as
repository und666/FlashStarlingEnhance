package cmpt {
    import flash.display.Bitmap;
    import flash.display.Loader;
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.net.URLLoader;
    import flash.net.URLRequest;
    
    import starling.core.Starling;
    import starling.display.Sprite;
    import starling.events.Event;
    import starling.extensions.particle.*;
    import starling.textures.Texture;

    /**
     * 动态加载的 Starling 粒子效果
     * 功能：传入 .pex 和 .png 的 URL，自动加载并播放
     */
    public class Particle {
        
        // 外部引用
        private var _starlingRoot:Sprite;
        
        // 加载器
        private var _xmlLoader:URLLoader;
        private var _imgLoader:Loader;
        
        // 数据缓存
        private var _pexXML:XML;
        private var _texture:Texture;
        
        // 核心粒子对象
        private var _particleSystem:PDParticleSystem;
        
        // 配置参数
        private var _playOnceAndDispose:Boolean;
        
		// 新增：用于缓存属性的私有变量 (防止加载未完成时设置报错)
        private var _cacheEmitterX:Number = 0;
        private var _cacheEmitterY:Number = 0;
        private var _cacheLocalX:Number = 0;
        private var _cacheLocalY:Number = 0;
        /**
         * 构造函数
         * @param starlingRoot Starling 显示列表的根容器
         * @param pexUrl .pex (XML) 配置文件路径
         * @param pngUrl 纹理图片路径
         * @param x 初始X坐标 (可选)
         * @param y 初始Y坐标 (可选)
         * @param playOnceAndDispose 是否播放一次完成后自动销毁 (可选, 默认 false)
         */
        public function Particle(starlingRoot:Sprite, pexUrl:String, pngUrl:String, playOnceAndDispose:Boolean = false, x:Number = 0, y:Number = 0) {
            _starlingRoot = starlingRoot;
            _playOnceAndDispose = playOnceAndDispose;
            _cacheLocalX = x;
            _cacheLocalY = y;
            loadPex(pexUrl, pngUrl);
        }

        //Step 1: 加载 XML
        private function loadPex(pexUrl:String, pngUrl:String):void {
            _xmlLoader = new URLLoader();
            _xmlLoader.addEventListener(flash.events.Event.COMPLETE, function(e:flash.events.Event):void {
                _pexXML = XML(e.target.data);
                loadPng(pngUrl); // XML加载完后加载图片
            });
            _xmlLoader.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
            _xmlLoader.load(new URLRequest(pexUrl));
        }

        //Step 2: 加载 PNG
        private function loadPng(pngUrl:String):void {
            _imgLoader = new Loader();
            _imgLoader.contentLoaderInfo.addEventListener(flash.events.Event.COMPLETE, onPngComplete);
            _imgLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
            _imgLoader.load(new URLRequest(pngUrl));
        }

        //Step 3: 创建并初始化粒子
        private function onPngComplete(e:flash.events.Event):void {
            var bitmap:Bitmap = e.target.content as Bitmap;
            
            // 创建纹理 (注意：这里没有使用 AssetManager，所以这个 Texture 归本实例管理)
            _texture = Texture.fromBitmap(bitmap);
            
            // 实例化 Starling 粒子系统
            _particleSystem = new PDParticleSystem(_pexXML, _texture);
            _particleSystem.x = _cacheLocalX; // 应用 localX
            _particleSystem.y = _cacheLocalY; // 应用 localY
            _particleSystem.emitterX = _cacheEmitterX; // 应用 emitterX
            _particleSystem.emitterY = _cacheEmitterY; // 应用 emitterY
            
            // 添加到舞台
            if (_starlingRoot) {
                _starlingRoot.addChild(_particleSystem);
            }
            
            // 必须添加到 Juggler 才能动起来！
            Starling.juggler.add(_particleSystem);
            
            // 开始播放
            _particleSystem.start();
            
            // 如果设置了只播放一次
            if (_playOnceAndDispose) {
                // PDParticleSystem 会在生命周期结束时派发 COMPLETE 事件
                _particleSystem.addEventListener(starling.events.Event.COMPLETE, onPlayComplete);
            }
            
            // 清理加载器引用
            cleanupLoaders();
        }
        
		/**
         * 设置粒子发射点的 X 偏移量 (emitterX)
         * 注意：这是相对于 localX 的偏移
         */
        public function set x(value:Number):void {
            _cacheEmitterX = value;
            if (_particleSystem) {
                _particleSystem.emitterX = value;
            }
        }
        
        public function get x():Number {
            if (_particleSystem) return _particleSystem.emitterX;
            return _cacheEmitterX;
        }

        /**
         * 设置粒子发射点的 Y 偏移量 (emitterY)
         */
        public function set y(value:Number):void {
            _cacheEmitterY = value;
            if (_particleSystem) {
                _particleSystem.emitterY = value;
            }
        }

        public function get y():Number {
            if (_particleSystem) return _particleSystem.emitterY;
            return _cacheEmitterY;
        }

        /**
         * 设置粒子系统的整体 X 坐标 (system.x)
         * 相当于 DisplayObject 的 x
         */
        public function set localX(value:Number):void {
            _cacheLocalX = value;
            if (_particleSystem) {
                _particleSystem.x = value;
            }
        }

        public function get localX():Number {
            if (_particleSystem) return _particleSystem.x;
            return _cacheLocalX;
        }

        /**
         * 设置粒子系统的整体 Y 坐标 (system.y)
         */
        public function set localY(value:Number):void {
            _cacheLocalY = value;
            if (_particleSystem) {
                _particleSystem.y = value;
            }
        }

        public function get localY():Number {
            if (_particleSystem) return _particleSystem.y;
            return _cacheLocalY;
        }
	
        private function onPlayComplete(e:starling.events.Event):void {
            dispose();
        }

        private function onIOError(e:IOErrorEvent):void {
            trace("[ParticleEffect] Load Error: " + e.text);
            cleanupLoaders();
        }
        
        private function cleanupLoaders():void {
            if (_xmlLoader) {
                _xmlLoader.removeEventListener(flash.events.Event.COMPLETE, arguments.callee); // 移除匿名函数会有困难，这里简化处理，依赖GC
                _xmlLoader = null;
            }
            if (_imgLoader) {
                _imgLoader.unloadAndStop();
                _imgLoader = null;
            }
        }

        /**
         * 获取核心对象，以便进行更精细的操作（如修改发射器位置等）
         */
        public function get system():PDParticleSystem {
            return _particleSystem;
        }
		
		/**
         * 柔性销毁 (Soft Dispose)
         * 停止产生新粒子，等屏幕上残留的粒子全部播放完毕后，自动销毁并释放内存。
         * 适用于：火把熄灭、魔法结束、引擎关闭。
         */
        public function softDispose():void {
            if (_particleSystem) {
                // 1. 停止发射器 (不再产生新粒子)
                _particleSystem.stop();
                
                // 2. 监听完成事件 (等待旧粒子死光)
                // 注意：如果粒子原本是无限循环的，调用 stop() 后它也会最终结束
                if (!_particleSystem.hasEventListener(starling.events.Event.COMPLETE)) {
                    _particleSystem.addEventListener(starling.events.Event.COMPLETE, onSoftDisposeComplete);
                }
            } else {
                // 如果粒子系统还没加载出来就调用了这个，直接销毁吧
                dispose();
            }
        }

        // 内部回调：当残留粒子全部消失时触发
        private function onSoftDisposeComplete(e:starling.events.Event):void{
            if (_particleSystem) {
                _particleSystem.removeEventListener(starling.events.Event.COMPLETE, onSoftDisposeComplete);
            }
            // 执行真正的物理销毁
            dispose(); 
        }
        /**
         * 手动销毁
         * 务必调用此方法以防止内存泄漏
         */
        public function dispose():void {
            // 1. 从 Juggler 移除
            if (_particleSystem) {
                Starling.juggler.remove(_particleSystem);
                _particleSystem.stop();
                _particleSystem.removeFromParent(true); // true 会调用 system 的 dispose
                _particleSystem = null;
            }
            
            // 2. 销毁纹理 (因为是我们自己 new 出来的，不是从 AssetManager 借来的，所以要负责到底)
            if (_texture) {
                _texture.dispose();
                _texture = null;
            }
            
            _starlingRoot = null;
            cleanupLoaders();
            
            // trace("[ParticleEffect] Disposed.");
        }
    }
}