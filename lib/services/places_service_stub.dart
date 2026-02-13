/// Stub implementations of dart:js_util functions for native platforms.
/// These will be used on Android/iOS where JS interop doesn't exist.
/// The actual Places API calls should be wrapped in kIsWeb checks.

// Stub for globalThis - only available on web
Object get globalThis => throw UnsupportedError(
    'globalThis is only available on web platform. Use kIsWeb check.');

dynamic getProperty(Object o, Object name) => throw UnsupportedError(
    'getProperty is only available on web platform. Use kIsWeb check.');

bool hasProperty(Object o, Object name) => throw UnsupportedError(
    'hasProperty is only available on web platform. Use kIsWeb check.');

dynamic callMethod(Object o, String method, List<Object?> args) =>
    throw UnsupportedError(
        'callMethod is only available on web platform. Use kIsWeb check.');

T callConstructor<T>(Object constr, List<Object?>? arguments) =>
    throw UnsupportedError(
        'callConstructor is only available on web platform. Use kIsWeb check.');

dynamic jsify(Object? dartObject) => throw UnsupportedError(
    'jsify is only available on web platform. Use kIsWeb check.');

Future<T> promiseToFuture<T>(Object jsPromise) => throw UnsupportedError(
    'promiseToFuture is only available on web platform. Use kIsWeb check.');
