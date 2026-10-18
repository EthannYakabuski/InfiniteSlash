extends RefCounted
## Godot's Android JNI bridge may expose a Java boolean as integer 0 or 1.
## Reject all other representations rather than coercing arbitrary truthy data.

static func sdk_boolean(value: Variant) -> bool:
	if value is bool: return value
	if value is int: return value == 1
	return false
