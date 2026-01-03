/// Web-specific implementation that exports globalThis from dart:js_interop.
/// This file is only imported on web platform.
@JS()
library;

import 'dart:js_interop';

/// Get the global JavaScript object (window in browsers).
@JS('globalThis')
external JSObject get _globalThis;

Object get globalThis => _globalThis;
