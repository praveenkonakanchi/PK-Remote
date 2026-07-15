package com.praveenkonakanchi.pkremote

import com.praveenkonakanchi.pkremote.model.RemoteDevice
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RemoteDeviceTest {
    @Test
    fun discoveredDeviceUsesStableNormalizedBonjourIdentity() {
        val first = RemoteDevice.discovered(" Peekay TV ", "_ANDROIDTVREMOTE2._TCP.")
        val second = RemoteDevice.discovered("Peekay TV", "_androidtvremote2._tcp")

        assertEquals(first?.id, second?.id)
        assertEquals("Peekay TV", first?.name)
        assertEquals("_androidtvremote2._tcp", first?.serviceType)
        assertNull(first?.endpointHost)
        assertNull(first?.remotePort)
    }

    @Test
    fun incompleteServiceCannotBecomeADevice() {
        assertNull(RemoteDevice.discovered("", "_androidtvremote2._tcp."))
        assertNull(RemoteDevice.discovered("TV", null))
    }
}
