import 'dart:js_util' as js_util;

void registerMapsApiReadyCallback(void Function() onReady) {
  js_util.setProperty(
    js_util.globalThis,
    'dartMapApiReadyCallback',
    js_util.allowInterop(onReady),
  );
}

bool googleMapsApiLoadedFlag() {
  final dynamic value = js_util.getProperty(js_util.globalThis, '_googleMapsLoaded');
  return value == true;
}
