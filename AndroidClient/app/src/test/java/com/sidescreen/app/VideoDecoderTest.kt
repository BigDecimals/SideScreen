package com.sidescreen.app

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecInfo.CodecCapabilities
import android.media.MediaCodecInfo.VideoCapabilities
import android.media.MediaCodecList
import android.media.MediaFormat
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import android.view.Display
import android.view.Surface
import io.mockk.*
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.Assert.assertEquals

class VideoDecoderTest {

    private lateinit var surface: Surface
    private lateinit var display: Display
    private lateinit var mockCodec: MediaCodec
    private lateinit var mockHandlerThread: HandlerThread
    private lateinit var mockLooper: Looper

    @Before
    fun setup() {
        mockkStatic(Log::class)
        every { Log.d(any(), any()) } returns 0
        every { Log.e(any(), any()) } returns 0
        every { Log.e(any(), any(), any()) } returns 0

        mockkObject(DiagLog)
        every { DiagLog.log(any(), any()) } returns Unit

        surface = mockk(relaxed = true)
        display = mockk(relaxed = true)
        every { display.refreshRate } returns 60f
        every { surface.isValid } returns true

        mockCodec = mockk(relaxed = true)
        mockkStatic(MediaCodec::class)
        every { MediaCodec.createDecoderByType(any()) } returns mockCodec
        every { MediaCodec.createByCodecName(any()) } returns mockCodec

        mockkStatic(MediaFormat::class)
        val mockFormat = mockk<MediaFormat>(relaxed = true)
        every { MediaFormat.createVideoFormat(any(), any(), any()) } returns mockFormat

        mockkConstructor(MediaCodecList::class)
        every { anyConstructed<MediaCodecList>().codecInfos } returns arrayOf()

        mockHandlerThread = mockk(relaxed = true)
        mockLooper = mockk(relaxed = true)
        mockkConstructor(HandlerThread::class)
        every { anyConstructed<HandlerThread>().start() } returns Unit
        every { anyConstructed<HandlerThread>().looper } returns mockLooper
        every { anyConstructed<HandlerThread>().quitSafely() } returns true

        mockkConstructor(Handler::class)
    }

    @After
    fun teardown() {
        unmockkAll()
    }

    @Test
    fun testUpdateResolution() {
        // Initialize decoder
        val decoder = spyk(VideoDecoder(surface, display, 1920, 1080), recordPrivateCalls = true)

        // Reset tracking so we only track calls from updateResolution
        clearMocks(decoder, answers = false, recordedCalls = true, childMocks = false)

        // Case 1: Same resolution. Should NOT release or setupDecoder again.
        decoder.updateResolution(1920, 1080)
        verify(exactly = 0) { decoder.release() }
        verify(exactly = 0) { decoder["setupDecoder"]() }

        // Case 2: Different resolution. Should call release() and setupDecoder().
        decoder.updateResolution(1280, 720)
        verify(exactly = 1) { decoder.release() }
        verify(exactly = 1) { decoder["setupDecoder"]() }

        // Clear tracking
        clearMocks(decoder, answers = false, recordedCalls = true, childMocks = false)

        // Case 3: Update again to a new resolution.
        decoder.updateResolution(2560, 1440)
        verify(exactly = 1) { decoder.release() }
        verify(exactly = 1) { decoder["setupDecoder"]() }
    }
}
