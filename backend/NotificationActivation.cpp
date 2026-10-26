#include "NotificationActivation.h"

#include <QDBusConnection>
#include <QGuiApplication>
#include <QWindow>
#include <qpa/qplatformnativeinterface.h>

#include <wayland-client.h>

#include <poll.h>

#include "xdg-activation-v1-client-protocol.h"

namespace {
QNativeInterface::QWaylandApplication *waylandApplication()
{
    auto *app = qobject_cast<QGuiApplication *>(QCoreApplication::instance());
    return app ? app->nativeInterface<QNativeInterface::QWaylandApplication>() : nullptr;
}
} // namespace

NotificationActivation::NotificationActivation(QObject *parent)
    : QObject(parent)
{
    m_pollTimer.setInterval(5);
    connect(&m_pollTimer, &QTimer::timeout, this, &NotificationActivation::pollPending);
}

NotificationActivation::~NotificationActivation()
{
    destroyWaylandObjects();
}

void NotificationActivation::destroyWaylandObjects()
{
    // The objects live on Qt's connection, which is gone once the application is torn down.
    if (!m_display || !waylandApplication())
        return;

    for (const auto &pending : m_pending)
        xdg_activation_token_v1_destroy(pending->token);
    m_pending.clear();
    if (m_activation)
        xdg_activation_v1_destroy(m_activation);
    if (m_registry)
        wl_registry_destroy(m_registry);
    if (m_queue)
        wl_event_queue_destroy(m_queue);
    m_activation = nullptr;
    m_registry = nullptr;
    m_queue = nullptr;
}

QDBusMessage NotificationActivation::activationTokenSignal(uint notificationId, const QString &token)
{
    QDBusMessage message = QDBusMessage::createSignal(QStringLiteral("/org/freedesktop/Notifications"),
                                                      QStringLiteral("org.freedesktop.Notifications"),
                                                      QStringLiteral("ActivationToken"));
    message << notificationId << token;
    return message;
}

void NotificationActivation::requestToken(QObject *windowObject, uint notificationId)
{
    if (!ensureActivationGlobal()) {
        reportLater(notificationId);
        return;
    }

    auto pending = std::make_unique<PendingToken>();
    pending->notificationId = notificationId;
    pending->token = xdg_activation_v1_get_activation_token(m_activation);
    static const xdg_activation_token_v1_listener tokenListener = {&NotificationActivation::handleTokenDone};
    xdg_activation_token_v1_add_listener(pending->token, &tokenListener, pending.get());

    // The click that triggered this is the last input; compositors only honour tokens with one.
    auto *waylandApp = waylandApplication();
    if (wl_seat *seat = waylandApp->lastInputSeat())
        xdg_activation_token_v1_set_serial(pending->token, waylandApp->lastInputSerial(), seat);
    auto *window = qobject_cast<QWindow *>(windowObject);
    if (QPlatformNativeInterface *native = QGuiApplication::platformNativeInterface(); window && native) {
        if (auto *surface = static_cast<wl_surface *>(native->nativeResourceForWindow("surface", window)))
            xdg_activation_token_v1_set_surface(pending->token, surface);
    }
    xdg_activation_token_v1_commit(pending->token);
    wl_display_flush(m_display);

    pending->age.start();
    m_pending.push_back(std::move(pending));
    m_pollTimer.start();
}

bool NotificationActivation::ensureActivationGlobal()
{
    if (m_activation)
        return true;
    if (m_globalsQueried)
        return false;
    m_globalsQueried = true;

    auto *waylandApp = waylandApplication();
    if (!waylandApp || !waylandApp->display())
        return false;

    // A private queue: Qt keeps dispatching its own, this object only ever dispatches this one.
    m_display = waylandApp->display();
    m_queue = wl_display_create_queue(m_display);
    auto *displayWrapper = static_cast<wl_display *>(wl_proxy_create_wrapper(m_display));
    wl_proxy_set_queue(reinterpret_cast<wl_proxy *>(displayWrapper), m_queue);
    m_registry = wl_display_get_registry(displayWrapper);
    wl_proxy_wrapper_destroy(displayWrapper);

    static const wl_registry_listener registryListener = {
        &NotificationActivation::handleRegistryGlobal,
        &NotificationActivation::handleRegistryGlobalRemove,
    };
    wl_registry_add_listener(m_registry, &registryListener, this);
    wl_display_roundtrip_queue(m_display, m_queue);

    if (!m_activation)
        qInfo() << "[Notifications] the compositor offers no xdg_activation_v1; actions run without activation tokens";
    return m_activation != nullptr;
}

void NotificationActivation::pollPending()
{
    // Read whatever is waiting on the socket without blocking (Qt's event thread may be reading
    // too; libwayland routes each event to its queue), then run this queue's callbacks.
    if (wl_display_prepare_read_queue(m_display, m_queue) == 0) {
        pollfd descriptor{wl_display_get_fd(m_display), POLLIN, 0};
        if (::poll(&descriptor, 1, 0) > 0)
            wl_display_read_events(m_display);
        else
            wl_display_cancel_read(m_display);
    }
    wl_display_dispatch_queue_pending(m_display, m_queue);

    std::vector<std::pair<uint, QString>> results;
    for (auto it = m_pending.begin(); it != m_pending.end();) {
        PendingToken *pending = it->get();
        if (!pending->done && pending->age.elapsed() < TokenTimeoutMs) {
            ++it;
            continue;
        }
        xdg_activation_token_v1_destroy(pending->token);
        results.emplace_back(pending->notificationId, pending->done ? pending->value : QString());
        it = m_pending.erase(it);
    }
    if (m_pending.empty())
        m_pollTimer.stop();

    for (const auto &[notificationId, token] : results) {
        // Same session-bus connection as Quickshell's notification server, so the signal comes
        // from the name owner, and it is queued before the ActionInvoked the caller sends next.
        if (!token.isEmpty())
            QDBusConnection::sessionBus().send(activationTokenSignal(notificationId, token));
        emit tokenReady(notificationId, token);
    }
}

void NotificationActivation::reportLater(uint notificationId)
{
    QTimer::singleShot(0, this, [this, notificationId] { emit tokenReady(notificationId, QString()); });
}

void NotificationActivation::handleRegistryGlobal(void *data, wl_registry *registry, uint32_t name,
                                                  const char *interface, uint32_t version)
{
    Q_UNUSED(version);
    auto *self = static_cast<NotificationActivation *>(data);
    if (!self->m_activation && qstrcmp(interface, xdg_activation_v1_interface.name) == 0) {
        self->m_activation = static_cast<xdg_activation_v1 *>(
            wl_registry_bind(registry, name, &xdg_activation_v1_interface, 1));
    }
}

void NotificationActivation::handleRegistryGlobalRemove(void *data, wl_registry *registry, uint32_t name)
{
    Q_UNUSED(data);
    Q_UNUSED(registry);
    Q_UNUSED(name);
}

void NotificationActivation::handleTokenDone(void *data, xdg_activation_token_v1 *token, const char *value)
{
    Q_UNUSED(token);
    auto *pending = static_cast<PendingToken *>(data);
    pending->done = true;
    pending->value = QString::fromUtf8(value);
}
