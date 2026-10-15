package org.smatkovi.bioquiz;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothServerSocket;
import android.bluetooth.BluetoothSocket;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Method;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.atomic.AtomicInteger;

// Classic Bluetooth (RFCOMM) for BioQuiz on Android, behind the same
// newline-delimited JSON link as the LAN game. C++ (src/BtLinkAndroid.cpp)
// calls the static methods; events come back through the native methods,
// always from a background thread.
//
// Two ways to meet a partner:
//  - Android to Android over the service UUID (SDP, public API);
//  - Sailfish OS / N9 listen and connect on the fixed RFCOMM channel without
//    SDP. Android reaches that channel only through hidden API, so those
//    calls go through reflection and may be refused by newer Android.
public final class BtBridge {
    private static final UUID SERVICE = UUID.fromString("8b2f6a3e-5d1c-4f7a-9e2b-b10c0a2f5e17");
    private static final String NAME = "BioQuiz";

    private static final AtomicInteger nextId = new AtomicInteger(1);
    private static final ConcurrentHashMap<Integer, Link> links = new ConcurrentHashMap<>();
    private static volatile BluetoothServerSocket uuidServer;
    private static volatile BluetoothServerSocket channelServer;

    static native void onConnected(int id);
    static native void onAccepted(int id, String address);
    static native void onData(int id, byte[] data);
    static native void onClosed(int id, String reason);

    private BtBridge() {}

    private static BluetoothAdapter adapter() {
        try {
            return BluetoothAdapter.getDefaultAdapter();
        } catch (Throwable e) {
            return null;
        }
    }

    public static boolean available() {
        BluetoothAdapter a = adapter();
        try {
            return a != null && a.isEnabled();
        } catch (SecurityException e) {
            return false;
        }
    }

    public static String localName() {
        BluetoothAdapter a = adapter();
        try {
            return a != null && a.getName() != null ? a.getName() : "";
        } catch (SecurityException e) {
            return "";
        }
    }

    // "name\taddress\n" for every paired device.
    public static String bonded() {
        StringBuilder out = new StringBuilder();
        BluetoothAdapter a = adapter();
        if (a == null)
            return "";
        try {
            Set<BluetoothDevice> devices = a.getBondedDevices();
            if (devices == null)
                return "";
            for (BluetoothDevice d : devices) {
                String name = d.getName();
                out.append(name != null ? name.replace('\t', ' ').replace('\n', ' ') : d.getAddress())
                   .append('\t').append(d.getAddress()).append('\n');
            }
        } catch (SecurityException e) {
            return "";
        }
        return out.toString();
    }

    // Opens both servers; returns an error text, empty on success.
    public static String listen(int channel) {
        stopListening();
        BluetoothAdapter a = adapter();
        if (a == null)
            return "Dieses Gerät hat kein Bluetooth";
        try {
            if (!a.isEnabled())
                return "Bluetooth ist ausgeschaltet";
            uuidServer = a.listenUsingInsecureRfcommWithServiceRecord(NAME, SERVICE);
            acceptLoop(uuidServer);
        } catch (SecurityException e) {
            return "Bluetooth-Berechtigung fehlt";
        } catch (IOException e) {
            return e.getMessage() != null ? e.getMessage() : "Bluetooth nicht verfügbar";
        }
        // For Sailfish OS guests, which connect to the fixed channel directly.
        try {
            Method m = a.getClass().getMethod("listenUsingInsecureRfcommOn", int.class);
            channelServer = (BluetoothServerSocket) m.invoke(a, channel);
            acceptLoop(channelServer);
        } catch (Throwable ignored) {
            channelServer = null;
        }
        return "";
    }

    public static void stopListening() {
        closeQuietly(uuidServer);
        closeQuietly(channelServer);
        uuidServer = null;
        channelServer = null;
    }

    private static void acceptLoop(final BluetoothServerSocket server) {
        Thread t = new Thread(() -> {
            while (true) {
                BluetoothSocket socket;
                try {
                    socket = server.accept();
                } catch (IOException e) {
                    return; // closed by stopListening()
                }
                if (socket == null)
                    continue;
                int id = nextId.getAndIncrement();
                Link link = new Link(id, socket);
                links.put(id, link);
                onAccepted(id, socket.getRemoteDevice().getAddress());
                link.start();
            }
        }, "bioquiz-bt-accept");
        t.setDaemon(true);
        t.start();
    }

    // Starts connecting and returns the id at once; onConnected or onClosed follows.
    public static int connect(final String address, final int channel) {
        final int id = nextId.getAndIncrement();
        Thread t = new Thread(() -> {
            BluetoothAdapter a = adapter();
            if (a == null) {
                onClosed(id, "Dieses Gerät hat kein Bluetooth");
                return;
            }
            BluetoothDevice device;
            try {
                device = a.getRemoteDevice(address);
                a.cancelDiscovery();
            } catch (Throwable e) {
                onClosed(id, "Keine Bluetooth-Adresse");
                return;
            }
            BluetoothSocket socket = null;
            String error = "Keine Antwort über Bluetooth";
            // First the service UUID (an Android host) ...
            try {
                socket = device.createInsecureRfcommSocketToServiceRecord(SERVICE);
                socket.connect();
            } catch (SecurityException e) {
                closeQuietly(socket);
                socket = null;
                error = "Bluetooth-Berechtigung fehlt";
            } catch (IOException e) {
                closeQuietly(socket);
                socket = null;
            }
            // ... then the fixed channel (a Sailfish OS or N9 host).
            if (socket == null) {
                for (String method : new String[] { "createInsecureRfcommSocket", "createRfcommSocket" }) {
                    try {
                        Method m = device.getClass().getMethod(method, int.class);
                        socket = (BluetoothSocket) m.invoke(device, channel);
                        socket.connect();
                        break;
                    } catch (Throwable e) {
                        closeQuietly(socket);
                        socket = null;
                    }
                }
            }
            if (socket == null) {
                onClosed(id, error);
                return;
            }
            Link link = new Link(id, socket);
            links.put(id, link);
            onConnected(id);
            link.start();
        }, "bioquiz-bt-connect");
        t.setDaemon(true);
        t.start();
        return id;
    }

    public static void write(int id, byte[] data) {
        Link link = links.get(id);
        if (link != null)
            link.queue.offer(data);
    }

    public static void close(int id) {
        Link link = links.remove(id);
        if (link != null)
            link.shutdown();
    }

    private static void closeQuietly(java.io.Closeable c) {
        if (c == null)
            return;
        try {
            c.close();
        } catch (IOException ignored) {
        }
    }

    // One connection: a reader thread and a writer thread, so a slow peer
    // never blocks the UI thread.
    private static final class Link {
        final int id;
        final BluetoothSocket socket;
        final LinkedBlockingQueue<byte[]> queue = new LinkedBlockingQueue<>();
        volatile boolean closed = false;
        private static final byte[] STOP = new byte[0];

        Link(int id, BluetoothSocket socket) {
            this.id = id;
            this.socket = socket;
        }

        void start() {
            Thread reader = new Thread(() -> {
                String reason = "Verbindung getrennt";
                try {
                    InputStream in = socket.getInputStream();
                    byte[] buffer = new byte[4096];
                    while (true) {
                        int n = in.read(buffer);
                        if (n < 0)
                            break;
                        byte[] chunk = new byte[n];
                        System.arraycopy(buffer, 0, chunk, 0, n);
                        onData(id, chunk);
                    }
                } catch (IOException e) {
                    if (e.getMessage() != null)
                        reason = e.getMessage();
                }
                boolean wasOpen = links.remove(id) != null;
                shutdown();
                if (wasOpen)
                    onClosed(id, reason);
            }, "bioquiz-bt-read-" + id);
            Thread writer = new Thread(() -> {
                try {
                    OutputStream out = socket.getOutputStream();
                    while (true) {
                        byte[] data = queue.take();
                        if (data == STOP)
                            return;
                        out.write(data);
                        out.flush();
                    }
                } catch (Exception e) {
                    shutdown();
                }
            }, "bioquiz-bt-write-" + id);
            reader.setDaemon(true);
            writer.setDaemon(true);
            reader.start();
            writer.start();
        }

        void shutdown() {
            if (closed)
                return;
            closed = true;
            queue.offer(STOP);
            closeQuietly(socket);
        }
    }
}
