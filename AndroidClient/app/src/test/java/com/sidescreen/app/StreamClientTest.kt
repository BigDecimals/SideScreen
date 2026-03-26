package com.sidescreen.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class StreamClientTest {

    @Test
    fun testBufferPool_acquireNewBufferWhenEmpty() {
        val client = StreamClient("localhost", 1234)
        val buffer = client.acquireBuffer(100)

        assertEquals(100, buffer.size)
        assertTrue(client.bufferPool.isEmpty())
    }

    @Test
    fun testBufferPool_releaseBufferAndReuse() {
        val client = StreamClient("localhost", 1234)
        val originalBuffer = client.acquireBuffer(100)

        // Release it back
        client.releaseBuffer(originalBuffer)
        assertEquals(1, client.bufferPool.size)

        // Acquire again, should be the exact same instance
        val reusedBuffer = client.acquireBuffer(100)
        assertSame(originalBuffer, reusedBuffer)
        assertTrue(client.bufferPool.isEmpty())
    }

    @Test
    fun testBufferPool_acquireNewBufferWhenRequestedSizeIsLarger() {
        val client = StreamClient("localhost", 1234)
        val smallBuffer = client.acquireBuffer(100)
        client.releaseBuffer(smallBuffer)

        // Request a larger buffer, should get a new one
        val largeBuffer = client.acquireBuffer(200)
        assertEquals(200, largeBuffer.size)
        assertNotSame(smallBuffer, largeBuffer)

        // The small buffer should still be in the pool
        assertEquals(1, client.bufferPool.size)
    }

    @Test
    fun testBufferPool_maxSizeLimit() {
        val client = StreamClient("localhost", 1234)

        // Create and release 10 buffers
        for (i in 1..10) {
            val buffer = ByteArray(100)
            client.releaseBuffer(buffer)
        }

        // The pool should cap at 8 (the configured limit)
        assertEquals(8, client.bufferPool.size)
    }

    @Test
    fun testBufferPool_acquireReturnsFirstSufficientBuffer() {
        val client = StreamClient("localhost", 1234)

        client.releaseBuffer(ByteArray(500))
        client.releaseBuffer(ByteArray(200)) // This one is smaller but sufficient
        client.releaseBuffer(ByteArray(100)) // This one is too small

        val buffer = client.acquireBuffer(150)

        // It currently just finds the first buffer that is large enough in the ArrayDeque.
        // It iterates over bufferPool.iterator() which gives elements in the order they were added.
        // So the first one added that is >= minSize is returned.
        // In our case, that is the 500 byte array.
        assertEquals(500, buffer.size)

        // Pool should now have the other two left
        assertEquals(2, client.bufferPool.size)
    }
}
