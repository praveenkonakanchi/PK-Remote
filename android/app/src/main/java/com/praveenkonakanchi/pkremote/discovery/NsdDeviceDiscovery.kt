package com.praveenkonakanchi.pkremote.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.praveenkonakanchi.pkremote.model.RemoteDevice
import java.util.ArrayDeque

class NsdDeviceDiscovery(
    context: Context,
    private val handler: Handler = Handler(Looper.getMainLooper()),
) : DeviceDiscovery {
    private val applicationContext = context.applicationContext
    private val nsdManager = applicationContext.getSystemService(NsdManager::class.java)
    private val wifiManager = applicationContext.getSystemService(WifiManager::class.java)
    private var currentSession: Session? = null

    override fun start(onEvent: (DeviceDiscoveryEvent) -> Unit) {
        stop()

        val session = Session(
            onEvent = onEvent,
            multicastLock = wifiManager.createMulticastLock(MulticastLockTag).apply {
                setReferenceCounted(false)
                acquire()
            },
        )
        val listener = listener(session = session)
        session.listener = listener
        currentSession = session

        try {
            nsdManager.discoverServices(ServiceType, NsdManager.PROTOCOL_DNS_SD, listener)
        } catch (error: RuntimeException) {
            fail(session, "Could not start TV discovery. ${error.message.orEmpty()}".trim())
        }
    }

    override fun stop() {
        val session = currentSession ?: return
        currentSession = null
        session.stopRequested = true
        cancelEmptySnapshot(session)
        releaseLock(session)
        if (session.started) stopServiceDiscovery(session)
    }

    private fun listener(session: Session) = object : NsdManager.DiscoveryListener {
        override fun onDiscoveryStarted(serviceType: String) = onMain {
            session.started = true
            if (session.stopRequested) {
                stopServiceDiscovery(session)
            } else if (currentSession === session) {
                scheduleEmptySnapshot(session)
            }
        }

        override fun onServiceFound(serviceInfo: NsdServiceInfo) = onMain {
            if (currentSession !== session || session.stopRequested) return@onMain
            val device = RemoteDevice.discovered(
                serviceName = serviceInfo.serviceName,
                serviceType = serviceInfo.serviceType,
            ) ?: return@onMain
            if (device.serviceType != NormalizedServiceType) return@onMain
            Log.d(LogTag, "Found ${device.name}; resolving current endpoint")
            session.lostDeviceIds.remove(device.id)
            if (session.devices.containsKey(device.id) ||
                session.resolving?.device?.id == device.id ||
                session.pendingResolutions.any { it.device.id == device.id }
            ) {
                return@onMain
            }
            session.pendingResolutions.addLast(PendingResolution(device, serviceInfo))
            resolveNext(session)
        }

        override fun onServiceLost(serviceInfo: NsdServiceInfo) = onMain {
            if (currentSession !== session || session.stopRequested) return@onMain
            val device = RemoteDevice.discovered(
                serviceName = serviceInfo.serviceName,
                serviceType = serviceInfo.serviceType,
            ) ?: return@onMain
            Log.d(LogTag, "Lost ${device.name}")
            session.lostDeviceIds.add(device.id)
            session.pendingResolutions.removeIf { it.device.id == device.id }
            if (session.devices.remove(device.id) != null) publish(session)
        }

        override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) = onMain {
            fail(session, discoveryError("Could not start TV discovery", errorCode))
        }

        override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) = onMain {
            cancelEmptySnapshot(session)
            releaseLock(session)
        }

        override fun onDiscoveryStopped(serviceType: String) = onMain {
            cancelEmptySnapshot(session)
            releaseLock(session)
        }
    }

    private fun scheduleEmptySnapshot(session: Session) {
        val timeout = Runnable {
            if (currentSession === session && session.devices.isEmpty()) publish(session)
        }
        session.emptySnapshotTimeout = timeout
        handler.postDelayed(timeout, EmptySnapshotDelayMillis)
    }

    private fun cancelEmptySnapshot(session: Session) {
        session.emptySnapshotTimeout?.let(handler::removeCallbacks)
        session.emptySnapshotTimeout = null
    }

    private fun publish(session: Session) {
        cancelEmptySnapshot(session)
        val devices = session.devices.values.sortedWith(
            compareBy(String.CASE_INSENSITIVE_ORDER) { it.name },
        )
        session.onEvent(DeviceDiscoveryEvent.Snapshot(devices))
    }

    @Suppress("DEPRECATION")
    private fun resolveNext(session: Session) {
        if (currentSession !== session || session.stopRequested || session.resolving != null) return
        val pending = session.pendingResolutions.pollFirst() ?: return
        session.resolving = pending

        try {
            nsdManager.resolveService(pending.serviceInfo, object : NsdManager.ResolveListener {
                override fun onServiceResolved(serviceInfo: NsdServiceInfo) = onMain {
                    if (session.resolving !== pending) return@onMain
                    session.resolving = null
                    if (currentSession === session &&
                        !session.stopRequested &&
                        pending.device.id !in session.lostDeviceIds &&
                        serviceInfo.host != null &&
                        serviceInfo.port > 0
                    ) {
                        val resolvedDevice = pending.device.copy(
                            endpointHost = serviceInfo.host.hostAddress,
                            remotePort = serviceInfo.port,
                        )
                        Log.d(
                            LogTag,
                            "Resolved ${resolvedDevice.name} at ${resolvedDevice.endpointHost}:${resolvedDevice.remotePort}",
                        )
                        session.devices[resolvedDevice.id] = resolvedDevice
                        publish(session)
                    }
                    resolveNext(session)
                }

                override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) = onMain {
                    if (session.resolving !== pending) return@onMain
                    Log.d(LogTag, "Could not resolve ${pending.device.name} (NSD error $errorCode)")
                    session.resolving = null
                    resolveNext(session)
                }
            })
        } catch (error: RuntimeException) {
            Log.d(LogTag, "Could not resolve ${pending.device.name}", error)
            session.resolving = null
            resolveNext(session)
        }
    }

    private fun fail(session: Session, message: String) {
        val isCurrentSession = currentSession === session
        if (isCurrentSession) currentSession = null
        cancelEmptySnapshot(session)
        releaseLock(session)
        if (isCurrentSession && !session.stopRequested) {
            session.onEvent(DeviceDiscoveryEvent.Failed(message))
        }
    }

    private fun stopServiceDiscovery(session: Session) {
        try {
            nsdManager.stopServiceDiscovery(session.listener)
        } catch (_: IllegalArgumentException) {
            releaseLock(session)
        }
    }

    private fun releaseLock(session: Session) {
        if (session.multicastLock.isHeld) session.multicastLock.release()
    }

    private fun onMain(action: () -> Unit) {
        handler.post(action)
    }

    private class Session(
        val onEvent: (DeviceDiscoveryEvent) -> Unit,
        val multicastLock: WifiManager.MulticastLock,
    ) {
        lateinit var listener: NsdManager.DiscoveryListener
        val devices = linkedMapOf<String, RemoteDevice>()
        val pendingResolutions = ArrayDeque<PendingResolution>()
        val lostDeviceIds = mutableSetOf<String>()
        var resolving: PendingResolution? = null
        var started = false
        var stopRequested = false
        var emptySnapshotTimeout: Runnable? = null
    }

    private data class PendingResolution(
        val device: RemoteDevice,
        val serviceInfo: NsdServiceInfo,
    )

    companion object {
        const val ServiceType = "_androidtvremote2._tcp."
        const val NormalizedServiceType = "_androidtvremote2._tcp"
        private const val MulticastLockTag = "pk-remote-nsd"
        private const val LogTag = "PKRemoteDiscovery"
        private const val EmptySnapshotDelayMillis = 4_000L

        private fun discoveryError(prefix: String, errorCode: Int): String =
            "$prefix (NSD error $errorCode). Check Wi-Fi and try again."
    }
}
