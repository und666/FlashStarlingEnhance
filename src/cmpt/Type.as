package cmpt {
    import flash.utils.getQualifiedClassName;

    /**
     * 简单的类型调试工具
     * 用于快速查看对象的类名（不含包名）
     */
    public class Type {

        /**
         * 输出并返回对象的简单类名
         * @param target 要检测的对象
         * @return 简单的类名字符串 (例如 "Sprite", "MovieClip")
         */
        public static function log(target:Object):String {
            if (target == null) {
                trace("[Type] null");
                return "null";
            }

            // 获取完全限定类名 (例如 "flash.display::Sprite")
            var fullClassName:String = getQualifiedClassName(target);
            
            // 提取 :: 之后的部分，即简单类名
            var shortClassName:String;
            var index:int = fullClassName.lastIndexOf("::");
            
            if (index != -1) {
                shortClassName = fullClassName.substring(index + 2);
            } else {
                // 如果没有包名（顶级类或基本类型），直接使用
                shortClassName = fullClassName;
            }

            // 调试输出
            trace("[Type] Object: " + target + " is " + shortClassName);
            
            return shortClassName;
        }
    }
}