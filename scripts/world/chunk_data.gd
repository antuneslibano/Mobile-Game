class_name ChunkData
extends RefCounted
## Dados de um chunk: faixa horizontal de WORLD_WIDTH × CHUNK_HEIGHT ids.

var index: int = 0
var ids: PackedByteArray


func _init(p_index: int, p_ids: PackedByteArray) -> void:
	index = p_index
	ids = p_ids


func get_local(x: int, ly: int) -> int:
	return ids[ly * Balance.WORLD_WIDTH + x]


func set_local(x: int, ly: int, id: int) -> void:
	ids[ly * Balance.WORLD_WIDTH + x] = id
