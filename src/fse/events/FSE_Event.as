package fse.events
{
	import flash.events.Event;

	public class FSE_Event extends Event
	{
        /**
         * 逻辑更新事件 (固定 60FPS)
         * 无论屏幕刷新率是多少，此事件每秒触发 60 次
         */
		public static const FIX_ENTER_FRAME:String = "fix_enter_frame";

		public function FSE_Event(type:String,bubbles:Boolean=false,cancelable:Boolean=false)
		{
			super(type,bubbles,cancelable);
		}
	}
}