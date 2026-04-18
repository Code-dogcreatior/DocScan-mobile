package com.example.docscan_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.max

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "docscan/native_detect"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "detectDocumentBoxFromY") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val width = call.argument<Int>("width") ?: 0
                    val height = call.argument<Int>("height") ?: 0
                    val bytesPerRow = call.argument<Int>("bytesPerRow") ?: 0
                    val maxLongEdge = call.argument<Int>("maxLongEdge") ?: 320
                    val edgeThreshold = call.argument<Int>("edgeThreshold") ?: 40
                    val yPlane = call.argument<ByteArray>("yPlane")
                    if (width <= 0 || height <= 0 || bytesPerRow <= 0 || yPlane == null) {
                        result.success(mapOf("ok" to false, "message" to "invalid_args"))
                        return@setMethodCallHandler
                    }
                    val box = detectBoxFromY(
                        yPlane = yPlane,
                        width = width,
                        height = height,
                        bytesPerRow = bytesPerRow,
                        maxLongEdge = maxLongEdge,
                        edgeThreshold = edgeThreshold,
                    )
                    if (box == null) {
                        result.success(mapOf("ok" to false, "message" to "no_box"))
                    } else {
                        result.success(
                            mapOf(
                                "ok" to true,
                                "minX" to box.minX,
                                "minY" to box.minY,
                                "maxX" to box.maxX,
                                "maxY" to box.maxY,
                            )
                        )
                    }
                } catch (e: Exception) {
                    result.success(mapOf("ok" to false, "message" to (e.message ?: "native_error")))
                }
            }
    }

    private data class Box(val minX: Double, val minY: Double, val maxX: Double, val maxY: Double)

    private fun detectBoxFromY(
        yPlane: ByteArray,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        maxLongEdge: Int,
        edgeThreshold: Int,
    ): Box? {
        val longEdge = max(width, height)
        val scale = longEdge.toDouble() / maxLongEdge.toDouble()
        val tw = max(1, (width / scale).toInt())
        val th = max(1, (height / scale).toInt())
        var minX = tw
        var minY = th
        var maxX = 0
        var maxY = 0
        var count = 0

        // Fast Sobel-like gradient on Y thumbnail.
        for (ty in 1 until th - 1) {
            val sy = (ty * height) / th
            val syPrev = ((ty - 1) * height) / th
            val syNext = ((ty + 1) * height) / th
            val row = sy * bytesPerRow
            val rowPrev = syPrev * bytesPerRow
            val rowNext = syNext * bytesPerRow
            for (tx in 1 until tw - 1) {
                val sx = (tx * width) / tw
                val sxPrev = ((tx - 1) * width) / tw
                val sxNext = ((tx + 1) * width) / tw

                val gx =
                    ((yPlane[rowPrev + sxNext].toInt() and 0xFF) + 2 * (yPlane[row + sxNext].toInt() and 0xFF) + (yPlane[rowNext + sxNext].toInt() and 0xFF)) -
                        ((yPlane[rowPrev + sxPrev].toInt() and 0xFF) + 2 * (yPlane[row + sxPrev].toInt() and 0xFF) + (yPlane[rowNext + sxPrev].toInt() and 0xFF))
                val gy =
                    ((yPlane[rowNext + sxPrev].toInt() and 0xFF) + 2 * (yPlane[rowNext + sx].toInt() and 0xFF) + (yPlane[rowNext + sxNext].toInt() and 0xFF)) -
                        ((yPlane[rowPrev + sxPrev].toInt() and 0xFF) + 2 * (yPlane[rowPrev + sx].toInt() and 0xFF) + (yPlane[rowPrev + sxNext].toInt() and 0xFF))
                val mag = abs(gx) + abs(gy)
                if (mag > edgeThreshold * 8) {
                    count++
                    if (tx < minX) minX = tx
                    if (tx > maxX) maxX = tx
                    if (ty < minY) minY = ty
                    if (ty > maxY) maxY = ty
                }
            }
        }

        val minCount = max(120, (2000.0 * (tw * th).toDouble() / (width * height).toDouble()).toInt())
        if (count < minCount || minX >= maxX || minY >= maxY) {
            return null
        }
        val sx = width.toDouble() / tw.toDouble()
        val sy = height.toDouble() / th.toDouble()
        return Box(
            minX = minX * sx,
            minY = minY * sy,
            maxX = maxX * sx,
            maxY = maxY * sy,
        )
    }
}
