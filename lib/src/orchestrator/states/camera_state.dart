import 'dart:io';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:camerawesome/src/orchestrator/camera_context.dart';
import 'package:flutter/foundation.dart';

typedef OnVideoMode = Function(VideoCameraState);

typedef OnPhotoMode = Function(PhotoCameraState);

typedef OnPreparingCamera = Function(PreparingCameraState);

typedef OnVideoRecordingMode = Function(VideoRecordingCameraState);

typedef OnPreviewMode = Function(PreviewCameraState);

typedef OnAnalysisOnlyMode = Function(AnalysisCameraState);

abstract class CameraState {
  // TODO Make private
  @protected
  CameraContext cameraContext;

  CameraState(this.cameraContext);

  abstract final CaptureMode? captureMode;

  when({
    OnVideoMode? onVideoMode,
    OnPhotoMode? onPhotoMode,
    OnPreparingCamera? onPreparingCamera,
    OnVideoRecordingMode? onVideoRecordingMode,
    OnPreviewMode? onPreviewMode,
    OnAnalysisOnlyMode? onAnalysisOnlyMode,
  }) {
    return switch (this) {
      (VideoCameraState state) => onVideoMode?.call(state),
      (PhotoCameraState state) => onPhotoMode?.call(state),
      (PreparingCameraState state) => onPreparingCamera?.call(state),
      (VideoRecordingCameraState state) => onVideoRecordingMode?.call(state),
      (PreviewCameraState state) => onPreviewMode?.call(state),
      (AnalysisCameraState state) => onAnalysisOnlyMode?.call(state),
      CameraState() => null,
    };
  }

  /// Closes streams depending on the current state
  void dispose();

  /// Use this stream to listen for capture state
  /// - while recording a video
  /// - while saving an image
  /// Accessible from all states
  Stream<MediaCapture?> get captureState$ => cameraContext.captureState$;

  MediaCapture? get captureState => cameraContext.captureState;

  /// Switch camera from [Sensors.BACK] [Sensors.front]
  /// All states can switch this
  Future<void> switchCameraSensor({
    CameraAspectRatios? aspectRatio,
    double? zoom,
    FlashMode? flash,
    SensorType? type,
  }) async {
    final previous = cameraContext.sensorConfig;

    SensorConfig next;
    if (previous.sensors.length <= 1) {
      next = SensorConfig.single(
        sensor: previous.sensors.first.position == SensorPosition.back
            ? Sensor.position(SensorPosition.front)
            : Sensor.position(SensorPosition.back),
        // TODO Initial values are not set in native when set like this
        aspectRatio: aspectRatio ?? CameraAspectRatios.ratio_4_3,
        zoom: zoom ?? 0.0,
        flashMode: flash ?? FlashMode.none,
      );
    } else {
      // switch all camera position in array by one like this:
      // old: [front, telephoto, wide]
      // new : [wide, front, telephoto]
      final newSensorsCopy = [...previous.sensors.nonNulls];
      next = SensorConfig.multiple(
        sensors: newSensorsCopy
          ..insert(0, newSensorsCopy.removeAt(newSensorsCopy.length - 1)),
        // TODO Initial values are not set in native when set like this
        aspectRatio: aspectRatio ?? CameraAspectRatios.ratio_4_3,
        zoom: zoom ?? 0.0,
        flashMode: flash ?? FlashMode.none,
      );
    }
    await cameraContext.setSensorConfig(next);

    // TODO Once initial sensorConfig is correctly handled, we can remove below lines
    if (aspectRatio != null) {
      await next.setAspectRatio(aspectRatio);
    }
    if (zoom != null) {
      await next.setZoom(zoom);
    }
    if (flash != null) {
      await next.setFlashMode(flash);
    }
  }

  void setSensorType(int cameraPosition, SensorType type, String deviceId) {
    final previous = cameraContext.sensorConfig;
    int sensorIndex = 0;
    final next = SensorConfig.multiple(
      sensors: previous.sensors
          .map((sensor) {
            if (sensorIndex == cameraPosition) {
              if (sensor.type == SensorType.trueDepth) {
                sensor.position = SensorPosition.front;
              } else {
                sensor.position = SensorPosition.back;
              }

              sensor.deviceId = deviceId;
              sensor.type = type;
            }

            sensorIndex++;
            return sensor;
          })
          .nonNulls
          .toList(),
      aspectRatio: previous.aspectRatio,
      flashMode: previous.flashMode,
      zoom: type == SensorType.ultraWideAngle ? 0.0 : previous.zoom,
    );
    cameraContext.setSensorConfig(next);
    if (type == SensorType.wideAngle && Platform.isAndroid) {
      next.setZoomToOneX();
    }
  }

  // PigeonSensorType? _sensorTypeFromPigeon(SensorType type) {
  //   switch (type) {
  //     case SensorType.wideAngle:
  //       return PigeonSensorType.wideAngle;
  //     case SensorType.telephoto:
  //       return PigeonSensorType.telephoto;
  //     case SensorType.trueDepth:
  //       return PigeonSensorType.trueDepth;
  //     case SensorType.ultraWideAngle:
  //       return PigeonSensorType.ultraWideAngle;
  //     default:
  //       return null;
  //   }
  // }

  void toggleFilterSelector() {
    cameraContext.toggleFilterSelector();
  }

  Future<void> setFilter(AwesomeFilter newFilter) {
    return cameraContext.setFilter(newFilter);
  }

  /// The sensor config allows you to
  /// - set the [FlashMode]
  /// - set the zoom level
  /// - handle luminosity or get it
  /// - adjust brightness
  SensorConfig get sensorConfig => cameraContext.sensorConfig;

  Stream<SensorConfig> get sensorConfig$ => cameraContext.sensorConfig$;

  Stream<bool> get filterSelectorOpened$ => cameraContext.filterSelectorOpened$;

  Stream<AwesomeFilter> get filter$ => cameraContext.filter$;

  AwesomeFilter get filter => cameraContext.filterController.value;

  /// Switch to a state between
  /// - [CaptureMode.photo]
  /// - [CaptureMode.video]
  /// - [CaptureMode.ANALYSIS]
  void setState(CaptureMode captureMode);

  SaveConfig? get saveConfig => cameraContext.saveConfig;

  Future<PreviewSize> previewSize(int index) {
    return cameraContext.previewSize(index);
  }

  Future<SensorDeviceData> getSensors() {
    return cameraContext.getSensors();
  }

  Future<int?> previewTextureId(int cameraPosition) {
    return cameraContext.previewTextureId(cameraPosition);
  }

  AnalysisController? get analysisController =>
      cameraContext.analysisController;

  /// Increments zoom progressively or switches from ultra-wide (0.5x) to 1.0x optical zoom.
  Future<void> stepZoomIn() async {
    final currentZoom = sensorConfig.zoom;
    final minZoom = await CamerawesomePlugin.getMinZoom() ?? 1.0;
    final maxZoom = await CamerawesomePlugin.getMaxZoom() ?? 1.0;
    final hasLogicalUltraWide = defaultTargetPlatform != TargetPlatform.iOS &&
        minZoom > 0.0 &&
        minZoom < 1.0 &&
        maxZoom > minZoom;

    if (hasLogicalUltraWide) {
      final currentRatio = minZoom + (maxZoom - minZoom) * currentZoom;
      if (currentRatio < 0.95) {
        // From ultra-wide (e.g. 0.5x) -> step directly to 1.0x
        await sensorConfig.setZoomRatio(1.0);
      } else {
        // Above 1.0x, step geometrically (multiplicative ~35% zoom increase per step)
        // so that perceptual zoom change is constant and linear to the human eye.
        final nextRatio = currentRatio < 1.05 ? 1.5 : (currentRatio * 1.35);
        await sensorConfig.setZoomRatio(nextRatio);
      }
    } else {
      final isUltraWide =
          sensorConfig.sensors.firstOrNull?.type == SensorType.ultraWideAngle ||
              sensorConfig.sensorType == SensorType.ultraWideAngle;
      final sensors = await getSensors();
      if (isUltraWide && sensors.wideAngle != null) {
        setSensorType(0, SensorType.wideAngle, sensors.wideAngle!.uid);
        await sensorConfig.setZoom(0.0);
      } else {
        await sensorConfig.setZoom((currentZoom + 0.1).clamp(0.0, 1.0));
      }
    }
  }

  /// Decrements zoom progressively or switches down to ultra-wide (0.5x / minZoom).
  Future<void> stepZoomOut() async {
    final currentZoom = sensorConfig.zoom;
    final minZoom = await CamerawesomePlugin.getMinZoom() ?? 1.0;
    final maxZoom = await CamerawesomePlugin.getMaxZoom() ?? 1.0;
    final hasLogicalUltraWide = defaultTargetPlatform != TargetPlatform.iOS &&
        minZoom > 0.0 &&
        minZoom < 1.0 &&
        maxZoom > minZoom;

    if (hasLogicalUltraWide) {
      final currentRatio = minZoom + (maxZoom - minZoom) * currentZoom;
      if (currentRatio > 1.25) {
        final nextRatio = currentRatio / 1.35;
        if (nextRatio <= 1.15) {
          // Snap cleanly to 1.0x optical zoom
          await sensorConfig.setZoomRatio(1.0);
        } else {
          await sensorConfig.setZoomRatio(nextRatio);
        }
      } else if (currentRatio > 0.95) {
        // From 1.0x -> step down to ultra-wide minZoom (0.5x)
        await sensorConfig.setZoomRatio(minZoom);
      } else {
        await sensorConfig.setZoom(0.0);
      }
    } else {
      final isBackCamera =
          sensorConfig.sensors.firstOrNull?.position != SensorPosition.front;
      final isUltraWide =
          sensorConfig.sensors.firstOrNull?.type == SensorType.ultraWideAngle ||
              sensorConfig.sensorType == SensorType.ultraWideAngle;
      if (currentZoom > 0.05) {
        await sensorConfig.setZoom((currentZoom - 0.1).clamp(0.0, 1.0));
      } else if (isBackCamera && !isUltraWide) {
        final sensors = await getSensors();
        if (sensors.ultraWideAngle != null) {
          setSensorType(
            0,
            SensorType.ultraWideAngle,
            sensors.ultraWideAngle!.uid,
          );
          await sensorConfig.setZoom(0.0);
        }
      }
    }
  }
}
