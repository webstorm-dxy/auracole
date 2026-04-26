extends RefCounted
class_name OperationHistory

var _operations: Array[Dictionary] = []


func is_empty() -> bool:
	return _operations.is_empty()


func push(operation: Dictionary) -> void:
	_operations.append(operation)


func pop() -> Dictionary:
	if _operations.is_empty():
		return {}
	return _operations.pop_back()


func clear() -> void:
	_operations.clear()


func remove_matching(type_value: int, key: String, value: Variant) -> void:
	for index in range(_operations.size() - 1, -1, -1):
		var operation: Dictionary = _operations[index]
		if int(operation.get("type", -1)) != type_value:
			continue
		if operation.get(key) == value:
			_operations.remove_at(index)
