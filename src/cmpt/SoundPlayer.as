package cmpt{
    import flash.media.Sound;
    import flash.media.SoundChannel;
    import flash.net.URLRequest;
    import flash.events.Event;
    import flash.events.IOErrorEvent;

    public class SoundPlayer {
        private var sound:Sound;
        private var soundChannel:SoundChannel;
        private var _loop:Boolean;
        private var _autoDispose:Boolean = true; // 新增自动释放标志

        // 加载并播放（新增自动释放参数）
        public function loadAndPlay(url:String, loop:Boolean = false, autoDispose:Boolean = true):void {
            dispose(); // 先释放之前资源
            _loop = loop;
            _autoDispose = autoDispose;
            
            sound = new Sound();
            configureSoundListeners();
            sound.load(new URLRequest(url));
        }

        // 播放控制（新增自动释放参数)
        public function play():void {
            if(sound) {
                stop();
                startPlay();
            }
        }

        // 停止并释放资源
        public function stop():void {
            if(soundChannel) {
                soundChannel.removeEventListener(Event.SOUND_COMPLETE, onComplete);
                soundChannel.stop();
                soundChannel = null;
            }
        }

        // 新增内存释放方法
        public function dispose():void{
            stop();
            
            if(sound) {
                sound.removeEventListener(Event.COMPLETE, onLoadComplete);
                sound.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
                sound = null;
            }
        }

        // 播放完成处理
        private function onComplete(e:Event):void {
            if(_loop) {
                startPlay(); // 循环播放
            } else if(_autoDispose) {
                dispose(); // 自动释放
            }
        }

        // 私有方法保持不变...
        private function startPlay():void {
            soundChannel = sound.play();
            soundChannel.addEventListener(Event.SOUND_COMPLETE, onComplete);
        }

        private function configureSoundListeners():void {
            sound.addEventListener(Event.COMPLETE, onLoadComplete);
            sound.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
        }

        private function onLoadComplete(event:Event):void {
            startPlay();
        }

        private function onLoadError(event:IOErrorEvent):void {
            trace("加载失败: " + event.text);
            dispose();
        }
    }
}
