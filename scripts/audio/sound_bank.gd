class_name SoundBank
extends Resource
## Banco de sons pré-gerado (0.21): efeitos, trilha e tema do guardião já sintetizados
## (tools/bake_audio.tscn). O jogo só carrega o arquivo: sem síntese nem threads no
## celular, então a música toca até no modo de compatibilidade.

@export var streams: Dictionary = {}
@export var music: AudioStreamWAV
@export var boss: AudioStreamWAV
