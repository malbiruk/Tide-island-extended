#pragma once

#include <QDBusMessage>
#include <QElapsedTimer>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QtQml/qqml.h>

#include <cstdint>
#include <memory>
#include <vector>

struct wl_display;
struct wl_event_queue;
struct wl_registry;
struct xdg_activation_v1;
struct xdg_activation_token_v1;

// Gets an xdg_activation_v1 token for a notification action, so the compositor lets the sender
// raise its window. The token is tied to the last input on the island's surface (the click), is
// announced to the sender with the ActivationToken signal of org.freedesktop.Notifications, and
// is then reported with tokenReady(); the caller invokes the action after that, so the signal
// reaches the sender before ActionInvoked.
class NotificationActivation final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit NotificationActivation(QObject *parent = nullptr);
    ~NotificationActivation() override;

    // Always answers with tokenReady() (asynchronously); the token is empty without Wayland,
    // without xdg_activation_v1, or when the compositor does not answer within the timeout.
    Q_INVOKABLE void requestToken(QObject *window, uint notificationId);

    static QDBusMessage activationTokenSignal(uint notificationId, const QString &token);

    static constexpr int TokenTimeoutMs = 300;

signals:
    void tokenReady(uint notificationId, const QString &token);

private:
    struct PendingToken {
        uint notificationId = 0;
        xdg_activation_token_v1 *token = nullptr;
        QElapsedTimer age;
        bool done = false;
        QString value;
    };

    bool ensureActivationGlobal();
    void pollPending();
    void reportLater(uint notificationId);
    void destroyWaylandObjects();

    static void handleRegistryGlobal(void *data, wl_registry *registry, uint32_t name,
                                     const char *interface, uint32_t version);
    static void handleRegistryGlobalRemove(void *data, wl_registry *registry, uint32_t name);
    static void handleTokenDone(void *data, xdg_activation_token_v1 *token, const char *value);

    wl_display *m_display = nullptr;
    wl_event_queue *m_queue = nullptr;
    wl_registry *m_registry = nullptr;
    xdg_activation_v1 *m_activation = nullptr;
    bool m_globalsQueried = false;
    std::vector<std::unique_ptr<PendingToken>> m_pending;
    QTimer m_pollTimer;
};
