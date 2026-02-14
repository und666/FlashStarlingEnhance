package
{
	import fse.events.*;
	import fse.conf.*;
	import fse.core.*;
	import fse.starling.StarlingMain;
	import fse.starling.StarlingManager;
	
    import flash.display.Stage;
	import flash.display.DisplayObjectContainer;
    import flash.events.Event;
	import flash.display.DisplayObject;
    import flash.display.MovieClip;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
    import flash.utils.getTimer;
	
	import starling.display.Sprite;
	
    public class fse
    {
		public static function init(stageRef:Stage,gameRoot:DisplayObjectContainer,takeOver:Boolean = true):void
        {
			FSE.init(stageRef,gameRoot,takeOver);
		}
	
		public static function visible(mc:DisplayObject,value:Boolean):void
		{
			FSE.visible(mc,value);
		}
		
		public static function getVisible(mc:DisplayObject):Boolean
		{
			return FSE.getVisible(mc);
		}
	
		public static function play(mc:MovieClip):void
		{
			FSE.play(mc);
		}
	
		public static function stop(mc:MovieClip):void
		{
			FSE.stop(mc);
		}
		public static function gotoAndStop(mc:MovieClip,frame:uint):void
		{
			FSE.gotoAndStop(mc,frame);
		}
		public static function gotoAndPlay(mc:MovieClip,frame:uint):void
		{
			FSE.gotoAndPlay(mc,frame);
		}
		public static function loop(listener:Function){
			FSE.loop(listener);
		}
		public static function stopLoop(listener:Function){
			FSE.stopLoop(listener);
		}
		public static function addLoop(scope:Object,listener:Function){
			FSE.addLoop(scope,listener);
		}
		
		public static function removeLoop(scope:Object,listener:Function){
			FSE.removeLoop(scope,listener);
		}
		
		public static function addEventListener(scope:Object, type:String, listener:Function):void
        {
            FSE.addEventListener(scope, type, listener);
        }
	
		public static function removeEventListener(scope:Object, type:String, listener:Function):void
		{
			FSE.removeEventListener(scope, type, listener);
		}
	
		public static function ban(target:Object):void
		{
			FSE.ban(target);
		}
		
		public static function noBan(target:Object):void
		{
			FSE.noBan(target);
		}
		
		public static function gpu(target:Object):void
		{
			FSE.noBan(target);
		}
		
		public static function cpu(target:Object):void
		{
			FSE.ban(target);
		}
		
		public static function isIgnore(target:Object):void{
			FSE.isIgnore(target);
		}
		
		public static function setNodeCached(mc:MovieClip, useCache:Boolean):void
        {
            FSE.setNodeCached(mc,useCache);
        }
		
		public static function gpuClear():void
        {
            FSE.gpuClear();
        }
	
		public static function getKeyRole():String{
			return FSE.keyRole;
		}
	
		public static function setKeyRole(mc:MovieClip){
			FSE.setKeyRole(mc);
		}
	
		public static function noKeyRole(){
			FSE.noKeyRole();
		}
		public static function get starlingRoot():Sprite{
			return FSE.starlingRoot;
		}
		public static function get starlingRootBack():Sprite{
			return FSE.starlingRootBack;
		}
	}
}