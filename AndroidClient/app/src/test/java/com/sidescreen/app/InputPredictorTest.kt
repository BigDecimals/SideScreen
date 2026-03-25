package com.sidescreen.app

import android.os.SystemClock
import io.mockk.every
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class InputPredictorTest {

    private lateinit var predictor: InputPredictor
    private var currentTimeNanos: Long = 0

    @Before
    fun setup() {
        predictor = InputPredictor()

        // Mock SystemClock
        mockkStatic(SystemClock::class)
        every { SystemClock.elapsedRealtimeNanos() } answers { currentTimeNanos }
    }

    @After
    fun teardown() {
        unmockkAll()
    }

    private fun addSample(x: Float, y: Float, timeAdvanceMs: Long) {
        currentTimeNanos += timeAdvanceMs * 1_000_000L
        predictor.addSample(x, y)
    }

    @Test
    fun `predictPosition returns zero when no history`() {
        val (x, y) = predictor.predictPosition(10f)
        assertEquals(0f, x, 0.001f)
        assertEquals(0f, y, 0.001f)
    }

    @Test
    fun `predictPosition returns last position when only one sample`() {
        addSample(10f, 20f, 0)
        val (x, y) = predictor.predictPosition(10f)
        assertEquals(10f, x, 0.001f)
        assertEquals(20f, y, 0.001f)
    }

    @Test
    fun `predictPosition correctly extrapolates linear movement`() {
        // Move from (0,0) to (10,10) over 10ms. Velocity = 1 unit/ms
        addSample(0f, 0f, 0)
        addSample(10f, 10f, 10)

        // Predict 5ms into future. Expected: (15, 15)
        val (x, y) = predictor.predictPosition(5f)
        assertEquals(15f, x, 0.001f)
        assertEquals(15f, y, 0.001f)
    }

    @Test
    fun `predictPosition handles noise filtering for very close samples`() {
        // Move slightly over a very small time (dt < 0.1ms)
        addSample(0f, 0f, 0)
        addSample(1f, 1f, 0) // Advanced 0ms, simulating noise/duplicates

        // Should return last known position, no extrapolation
        val (x, y) = predictor.predictPosition(10f)
        assertEquals(1f, x, 0.001f)
        assertEquals(1f, y, 0.001f)
    }

    @Test
    fun `getCurrentVelocity calculates velocity correctly`() {
        // Velocity should be 0 when history < 2
        val (vx0, vy0) = predictor.getCurrentVelocity()
        assertEquals(0f, vx0, 0.001f)
        assertEquals(0f, vy0, 0.001f)

        // Move from (0,0) to (100,200) over 100ms (0.1s)
        // Velocity: vx = 100 / 0.1 = 1000 units/s, vy = 200 / 0.1 = 2000 units/s
        addSample(0f, 0f, 0)
        addSample(100f, 200f, 100)

        val (vx, vy) = predictor.getCurrentVelocity()
        assertEquals(1000f, vx, 0.001f)
        assertEquals(2000f, vy, 0.001f)
    }

    @Test
    fun `getCurrentVelocity returns zero when time delta is zero`() {
        addSample(0f, 0f, 0)
        addSample(100f, 200f, 0) // No time advanced

        val (vx, vy) = predictor.getCurrentVelocity()
        assertEquals(0f, vx, 0.001f)
        assertEquals(0f, vy, 0.001f)
    }

    @Test
    fun `reset clears history`() {
        addSample(10f, 20f, 0)
        predictor.reset()

        // Should act like no history
        val (x, y) = predictor.predictPosition(10f)
        assertEquals(0f, x, 0.001f)
        assertEquals(0f, y, 0.001f)
    }

    @Test
    fun `history maintains maximum capacity of 5 samples`() {
        // Add 6 samples
        addSample(10f, 10f, 10)
        addSample(20f, 20f, 10)
        addSample(30f, 30f, 10)
        addSample(40f, 40f, 10)
        addSample(50f, 50f, 10)

        // This 6th sample should cause the 1st one to be dropped
        addSample(60f, 60f, 10)

        // Velocity should be calculated from the last 2 samples (5th and 6th)
        // (50,50) to (60,60) over 10ms. dt = 10ms = 0.01s. Velocity = 10 / 0.01 = 1000
        val (vx, vy) = predictor.getCurrentVelocity()
        assertEquals(1000f, vx, 0.001f)
        assertEquals(1000f, vy, 0.001f)

        // Extrapolate 10ms into the future. Velocity is 1 unit/ms.
        // Last position is (60,60). Expected: (70, 70)
        val (x, y) = predictor.predictPosition(10f)
        assertEquals(70f, x, 0.001f)
        assertEquals(70f, y, 0.001f)
    }
}
