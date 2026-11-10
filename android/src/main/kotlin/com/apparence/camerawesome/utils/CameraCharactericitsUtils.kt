package com.apparence.camerawesome.utils

import android.hardware.camera2.CameraCharacteristics
import android.util.Size
import android.util.SizeF
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.CameraSelector.LENS_FACING_BACK
import com.apparence.camerawesome.cameraX.PigeonSensorPosition
import com.apparence.camerawesome.cameraX.PigeonSensorType
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

// 35mm film format diagonal: sqrt(36^2 + 24^2) ≈ 43.2666mm
const val DIAGONAL_35MM = 43.2666f

/**
 * Calculates the 35mm-equivalent focal length for the given camera.
 */
@ExperimentalCamera2Interop
fun Camera2CameraInfo.getEquivalentFocalLength(): Float? {
    val focalLengths = this.getCameraCharacteristic(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
        ?: return null
    val sensorSize = this.getCameraCharacteristic(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
        ?: return null

    if (sensorSize.width <= 0f || sensorSize.height <= 0f || focalLengths.isEmpty()) {
        return null
    }

    val sensorDiagonal = sqrt(sensorSize.width * sensorSize.width + sensorSize.height * sensorSize.height)
    if (sensorDiagonal <= 0f) return null

    val cropFactor = DIAGONAL_35MM / sensorDiagonal
    val focalLength = focalLengths.minOrNull() ?: return null
    return focalLength * cropFactor
}

/**
 * Converts focal lengths and sensor dimensions to the corresponding [PigeonSensorType].
 *
 * * < 24mm : Ultra-Wide Angle
 * * 24mm..45mm : Wide Angle (standard main camera)
 * * > 45mm : Telephoto
 */
@ExperimentalCamera2Interop
fun Camera2CameraInfo.getSensorType(): PigeonSensorType {
    val eqFocal = getEquivalentFocalLength() ?: return PigeonSensorType.UNKNOWN
    return when {
        eqFocal < 24f -> PigeonSensorType.ULTRAWIDEANGLE
        eqFocal in 24f..45f -> PigeonSensorType.WIDEANGLE
        eqFocal > 45f -> PigeonSensorType.TELEPHOTO
        else -> PigeonSensorType.UNKNOWN
    }
}

@ExperimentalCamera2Interop
fun Camera2CameraInfo.getPigeonPosition(): PigeonSensorPosition {
    val facing = this.getCameraCharacteristic(CameraCharacteristics.LENS_FACING)
    return if (facing == LENS_FACING_BACK)
        PigeonSensorPosition.BACK
    else
        PigeonSensorPosition.FRONT
}

@ExperimentalCamera2Interop
fun Camera2CameraInfo.getIso(): Double {
    val sensitivityRange = this.getCameraCharacteristic(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
    return sensitivityRange?.upper?.toDouble() ?: 0.0
}

@ExperimentalCamera2Interop
fun Camera2CameraInfo.hasFlash(): Boolean {
    return this.getCameraCharacteristic(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false
}

@ExperimentalCamera2Interop
fun Camera2CameraInfo.getMinZoomRatio(): Float {
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
        val range = this.getCameraCharacteristic(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
        if (range != null) {
            return range.lower
        }
    }
    return 1.0f
}

val Size.bigger: Int
    get() = max(this.width, this.height)
val Size.smaller: Int
    get() = min(this.width, this.height)

val SizeF.bigger: Float
    get() = max(this.width, this.height)
val SizeF.smaller: Float
    get() = min(this.width, this.height)
