#include "peril_native.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void PerilNative::_bind_methods() {
	ClassDB::bind_static_method("PerilNative", D_METHOD("version"), &PerilNative::version);
}

String PerilNative::version() {
	return String("peril-native 1");
}
