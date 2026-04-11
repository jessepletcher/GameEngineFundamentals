extends TextureRect

@export var h_frames: int = 12
@export var v_frames: int = 1
@export var fps: float = 8.0

var _time := 0.0
var _frame := 0
var _atlas: AtlasTexture
var _source: Texture2D

func _ready() -> void:
	_source = texture
	_atlas = AtlasTexture.new()
	_atlas.atlas = _source
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture = _atlas
	_update_frame()

func _process(delta: float) -> void:
	_time += delta * fps
	if _time >= 1.0:
		_time -= 1.0
		_frame = (_frame + 1) % (h_frames * v_frames)
		_update_frame()

func _update_frame() -> void:
	var fw = _source.get_width() / h_frames
	var fh = _source.get_height() / v_frames
	var col = _frame % h_frames
	var row = _frame / h_frames
	_atlas.region = Rect2(col * fw, row * fh, fw, fh)
