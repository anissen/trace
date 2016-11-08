package core.physics;

class Vector3D {
	public var x :Float;
	public var y :Float;
	public var z :Float;
	public var w :Float;

	public function new(x :Float = 0, y :Float = 0, z :Float = 0, w :Float = 0) {
		this.x = x;
		this.y = y;
		this.z = z;
		this.w = w;
	}

	public static function distance(p1 :Vector3D, p2 :Vector3D) :Float {
		var	xd = p2.x - p1.x;
		var	yd = p2.y - p1.y;
		var	zd = p2.z - p1.z;
		return Math.sqrt(xd * xd + yd * yd + zd * zd);
	}

	public function add(p2 :Vector3D) :Vector3D {
		return new Vector3D(p2.x + this.x, p2.y + this.y, p2.z + this.z, p2.w + this.w);
	}

	public function subtract(p2 :Vector3D) :Vector3D {
		return new Vector3D(p2.x - this.x, p2.y - this.y, p2.z - this.z, p2.w - this.w);
	}

	public function clone() :Vector3D {
		return new Vector3D(this.x, this.y, this.z, this.w);
	}

	public function scaleBy(s :Float) :Void {
		this.x *= s;
		this.y *= s;
		this.z *= s;
		this.w *= s;
	}
}
