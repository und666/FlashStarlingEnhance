package fse.cache
{
	import flash.utils.Dictionary;
	import starling.textures.Texture;

	/**
	 * 纹理缓存容器
	 * 职责：底层存储 Key-Texture 映射
	 */
	public class Cache
	{
		// 核心字典 { key:String, value:Texture }
		private var _dict:Dictionary;

		public function Cache()
		{
			_dict = new Dictionary  ;
		}

		/**
		 * 尝试获取纹理
		 */
		public function getTexture(key:String):Texture
		{
			return _dict[key] as Texture;
		}

		/**
		 * 存入纹理
		 */
		public function addTexture(key:String,texture:Texture):void
		{
			if ((key && texture))
			{
				_dict[key] = texture;
				// trace("[Cache] ⚡ 新纹理入库 Key:", key);
			}
		}

		/**
		 * 检查是否存在
		 */
		public function hasKey(key:String):Boolean
		{
			return _dict[key] != undefined;
		}

		/**
		 * (预留) 移除指定 Key
		 */
		public function removeTexture(key:String):void
		{
			if (_dict[key])
			{
				delete _dict[key];
			}
		}
	}
}