package com.sidescreen.app

import android.content.Context
import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.mockito.kotlin.*

class PreferencesManagerTest {

    private lateinit var context: Context
    private lateinit var sharedPrefs: SharedPreferences
    private lateinit var editor: SharedPreferences.Editor
    private lateinit var preferencesManager: PreferencesManager

    @Before
    fun setup() {
        context = mock()
        sharedPrefs = mock()
        editor = mock()

        whenever(context.getSharedPreferences("app_prefs", Context.MODE_PRIVATE)).thenReturn(sharedPrefs)
        whenever(sharedPrefs.edit()).thenReturn(editor)

        // Let the editor return itself when putting values to allow chaining (.apply())
        whenever(editor.putBoolean(any(), any())).thenReturn(editor)
        whenever(editor.putFloat(any(), any())).thenReturn(editor)
        whenever(editor.putInt(any(), any())).thenReturn(editor)

        preferencesManager = PreferencesManager(context)
    }

    @Test
    fun testShowStatsOverlay() {
        // Test default value
        whenever(sharedPrefs.getBoolean("show_stats", true)).thenReturn(true)
        assertEquals(true, preferencesManager.showStatsOverlay)

        // Test getting false
        whenever(sharedPrefs.getBoolean("show_stats", true)).thenReturn(false)
        assertEquals(false, preferencesManager.showStatsOverlay)

        // Test setter
        preferencesManager.showStatsOverlay = false
        verify(editor).putBoolean("show_stats", false)
        verify(editor).apply()
    }

    @Test
    fun testOverlayOpacity() {
        // Test default value
        whenever(sharedPrefs.getFloat("overlay_opacity", 0.8f)).thenReturn(0.8f)
        assertEquals(0.8f, preferencesManager.overlayOpacity, 0.0f)

        // Test setting a value
        preferencesManager.overlayOpacity = 0.5f
        verify(editor).putFloat("overlay_opacity", 0.5f)
        verify(editor).apply()
    }

    @Test
    fun testOverlayX() {
        whenever(sharedPrefs.getFloat("overlay_x", -1f)).thenReturn(-1f)
        assertEquals(-1f, preferencesManager.overlayX, 0.0f)

        preferencesManager.overlayX = 100f
        verify(editor).putFloat("overlay_x", 100f)
        verify(editor).apply()
    }

    @Test
    fun testOverlayY() {
        whenever(sharedPrefs.getFloat("overlay_y", -1f)).thenReturn(-1f)
        assertEquals(-1f, preferencesManager.overlayY, 0.0f)

        preferencesManager.overlayY = 200f
        verify(editor).putFloat("overlay_y", 200f)
        verify(editor).apply()
    }

    @Test
    fun testSettingsButtonX() {
        whenever(sharedPrefs.getFloat("settings_x", -1f)).thenReturn(-1f)
        assertEquals(-1f, preferencesManager.settingsButtonX, 0.0f)

        preferencesManager.settingsButtonX = 50f
        verify(editor).putFloat("settings_x", 50f)
        verify(editor).apply()
    }

    @Test
    fun testSettingsButtonY() {
        whenever(sharedPrefs.getFloat("settings_y", -1f)).thenReturn(-1f)
        assertEquals(-1f, preferencesManager.settingsButtonY, 0.0f)

        preferencesManager.settingsButtonY = 150f
        verify(editor).putFloat("settings_y", 150f)
        verify(editor).apply()
    }

    @Test
    fun testSettingsButtonCorner() {
        // 0=bottom-right, 1=bottom-left, 2=top-right, 3=top-left
        whenever(sharedPrefs.getInt("settings_corner", 0)).thenReturn(0)
        assertEquals(0, preferencesManager.settingsButtonCorner)

        whenever(sharedPrefs.getInt("settings_corner", 0)).thenReturn(2)
        assertEquals(2, preferencesManager.settingsButtonCorner)

        preferencesManager.settingsButtonCorner = 3
        verify(editor).putInt("settings_corner", 3)
        verify(editor).apply()
    }
}
