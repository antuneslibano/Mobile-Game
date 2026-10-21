class_name ChunkData
extends RefCounted
## Micro-células de um chunk: WORLD_CELLS_X × CHUNK_CELLS_Y.
## ids = material; dmg = desgaste parcial (0..254, 255 nunca é usado). Desgaste não é salvo.

var index: int = 0
var ids: PackedByteArray
var dmg: PackedByteArray


func _init(p_index: int, p_ids: PackedByteArray) -> void:
	index = p_index
	ids = p_ids
	dmg = PackedByteArray()
	dmg.resize(ids.size())
