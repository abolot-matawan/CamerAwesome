import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SensorDeviceData correctly filters available sensors', () {
    final sensorData = SensorDeviceData(
      ultraWideAngle: SensorTypeDevice(
        sensorType: SensorType.ultraWideAngle,
        name: 'Ultra Wide',
        iso: 100,
        flashAvailable: false,
        uid: '0:ultrawide',
      ),
      wideAngle: SensorTypeDevice(
        sensorType: SensorType.wideAngle,
        name: 'Wide',
        iso: 100,
        flashAvailable: true,
        uid: '0',
      ),
    );

    expect(sensorData.availableBackSensors, 2);
    expect(sensorData.availableSensors.length, 2);
    expect(sensorData.ultraWideAngle, isNotNull);
    expect(sensorData.wideAngle, isNotNull);
  });

  test('SensorConfig initialization with default and custom values', () {
    final sensorConfig = SensorConfig.single(
      zoom: 0.0,
      flashMode: FlashMode.none,
    );

    expect(sensorConfig.zoom, 0.0);
    expect(sensorConfig.flashMode, FlashMode.none);
    expect(sensorConfig.aspectRatio, CameraAspectRatios.ratio_4_3);

    sensorConfig.dispose();
  });
}
