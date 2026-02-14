package fse.utils
{
	/**
	 * MD5 Hash Implementation
	 */
	public class MD5
	{
		public static function getMD5(string:String):String
		{
			var x:Array;
			var k:int, AA:int, BB:int, CC:int, DD:int, a:int, b:int, c:int, d:int;
			
			// 常量定义 (S Constants)
			const S11:int = 7, S12:int = 12, S13:int = 17, S14:int = 22;
			const S21:int = 5, S22:int = 9,  S23:int = 14, S24:int = 20;
			const S31:int = 4, S32:int = 11, S33:int = 16, S34:int = 23;
			const S41:int = 6, S42:int = 10, S43:int = 15, S44:int = 21;

			string = utf8Encode(string);
			x = convertToWordArray(string);

			a = 0x67452301;
			b = 0xEFCDAB89;
			c = 0x98BADCFE;
			d = 0x10325476;

			for (k = 0; k < x.length; k += 16)
			{
				AA = a;
				BB = b;
				CC = c;
				DD = d;

				// Round 1
				a = FF(a, b, c, d, x[k + 0],  S11, 0xD76AA478);
				d = FF(d, a, b, c, x[k + 1],  S12, 0xE8C7B756);
				c = FF(c, d, a, b, x[k + 2],  S13, 0x242070DB);
				b = FF(b, c, d, a, x[k + 3],  S14, 0xC1BDCEEE);
				a = FF(a, b, c, d, x[k + 4],  S11, 0xF57C0FAF);
				d = FF(d, a, b, c, x[k + 5],  S12, 0x4787C62A);
				c = FF(c, d, a, b, x[k + 6],  S13, 0xA8304613);
				b = FF(b, c, d, a, x[k + 7],  S14, 0xFD469501);
				a = FF(a, b, c, d, x[k + 8],  S11, 0x698098D8);
				d = FF(d, a, b, c, x[k + 9],  S12, 0x8B44F7AF);
				c = FF(c, d, a, b, x[k + 10], S13, 0xFFFF5BB1);
				b = FF(b, c, d, a, x[k + 11], S14, 0x895CD7BE);
				a = FF(a, b, c, d, x[k + 12], S11, 0x6B901122);
				d = FF(d, a, b, c, x[k + 13], S12, 0xFD987193);
				c = FF(c, d, a, b, x[k + 14], S13, 0xA679438E);
				b = FF(b, c, d, a, x[k + 15], S14, 0x49B40821);

				// Round 2
				a = GG(a, b, c, d, x[k + 1],  S21, 0xF61E2562);
				d = GG(d, a, b, c, x[k + 6],  S22, 0xC040B340);
				c = GG(c, d, a, b, x[k + 11], S23, 0x265E5A51);
				b = GG(b, c, d, a, x[k + 0],  S24, 0xE9B6C7AA);
				a = GG(a, b, c, d, x[k + 5],  S21, 0xD62F105D);
				d = GG(d, a, b, c, x[k + 10], S22, 0x02441453);
				c = GG(c, d, a, b, x[k + 15], S23, 0xD8A1E681);
				b = GG(b, c, d, a, x[k + 4],  S24, 0xE7D3FBC8);
				a = GG(a, b, c, d, x[k + 9],  S21, 0x21E1CDE6);
				d = GG(d, a, b, c, x[k + 14], S22, 0xC33707D6);
				c = GG(c, d, a, b, x[k + 3],  S23, 0xF4D50D87);
				b = GG(b, c, d, a, x[k + 8],  S24, 0x455A14ED);
				a = GG(a, b, c, d, x[k + 13], S21, 0xA9E3E905);
				d = GG(d, a, b, c, x[k + 2],  S22, 0xFCEFA3F8);
				c = GG(c, d, a, b, x[k + 7],  S23, 0x676F02D9);
				b = GG(b, c, d, a, x[k + 12], S24, 0x8D2A4C8A);

				// Round 3
				a = HH(a, b, c, d, x[k + 5],  S31, 0xFFFA3942);
				d = HH(d, a, b, c, x[k + 8],  S32, 0x8771F681);
				c = HH(c, d, a, b, x[k + 11], S33, 0x6D9D6122);
				b = HH(b, c, d, a, x[k + 14], S34, 0xFDE5380C);
				a = HH(a, b, c, d, x[k + 1],  S31, 0xA4BEEA44);
				d = HH(d, a, b, c, x[k + 4],  S32, 0x4BDECFA9);
				c = HH(c, d, a, b, x[k + 7],  S33, 0xF6BB4B60);
				b = HH(b, c, d, a, x[k + 10], S34, 0xBEBFBC70);
				a = HH(a, b, c, d, x[k + 13], S31, 0x289B7EC6);
				d = HH(d, a, b, c, x[k + 0],  S32, 0xEAA127FA);
				c = HH(c, d, a, b, x[k + 3],  S33, 0xD4EF3085);
				b = HH(b, c, d, a, x[k + 6],  S34, 0x04881D05);
				a = HH(a, b, c, d, x[k + 9],  S31, 0xD9D4D039);
				d = HH(d, a, b, c, x[k + 12], S32, 0xE6DB99E5);
				c = HH(c, d, a, b, x[k + 15], S33, 0x1FA27CF8);
				b = HH(b, c, d, a, x[k + 2],  S34, 0xC4AC5665);

				// Round 4
				a = II(a, b, c, d, x[k + 0],  S41, 0xF4292244);
				d = II(d, a, b, c, x[k + 7],  S42, 0x432AFF97);
				c = II(c, d, a, b, x[k + 14], S43, 0xAB9423A7);
				b = II(b, c, d, a, x[k + 5],  S44, 0xFC93A039);
				a = II(a, b, c, d, x[k + 12], S41, 0x655B59C3);
				d = II(d, a, b, c, x[k + 3],  S42, 0x8F0CCC92);
				c = II(c, d, a, b, x[k + 10], S43, 0xFFEFF47D);
				b = II(b, c, d, a, x[k + 1],  S44, 0x85845DD1);
				a = II(a, b, c, d, x[k + 8],  S41, 0x6FA87E4F);
				d = II(d, a, b, c, x[k + 15], S42, 0xFE2CE6E0);
				c = II(c, d, a, b, x[k + 6],  S43, 0xA3014314);
				b = II(b, c, d, a, x[k + 13], S44, 0x4E0811A1);
				a = II(a, b, c, d, x[k + 4],  S41, 0xF7537E82);
				d = II(d, a, b, c, x[k + 11], S42, 0xBD3AF235);
				c = II(c, d, a, b, x[k + 2],  S43, 0x2AD7D2BB);
				b = II(b, c, d, a, x[k + 9],  S44, 0xEB86D391);

				a += AA;
				b += BB;
				c += CC;
				d += DD;
			}
			return (wordToHex(a) + wordToHex(b) + wordToHex(c) + wordToHex(d)).toLowerCase();
		}

		// --- Core Transformations ---
		// 注意：AS3 的 int 加法会自动处理 32 位溢出，无需 AddUnsigned

		private static function rotateLeft(lValue:int, iShiftBits:int):int {
			return (lValue << iShiftBits) | (lValue >>> (32 - iShiftBits));
		}

		private static function FF(a:int, b:int, c:int, d:int, x:int, s:int, ac:int):int {
			// F = (x & y) | ((~x) & z)
			return rotateLeft(a + ((b & c) | ((~b) & d)) + x + ac, s) + b;
		}

		private static function GG(a:int, b:int, c:int, d:int, x:int, s:int, ac:int):int {
			// G = (x & z) | (y & (~z))
			return rotateLeft(a + ((b & d) | (c & (~d))) + x + ac, s) + b;
		}

		private static function HH(a:int, b:int, c:int, d:int, x:int, s:int, ac:int):int {
			// H = x ^ y ^ z
			return rotateLeft(a + (b ^ c ^ d) + x + ac, s) + b;
		}

		private static function II(a:int, b:int, c:int, d:int, x:int, s:int, ac:int):int {
			// I = y ^ (x | (~z))
			return rotateLeft(a + (c ^ (b | (~d))) + x + ac, s) + b;
		}

		// --- Helper Functions ---

		private static function convertToWordArray(string:String):Array {
			var lWordCount:int;
			var lMessageLength:int = string.length;
			var lNumberOfWords_temp1:int = lMessageLength + 8;
			var lNumberOfWords_temp2:int = (lNumberOfWords_temp1 - (lNumberOfWords_temp1 % 64)) / 64;
			var lNumberOfWords:int = (lNumberOfWords_temp2 + 1) * 16;
			var lWordArray:Array = new Array(lNumberOfWords - 1);
			var lBytePosition:int = 0;
			var lByteCount:int = 0;
			while (lByteCount < lMessageLength) {
				lWordCount = (lByteCount - (lByteCount % 4)) / 4;
				lBytePosition = (lByteCount % 4) * 8;
				if (lWordArray[lWordCount] == undefined) lWordArray[lWordCount] = 0;
				lWordArray[lWordCount] = (lWordArray[lWordCount] | (string.charCodeAt(lByteCount) << lBytePosition));
				lByteCount++;
			}
			lWordCount = (lByteCount - (lByteCount % 4)) / 4;
			lBytePosition = (lByteCount % 4) * 8;
			if (lWordArray[lWordCount] == undefined) lWordArray[lWordCount] = 0;
			lWordArray[lWordCount] = lWordArray[lWordCount] | (0x80 << lBytePosition);
			lWordArray[lNumberOfWords - 2] = lMessageLength << 3;
			lWordArray[lNumberOfWords - 1] = lMessageLength >>> 29;
			return lWordArray;
		}

		private static function wordToHex(lValue:int):String {
			var wordToHexValue:String = "";
			var lByte:int, lCount:int;
			for (lCount = 0; lCount <= 3; lCount++) {
				lByte = (lValue >>> (lCount * 8)) & 255;
				var hex:String = "0" + lByte.toString(16);
				wordToHexValue += hex.substr(hex.length - 2, 2);
			}
			return wordToHexValue;
		}

		private static function utf8Encode(string:String):String {
			string = string.replace(/\r\n/g, "\n");
			var utftext:String = "";
			for (var n:int = 0; n < string.length; n++) {
				var c:int = string.charCodeAt(n);
				if (c < 128) {
					utftext += String.fromCharCode(c);
				} else if ((c > 127) && (c < 2048)) {
					utftext += String.fromCharCode((c >> 6) | 192);
					utftext += String.fromCharCode((c & 63) | 128);
				} else {
					utftext += String.fromCharCode((c >> 12) | 224);
					utftext += String.fromCharCode(((c >> 6) & 63) | 128);
					utftext += String.fromCharCode((c & 63) | 128);
				}
			}
			return utftext;
		}
	}
}