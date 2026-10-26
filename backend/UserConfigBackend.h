#pragma once

#include <QFileSystemWatcher>
#include <QJsonValue>
#include <QObject>
#include <QTimer>
#include <QtQml/qqml.h>

class UserConfigBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(UserConfig)
    QML_SINGLETON

    Q_PROPERTY(QString userConfigPath READ userConfigPath CONSTANT FINAL)
    Q_PROPERTY(QString configError READ configError NOTIFY configErrorChanged FINAL)
    Q_PROPERTY(QString defaultTlpSudoPassword READ defaultTlpSudoPassword WRITE setDefaultTlpSudoPassword NOTIFY defaultTlpSudoPasswordChanged FINAL)

    Q_PROPERTY(QString iconFontFamily READ iconFontFamily NOTIFY iconFontFamilyChanged FINAL)
    Q_PROPERTY(QString textFontFamily READ textFontFamily NOTIFY textFontFamilyChanged FINAL)
    Q_PROPERTY(QString heroFontFamily READ heroFontFamily NOTIFY heroFontFamilyChanged FINAL)
    Q_PROPERTY(QString timeFontFamily READ timeFontFamily NOTIFY timeFontFamilyChanged FINAL)
    Q_PROPERTY(QString clockFormat READ clockFormat NOTIFY clockFormatChanged FINAL)
    Q_PROPERTY(QString tlpSudoPassword READ tlpSudoPassword NOTIFY tlpSudoPasswordChanged FINAL)
    Q_PROPERTY(QString tlpPermissionMode READ tlpPermissionMode NOTIFY tlpPermissionModeChanged FINAL)
    Q_PROPERTY(QString powerProfileDriver READ powerProfileDriver NOTIFY powerProfileDriverChanged FINAL)
    Q_PROPERTY(QString terminalEmulator READ terminalEmulator NOTIFY terminalEmulatorChanged FINAL)


    Q_PROPERTY(int dynamicIslandPrimaryButton READ dynamicIslandPrimaryButton NOTIFY dynamicIslandPrimaryButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandPrimaryAction READ dynamicIslandPrimaryAction NOTIFY dynamicIslandPrimaryActionChanged FINAL)
    Q_PROPERTY(int dynamicIslandSecondaryButton READ dynamicIslandSecondaryButton NOTIFY dynamicIslandSecondaryButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandSecondaryAction READ dynamicIslandSecondaryAction NOTIFY dynamicIslandSecondaryActionChanged FINAL)
    Q_PROPERTY(int dynamicIslandMiddleButton READ dynamicIslandMiddleButton NOTIFY dynamicIslandMiddleButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandMiddleAction READ dynamicIslandMiddleAction NOTIFY dynamicIslandMiddleActionChanged FINAL)
    Q_PROPERTY(int hoverExpandAction READ hoverExpandAction NOTIFY hoverExpandActionChanged FINAL)
    Q_PROPERTY(bool islandAutoHideEnabled READ islandAutoHideEnabled NOTIFY islandAutoHideEnabledChanged FINAL)
    Q_PROPERTY(int islandAutoHideDelayMs READ islandAutoHideDelayMs NOTIFY islandAutoHideDelayMsChanged FINAL)
    Q_PROPERTY(QString islandBatteryMode READ islandBatteryMode NOTIFY islandBatteryModeChanged FINAL)
    Q_PROPERTY(bool islandAutoHideKeepActivities READ islandAutoHideKeepActivities NOTIFY islandAutoHideKeepActivitiesChanged FINAL)
    // Popup timeouts in seconds for normal and low urgency (critical popups stay until dismissed).
    // Screen edge the island lives on: "top" or "bottom" (anything else is "top").
    Q_PROPERTY(QString islandEdge READ islandEdge NOTIFY islandEdgeChanged FINAL)
    Q_PROPERTY(int notificationTimeout READ notificationTimeout NOTIFY notificationTimeoutChanged FINAL)
    Q_PROPERTY(int notificationTimeoutLow READ notificationTimeoutLow NOTIFY notificationTimeoutLowChanged FINAL)
    Q_PROPERTY(QStringList idleInhibitCommand READ idleInhibitCommand NOTIFY idleInhibitCommandChanged FINAL)
    Q_PROPERTY(QStringList lockCommand READ lockCommand NOTIFY lockCommandChanged FINAL)

    Q_PROPERTY(int islandWidth READ islandWidth NOTIFY islandWidthChanged FINAL)
    Q_PROPERTY(int islandHeight READ islandHeight NOTIFY islandHeightChanged FINAL)
    Q_PROPERTY(int islandExclusiveZone READ islandExclusiveZone NOTIFY islandExclusiveZoneChanged FINAL)
    Q_PROPERTY(int islandTopMargin READ islandTopMargin NOTIFY islandTopMarginChanged FINAL)
    Q_PROPERTY(int islandPositionX READ islandPositionX NOTIFY islandPositionXChanged FINAL)
    Q_PROPERTY(int islandBackgroundOpacity READ islandBackgroundOpacity NOTIFY islandBackgroundOpacityChanged FINAL)
    Q_PROPERTY(bool islandBlurEnabled READ islandBlurEnabled NOTIFY islandBlurEnabledChanged FINAL)
    Q_PROPERTY(int bodyFontSize READ bodyFontSize NOTIFY bodyFontSizeChanged FINAL)
    Q_PROPERTY(int titleFontSize READ titleFontSize NOTIFY titleFontSizeChanged FINAL)
    Q_PROPERTY(int iconFontSize READ iconFontSize NOTIFY iconFontSizeChanged FINAL)

    Q_PROPERTY(bool weatherEnabled READ weatherEnabled NOTIFY weatherEnabledChanged FINAL)
    Q_PROPERTY(QString weatherLocation READ weatherLocation NOTIFY weatherLocationChanged FINAL)
    Q_PROPERTY(QString weatherUnits READ weatherUnits NOTIFY weatherUnitsChanged FINAL)
    Q_PROPERTY(int weatherRefreshInterval READ weatherRefreshInterval NOTIFY weatherRefreshIntervalChanged FINAL)

    Q_PROPERTY(bool colorPaletteEnabled READ colorPaletteEnabled NOTIFY colorPaletteEnabledChanged FINAL)
    Q_PROPERTY(QString colorsFilePath READ colorsFilePath NOTIFY colorsFilePathChanged FINAL)
    Q_PROPERTY(bool dynamicBatteryColorEnabled READ dynamicBatteryColorEnabled NOTIFY dynamicBatteryColorEnabledChanged FINAL)
    Q_PROPERTY(bool marqueeTrackTitleEnabled READ marqueeTrackTitleEnabled NOTIFY marqueeTrackTitleEnabledChanged FINAL)
    Q_PROPERTY(bool privacyCameraBubbleEnabled READ privacyCameraBubbleEnabled NOTIFY privacyCameraBubbleEnabledChanged FINAL)
    Q_PROPERTY(bool privacyMicBubbleEnabled READ privacyMicBubbleEnabled NOTIFY privacyMicBubbleEnabledChanged FINAL)
    Q_PROPERTY(QString avatarPath READ avatarPath WRITE setAvatarPath NOTIFY avatarPathChanged FINAL)
    Q_PROPERTY(bool doNotDisturb READ doNotDisturb WRITE setDoNotDisturb NOTIFY doNotDisturbChanged FINAL)

public:
    explicit UserConfigBackend(QObject *parent = nullptr);

    QString userConfigPath() const;
    QString configError() const;
    QString defaultTlpSudoPassword() const;
    QString iconFontFamily() const;
    QString textFontFamily() const;
    QString heroFontFamily() const;
    QString timeFontFamily() const;
    QString clockFormat() const;
    QString tlpSudoPassword() const;
    QString tlpPermissionMode() const;
    QString powerProfileDriver() const;
    QString terminalEmulator() const;
    int dynamicIslandPrimaryButton() const;
    QString dynamicIslandPrimaryAction() const;
    int dynamicIslandSecondaryButton() const;
    QString dynamicIslandSecondaryAction() const;
    int dynamicIslandMiddleButton() const;
    QString dynamicIslandMiddleAction() const;
    int hoverExpandAction() const;
    QString islandBatteryMode() const;
    bool islandAutoHideKeepActivities() const;
    int notificationTimeout() const;
    QString islandEdge() const;
    int notificationTimeoutLow() const;
    QStringList idleInhibitCommand() const;
    QStringList lockCommand() const;
    bool islandAutoHideEnabled() const;
    int islandAutoHideDelayMs() const;
    int islandWidth() const;
    int islandHeight() const;
    int islandExclusiveZone() const;
    int islandTopMargin() const;
    int islandPositionX() const;
    int islandBackgroundOpacity() const;
    bool islandBlurEnabled() const;
    int bodyFontSize() const;
    int titleFontSize() const;
    int iconFontSize() const;
    bool weatherEnabled() const;
    QString weatherLocation() const;
    QString weatherUnits() const;
    int weatherRefreshInterval() const;
    bool colorPaletteEnabled() const;
    QString colorsFilePath() const;
    bool dynamicBatteryColorEnabled() const;
    bool marqueeTrackTitleEnabled() const;
    bool privacyCameraBubbleEnabled() const;
    bool privacyMicBubbleEnabled() const;
    QString avatarPath() const;
    void setAvatarPath(const QString &path);
    bool doNotDisturb() const;
    void setDoNotDisturb(bool enabled);
    void setDefaultTlpSudoPassword(const QString &password);

    Q_INVOKABLE int mouseButton(const QVariant &button) const;
    Q_INVOKABLE int mouseButtonsMask(const QVariant &buttons) const;
    Q_INVOKABLE void reload();

signals:
    void configErrorChanged();
    void defaultTlpSudoPasswordChanged();
    void iconFontFamilyChanged();
    void textFontFamilyChanged();
    void heroFontFamilyChanged();
    void timeFontFamilyChanged();
    void clockFormatChanged();
    void tlpSudoPasswordChanged();
    void tlpPermissionModeChanged();
    void powerProfileDriverChanged();
    void terminalEmulatorChanged();
    void dynamicIslandPrimaryButtonChanged();
    void dynamicIslandPrimaryActionChanged();
    void dynamicIslandSecondaryButtonChanged();
    void dynamicIslandSecondaryActionChanged();
    void dynamicIslandMiddleButtonChanged();
    void dynamicIslandMiddleActionChanged();
    void islandBatteryModeChanged();
    void islandAutoHideKeepActivitiesChanged();
    void notificationTimeoutChanged();
    void islandEdgeChanged();
    void notificationTimeoutLowChanged();
    void idleInhibitCommandChanged();
    void lockCommandChanged();
    void hoverExpandActionChanged();
    void islandAutoHideEnabledChanged();
    void islandAutoHideDelayMsChanged();
    void islandWidthChanged();
    void islandHeightChanged();
    void islandExclusiveZoneChanged();
    void islandTopMarginChanged();
    void islandPositionXChanged();
    void islandBackgroundOpacityChanged();
    void islandBlurEnabledChanged();
    void bodyFontSizeChanged();
    void titleFontSizeChanged();
    void iconFontSizeChanged();
    void weatherEnabledChanged();
    void weatherLocationChanged();
    void weatherUnitsChanged();
    void weatherRefreshIntervalChanged();
    void colorPaletteEnabledChanged();
    void colorsFilePathChanged();
    void dynamicBatteryColorEnabledChanged();
    void marqueeTrackTitleEnabledChanged();
    void privacyCameraBubbleEnabledChanged();
    void privacyMicBubbleEnabledChanged();
    void avatarPathChanged();
    void doNotDisturbChanged();

private:
    void scheduleReload();
    void loadConfig();
    bool writeConfigValue(const QString &key, const QJsonValue &value);
    void updateWatchedPaths();
    QString configHome() const;

    QString m_userConfigPath;
    QString m_configError;
    QString m_defaultTlpSudoPassword;
    QString m_iconFontFamily = QStringLiteral("JetBrainsMono Nerd Font");
    QString m_textFontFamily = QStringLiteral("Sans Serif");
    QString m_heroFontFamily = QStringLiteral("Sans Serif");
    QString m_timeFontFamily = QStringLiteral("Sans Serif");
    QString m_clockFormat = QStringLiteral("12");
    QString m_tlpSudoPassword;
    QString m_tlpPermissionMode = QStringLiteral("skip");
    QString m_powerProfileDriver = QStringLiteral("auto");
    QString m_terminalEmulator;
    int m_dynamicIslandPrimaryButton = 1;
    QString m_dynamicIslandPrimaryAction = QStringLiteral("none");
    int m_dynamicIslandSecondaryButton = 3;
    QString m_dynamicIslandSecondaryAction = QStringLiteral("toggleControlCenter");
    int m_dynamicIslandMiddleButton = 2;
    QString m_dynamicIslandMiddleAction = QStringLiteral("toggleClipboard");
    QString m_islandBatteryMode = QStringLiteral("low");
    bool m_islandAutoHideKeepActivities = true;
    int m_notificationTimeout = 8;
    QString m_islandEdge = QStringLiteral("top");
    int m_notificationTimeoutLow = 5;
    QStringList m_idleInhibitCommand;
    QStringList m_lockCommand;
    int m_hoverExpandAction = 0;
    bool m_islandAutoHideEnabled = true;
    int m_islandAutoHideDelayMs = 1000;
    int m_islandWidth = 140;
    int m_islandBackgroundOpacity = 60;
    bool m_islandBlurEnabled = true;
    int m_islandHeight = 38;
    int m_islandExclusiveZone = 45;
    int m_islandTopMargin = 4;
    int m_islandPositionX = 50;
    int m_bodyFontSize = 16;
    int m_titleFontSize = 20;
    int m_iconFontSize = 18;
    bool m_weatherEnabled = true;
    QString m_weatherLocation;
    QString m_weatherUnits = QStringLiteral("metric");
    int m_weatherRefreshInterval = 1800000;
    bool m_colorPaletteEnabled = true;
    QString m_colorsFilePath;
    bool m_dynamicBatteryColorEnabled = true;
    bool m_marqueeTrackTitleEnabled = true;
    bool m_privacyCameraBubbleEnabled = true;
    bool m_privacyMicBubbleEnabled = true;
    QString m_avatarPath;
    bool m_doNotDisturb = false;

    QFileSystemWatcher m_watcher;
    QTimer m_reloadTimer;
};
