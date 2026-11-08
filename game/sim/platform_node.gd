class_name PlatformNode
extends RefCounted

var id := 0
var kind := ""
var center := Vector2.ZERO
var size := 0.0
var links: Array[int] = [-1, -1, -1, -1]
var built := false
var parent_port := -1
var run := 0
