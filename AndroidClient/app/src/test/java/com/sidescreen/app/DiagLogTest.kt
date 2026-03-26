package com.sidescreen.app

import android.content.Context
import android.util.Log
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

class DiagLogTest {

    private lateinit var tempDir: File

    @Before
    fun setup() {
        tempDir = Files.createTempDirectory("diaglog_test").toFile()
        mockkStatic(Log::class)
        every { Log.d(any(), any()) } returns 0
    }

    @After
    fun teardown() {
        tempDir.deleteRecursively()
        unmockkAll()

        // Reset DiagLog logFile via reflection since it's private
        val logFileField = DiagLog::class.java.getDeclaredField("logFile")
        logFileField.isAccessible = true
        logFileField.set(DiagLog, null)
    }

    @Test
    fun testInitSetsLogFile() {
        val mockContext = mockk<Context>()
        every { mockContext.filesDir } returns tempDir

        DiagLog.init(mockContext)

        // Reflection to verify it was set
        val logFileField = DiagLog::class.java.getDeclaredField("logFile")
        logFileField.isAccessible = true
        val logFile = logFileField.get(DiagLog) as File

        assertEquals(File(tempDir, "diag.log").absolutePath, logFile.absolutePath)
    }

    @Test
    fun testLogAppendsToFile() {
        val mockContext = mockk<Context>()
        every { mockContext.filesDir } returns tempDir
        DiagLog.init(mockContext)

        val logFile = File(tempDir, "diag.log")
        assertFalse(logFile.exists())

        DiagLog.log("TestTag", "TestMessage1")
        assertTrue(logFile.exists())
        val content1 = logFile.readText()
        assertTrue(content1.contains("TestTag: TestMessage1"))

        DiagLog.log("TestTag", "TestMessage2")
        val content2 = logFile.readText()
        assertTrue(content2.contains("TestTag: TestMessage1"))
        assertTrue(content2.contains("TestTag: TestMessage2"))
    }

    @Test
    fun testLogRotatesWhenTooLarge() {
        val mockContext = mockk<Context>()
        every { mockContext.filesDir } returns tempDir
        DiagLog.init(mockContext)

        val logFile = File(tempDir, "diag.log")
        // Create a file just over MAX_LOG_SIZE
        logFile.writeBytes(ByteArray(1_048_576 + 1))
        assertTrue(logFile.exists())

        val backupFile = File(tempDir, "diag.log.old")
        assertFalse(backupFile.exists())

        DiagLog.log("TestTag", "RotatedMessage")

        assertTrue(logFile.exists())
        assertTrue(backupFile.exists())
        assertEquals(1_048_576L + 1L, backupFile.length())

        val newContent = logFile.readText()
        assertTrue(newContent.contains("TestTag: RotatedMessage"))
        assertTrue(newContent.length < 1000) // Should just be the new message
    }

    @Test
    fun testLogOverwritesOldBackup() {
        val mockContext = mockk<Context>()
        every { mockContext.filesDir } returns tempDir
        DiagLog.init(mockContext)

        val logFile = File(tempDir, "diag.log")
        // Create a file just over MAX_LOG_SIZE
        logFile.writeBytes(ByteArray(1_048_576 + 1))

        val backupFile = File(tempDir, "diag.log.old")
        backupFile.writeText("Old Backup")

        DiagLog.log("TestTag", "NewRotatedMessage")

        assertTrue(logFile.exists())
        assertTrue(backupFile.exists())
        assertEquals(1_048_576L + 1L, backupFile.length()) // Should be overwritten by the large file
    }

    @Test
    fun testLogHandlesExceptionsGracefully() {
        val mockContext = mockk<Context>()
        every { mockContext.filesDir } returns tempDir
        DiagLog.init(mockContext)

        val logFile = File(tempDir, "diag.log")
        // Create a directory where the log file should be, causing an exception when trying to write
        logFile.mkdir()

        // Should not crash
        DiagLog.log("TestTag", "TestMessage")

        assertTrue(logFile.isDirectory) // Ensure it didn't somehow overwrite the directory
    }

    @Test
    fun testLogDoesNothingIfUninitialized() {
        // Init was not called

        // Should not crash
        DiagLog.log("TestTag", "TestMessage")

        val logFile = File(tempDir, "diag.log")
        assertFalse(logFile.exists())
    }
}
