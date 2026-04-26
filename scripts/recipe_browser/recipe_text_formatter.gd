class_name RecipeTextFormatter
extends RefCounted


static func format_optional(value: String, fallback: String = "无") -> String:
	var trimmed: String = value.strip_edges()
	return fallback if trimmed.is_empty() else trimmed
