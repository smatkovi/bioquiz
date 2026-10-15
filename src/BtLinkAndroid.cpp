#include "BtLink.h"

// Android side of BtLink.h: the same RfcommSocket/RfcommServer/BtDevices,
// but the bytes travel through the Android Bluetooth API in
// android/package/src/org/smatkovi/bioquiz/BtBridge.java. Java calls back
// from its own threads; every callback is queued onto the main thread
// before it touches a Qt object.
#ifdef Q_OS_ANDROID

#include <QCoreApplication>
#include <QHash>
#include <QJniEnvironment>
#include <QJniObject>
#include <QPermissions>
#include <QPointer>
#include <QStringList>
#include <QVariantMap>

namespace {

const char kBridge[] = "org/smatkovi/bioquiz/BtBridge";

QHash<int, QPointer<RfcommSocket>>& sockets()
{
    static QHash<int, QPointer<RfcommSocket>> map;
    return map;
}

QPointer<RfcommServer>& activeServer()
{
    static QPointer<RfcommServer> server;
    return server;
}

QString fromJava(JNIEnv* env, jstring text)
{
    if (!text)
        return QString();
    const char* utf = env->GetStringUTFChars(text, nullptr);
    const QString result = QString::fromUtf8(utf);
    env->ReleaseStringUTFChars(text, utf);
    return result;
}

void onConnected(JNIEnv*, jclass, jint id)
{
    QMetaObject::invokeMethod(qApp, [id]() {
        if (RfcommSocket* socket = sockets().value(id))
            socket->bridgeConnected();
    }, Qt::QueuedConnection);
}

void onAccepted(JNIEnv* env, jclass, jint id, jstring address)
{
    const QString peer = fromJava(env, address);
    QMetaObject::invokeMethod(qApp, [id, peer]() {
        if (RfcommServer* server = activeServer())
            server->bridgeAccepted(id, peer);
        else
            QJniObject::callStaticMethod<void>(kBridge, "close", "(I)V", jint(id));
    }, Qt::QueuedConnection);
}

void onData(JNIEnv* env, jclass, jint id, jbyteArray data)
{
    const jsize size = env->GetArrayLength(data);
    QByteArray bytes(size, Qt::Uninitialized);
    env->GetByteArrayRegion(data, 0, size, reinterpret_cast<jbyte*>(bytes.data()));
    QMetaObject::invokeMethod(qApp, [id, bytes]() {
        if (RfcommSocket* socket = sockets().value(id))
            socket->bridgeData(bytes);
    }, Qt::QueuedConnection);
}

void onClosed(JNIEnv* env, jclass, jint id, jstring reason)
{
    const QString text = fromJava(env, reason);
    QMetaObject::invokeMethod(qApp, [id, text]() {
        if (RfcommSocket* socket = sockets().value(id))
            socket->bridgeClosed(text);
    }, Qt::QueuedConnection);
}

bool registerNatives()
{
    static bool done = false;
    if (done)
        return true;
    const JNINativeMethod methods[] = {
        { "onConnected", "(I)V", reinterpret_cast<void*>(onConnected) },
        { "onAccepted", "(ILjava/lang/String;)V", reinterpret_cast<void*>(onAccepted) },
        { "onData", "(I[B)V", reinterpret_cast<void*>(onData) },
        { "onClosed", "(ILjava/lang/String;)V", reinterpret_cast<void*>(onClosed) },
    };
    QJniEnvironment env;
    done = env.registerNativeMethods(kBridge, methods, 4);
    return done;
}

// Android 12+ wants BLUETOOTH_CONNECT at run time. Asked for once, the first
// time Bluetooth is looked at; until then Bluetooth counts as unavailable.
bool permitted()
{
    QBluetoothPermission permission;
    permission.setCommunicationModes(QBluetoothPermission::Access);
    switch (qApp->checkPermission(permission)) {
    case Qt::PermissionStatus::Granted:
        return true;
    case Qt::PermissionStatus::Undetermined:
        qApp->requestPermission(permission, qApp, [](const QPermission&) {});
        return false;
    default:
        return false;
    }
}

} // namespace

// --- Bt --------------------------------------------------------------------------

bool Bt::available()
{
    return permitted() && registerNatives()
        && QJniObject::callStaticMethod<jboolean>(kBridge, "available", "()Z");
}

QString Bt::localAddress()
{
    // Android hides the own adapter address from apps (02:00:00:00:00:00).
    return QString();
}

QString Bt::normalizeAddress(const QString& address)
{
    QString text = address.trimmed().toUpper();
    text.replace(QLatin1Char('-'), QLatin1Char(':'));
    text.replace(QLatin1Char(' '), QLatin1Char(':'));
    const QStringList parts = text.split(QLatin1Char(':'));
    if (parts.size() != 6)
        return QString();
    QStringList clean;
    for (const QString& part : parts) {
        bool ok = false;
        const uint byte = part.toUInt(&ok, 16);
        if (!ok || byte > 0xff)
            return QString();
        clean.append(QStringLiteral("%1").arg(byte, 2, 16, QLatin1Char('0')).toUpper());
    }
    return clean.join(QLatin1Char(':'));
}

// --- RfcommSocket ----------------------------------------------------------------

RfcommSocket::RfcommSocket(QObject* parent)
    : QIODevice(parent)
    , m_fd(-1)
    , m_state(Unconnected)
    , m_readNotifier(nullptr)
    , m_writeNotifier(nullptr)
{
}

RfcommSocket::~RfcommSocket()
{
    blockSignals(true);
    shutdown(false);
}

void RfcommSocket::connectToDevice(const QString& address, int channel)
{
    shutdown(false);
    if (!Bt::available()) {
        fail(tr("Bluetooth ist aus oder nicht erlaubt"));
        return;
    }
    m_peer = address;
    m_state = Connecting;
    m_fd = QJniObject::callStaticMethod<jint>(kBridge, "connect", "(Ljava/lang/String;I)I",
                                              QJniObject::fromString(address).object<jstring>(), jint(channel));
    sockets().insert(m_fd, this);
}

void RfcommSocket::adopt(int descriptor, const QString& peerAddress)
{
    shutdown(false);
    m_fd = descriptor;
    m_peer = peerAddress;
    m_state = Connected;
    sockets().insert(m_fd, this);
    setOpenMode(QIODevice::ReadWrite | QIODevice::Unbuffered);
}

void RfcommSocket::bridgeConnected()
{
    if (m_state != Connecting)
        return;
    m_state = Connected;
    setOpenMode(QIODevice::ReadWrite | QIODevice::Unbuffered);
    emit connected();
    writePending();
}

void RfcommSocket::bridgeData(const QByteArray& data)
{
    m_in.append(data);
    emit readyRead();
}

void RfcommSocket::bridgeClosed(const QString& reason)
{
    const bool wasConnecting = m_state == Connecting;
    sockets().remove(m_fd);
    m_fd = -1;
    if (wasConnecting) {
        m_state = Unconnected;
        fail(reason);
        return;
    }
    shutdown(true);
}

qint64 RfcommSocket::bytesAvailable() const
{
    return m_in.size() + QIODevice::bytesAvailable();
}

void RfcommSocket::close()
{
    shutdown(true);
    QIODevice::close();
}

void RfcommSocket::abort()
{
    m_out.clear();
    shutdown(false);
}

void RfcommSocket::flush()
{
    writePending();
}

void RfcommSocket::disconnectFromHost()
{
    writePending();
    shutdown(true);
}

qint64 RfcommSocket::readData(char* data, qint64 maxSize)
{
    if (m_in.isEmpty())
        return m_state == Connected ? 0 : -1;
    const int count = static_cast<int>(qMin<qint64>(maxSize, m_in.size()));
    memcpy(data, m_in.constData(), count);
    m_in.remove(0, count);
    return count;
}

qint64 RfcommSocket::writeData(const char* data, qint64 size)
{
    if (m_state == Unconnected)
        return -1;
    m_out.append(data, static_cast<int>(size));
    if (m_state == Connected)
        writePending();
    return size;
}

void RfcommSocket::writePending()
{
    if (m_fd < 0 || m_state != Connected || m_out.isEmpty())
        return;
    QJniEnvironment env;
    jbyteArray array = env->NewByteArray(m_out.size());
    env->SetByteArrayRegion(array, 0, m_out.size(), reinterpret_cast<const jbyte*>(m_out.constData()));
    QJniObject::callStaticMethod<void>(kBridge, "write", "(I[B)V", jint(m_fd), array);
    env->DeleteLocalRef(array);
    m_out.clear();
}

void RfcommSocket::onReadable() {}
void RfcommSocket::onWritable() {}

void RfcommSocket::fail(const QString& reason)
{
    emit errorOccurred(reason);
}

void RfcommSocket::shutdown(bool notify)
{
    const bool wasConnected = m_state == Connected;
    m_state = Unconnected;
    if (m_fd >= 0) {
        sockets().remove(m_fd);
        QJniObject::callStaticMethod<void>(kBridge, "close", "(I)V", jint(m_fd));
        m_fd = -1;
    }
    setOpenMode(QIODevice::NotOpen);
    if (notify && wasConnected)
        emit disconnected();
}

// --- RfcommServer ----------------------------------------------------------------

RfcommServer::RfcommServer(QObject* parent)
    : QObject(parent)
    , m_fd(-1)
    , m_notifier(nullptr)
{
}

RfcommServer::~RfcommServer()
{
    close();
}

bool RfcommServer::listen(int channel, QString* error)
{
    close();
    if (!Bt::available()) {
        if (error)
            *error = tr("Bluetooth ist aus oder nicht erlaubt");
        return false;
    }
    const QString result = QJniObject::callStaticMethod<jstring>(kBridge, "listen", "(I)Ljava/lang/String;", jint(channel)).toString();
    if (!result.isEmpty()) {
        if (error)
            *error = result;
        return false;
    }
    m_fd = 1; // listening; the Java side holds the server sockets
    activeServer() = this;
    return true;
}

void RfcommServer::close()
{
    if (m_fd < 0)
        return;
    m_fd = -1;
    if (activeServer() == this)
        activeServer() = nullptr;
    QJniObject::callStaticMethod<void>(kBridge, "stopListening", "()V");
}

void RfcommServer::bridgeAccepted(int id, const QString& address)
{
    RfcommSocket* socket = new RfcommSocket(this);
    socket->adopt(id, address);
    emit newConnection(socket);
}

void RfcommServer::onIncoming() {}

// --- BtDevices -------------------------------------------------------------------

BtDevices::BtDevices(QObject* parent)
    : QObject(parent)
    , m_available(false)
{
    refresh();
}

void BtDevices::refresh()
{
    m_available = Bt::available();
    m_localAddress.clear();
    m_localName.clear();
    m_devices.clear();
    if (m_available) {
        m_localName = QJniObject::callStaticMethod<jstring>(kBridge, "localName", "()Ljava/lang/String;").toString();
        const QString list = QJniObject::callStaticMethod<jstring>(kBridge, "bonded", "()Ljava/lang/String;").toString();
        for (const QString& line : list.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
            const QStringList fields = line.split(QLatin1Char('\t'));
            if (fields.size() < 2)
                continue;
            QVariantMap entry;
            entry.insert(QStringLiteral("address"), fields.at(1));
            entry.insert(QStringLiteral("name"), fields.at(0));
            entry.insert(QStringLiteral("connected"), false);
            m_devices.append(entry);
        }
    }
    emit changed();
}

bool BtDevices::readBluez5() { return false; }
bool BtDevices::readBluez4() { return false; }

#endif // Q_OS_ANDROID
