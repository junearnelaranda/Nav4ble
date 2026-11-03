// On phones and desktop this runs the bundled YOLO model with TensorFlow
// Lite; on the web (no TFLite) it always reports "unavailable".
export 'on_device_detector_stub.dart'
    if (dart.library.ffi) 'on_device_detector_io.dart';
