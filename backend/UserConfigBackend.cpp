#include "UserConfigBackend.h"
#include "../common/JsonComments.h"
#include "../common/UserConfigFile.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QJsonParseError>
#include <QJsonValue>
#include <QProcess>
#include <QSet>
#include <QUrl>
#include <QVariant>
#include <Qt>

#include <algorithm>
#include <cmath>

namespace {
// A command line as the shell would split it (quotes allowed); "~" in the program is the home dir.
QStringList commandArguments(const QString &command)
{
    QStringList arguments = QProcess::splitCommand(command.trimmed());
    if (!arguments.isEmpty() && (arguments.first() == QLatin1String("~") || arguments.first().startsWith(QLatin1String("~/"))))
        arguments.first().replace(0, 1, QDir::homePath());
    return arguments;
}

QString jsonString(const QJsonObject &object, QLatin1String key, const QString &fallback)
{
    const QJsonValue value = object.value(key);
    return value.isString() && !value.toString().isEmpty() ? value.toString() : fallback;
}

int jsonInt(const QJsonObject &object, QLatin1String key, int fallback)
{
    const QJsonValue value = object.value(key);
    if (!value.isDouble())
        return fallback;

    const double number = value.toDouble();
    return std::isfinite(number) ? qRound(number) : fallback;
}

int jsonBoundedInt(const QJsonObject &object, QLatin1String key, int fallback, int minimum, int maximum)
{
    return std::clamp(jsonInt(object, key, fallback), minimum, maximum);
}

double jsonDouble(const QJsonObject &object, QLatin1String key, double fallback)
{
    const QJsonValue value = object.value(key);
    if (!value.isDouble())
        return fallback;

    const double number = value.toDouble();
    return std::isfinite(number) ? number : fallback;
}

bool jsonBool(const QJsonObject &object, QLatin1String key, bool fallback)
{
    const QJsonValue value = object.value(key);
    return value.isBool() ? value.toBool() : fallback;
}

template<typename Owner, typename T, typename Signal>
void updateField(Owner *owner, T &field, T nextValue, Signal signal)
{
    if (field == nextValue)
        return;

    field = std::move(nextValue);
    emit(owner->*signal)();
}
}

UserConfigBackend::UserConfigBackend(QObject *parent)
    : QObject(parent)
    , m_userConfigPath(configHome() + QStringLiteral("/tide-island/userconfig.json"))
{
    m_reloadTimer.setSingleShot(true);
    m_reloadTimer.setInterval(50);

    connect(&m_reloadTimer, &QTimer::timeout, this, &UserConfigBackend::loadConfig);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &UserConfigBackend::scheduleReload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &UserConfigBackend::scheduleReload);

    loadConfig();
}

QString UserConfigBackend::userConfigPath() const
{
    return m_userConfigPath;
}

QString UserConfigBackend::configError() const
{
    return m_configError;
}

QString UserConfigBackend::defaultTlpSudoPassword() const
{
    return m_defaultTlpSudoPassword;
}














QString UserConfigBackend::iconFontFamily() const
{
    return m_iconFontFamily;
}

QString UserConfigBackend::textFontFamily() const
{
    return m_textFontFamily;
}

QString UserConfigBackend::heroFontFamily() const
{
    return m_heroFontFamily;
}

QString UserConfigBackend::timeFontFamily() const
{
    return m_timeFontFamily;
}

QString UserConfigBackend::clockFormat() const
{
    return m_clockFormat;
}

QString UserConfigBackend::tlpSudoPassword() const
{
    return m_tlpSudoPassword;
}

QString UserConfigBackend::tlpPermissionMode() const
{
    return m_tlpPermissionMode;
}

QString UserConfigBackend::powerProfileDriver() const
{
    return m_powerProfileDriver;
}


int UserConfigBackend::dynamicIslandPrimaryButton() const
{
    return m_dynamicIslandPrimaryButton;
}

QString UserConfigBackend::dynamicIslandPrimaryAction() const
{
    return m_dynamicIslandPrimaryAction;
}

int UserConfigBackend::dynamicIslandSecondaryButton() const
{
    return m_dynamicIslandSecondaryButton;
}

QString UserConfigBackend::dynamicIslandSecondaryAction() const
{
    return m_dynamicIslandSecondaryAction;
}

int UserConfigBackend::dynamicIslandMiddleButton() const
{
    return m_dynamicIslandMiddleButton;
}

QString UserConfigBackend::dynamicIslandMiddleAction() const
{
    return m_dynamicIslandMiddleAction;
}

int UserConfigBackend::hoverExpandAction() const
{
    return m_hoverExpandAction;
}

bool UserConfigBackend::islandAutoHideEnabled() const
{
    return m_islandAutoHideEnabled;
}


// Island battery section: "low" (only below 40 % while discharging), "always" or "never".
QString UserConfigBackend::islandBatteryMode() const
{
    return m_islandBatteryMode;
}

bool UserConfigBackend::islandAutoHideKeepActivities() const
{
    return m_islandAutoHideKeepActivities;
}

QString UserConfigBackend::islandEdge() const
{
    return m_islandEdge;
}

int UserConfigBackend::notificationTimeout() const
{
    return m_notificationTimeout;
}

int UserConfigBackend::notificationTimeoutLow() const
{
    return m_notificationTimeoutLow;
}

// Command implementing `toggle` and `status` (prints "on"/"off") for idle inhibition;
// empty hides the control.
QStringList UserConfigBackend::idleInhibitCommand() const
{
    return m_idleInhibitCommand;
}

// Screen locker run by the power menu's Lock; empty uses gtklock, loginctl or swaylock.
QStringList UserConfigBackend::lockCommand() const
{
    return m_lockCommand;
}

int UserConfigBackend::islandAutoHideDelayMs() const
{
    return m_islandAutoHideDelayMs;
}


int UserConfigBackend::islandWidth() const
{
    return m_islandWidth;
}

int UserConfigBackend::islandBackgroundOpacity() const
{
    return m_islandBackgroundOpacity;
}

bool UserConfigBackend::islandBlurEnabled() const
{
    return m_islandBlurEnabled;
}

int UserConfigBackend::islandHeight() const
{
    return m_islandHeight;
}

int UserConfigBackend::islandExclusiveZone() const
{
    return m_islandExclusiveZone;
}

int UserConfigBackend::islandTopMargin() const
{
    return m_islandTopMargin;
}

int UserConfigBackend::islandPositionX() const
{
    return m_islandPositionX;
}

int UserConfigBackend::bodyFontSize() const
{
    return m_bodyFontSize;
}

int UserConfigBackend::titleFontSize() const
{
    return m_titleFontSize;
}

int UserConfigBackend::iconFontSize() const
{
    return m_iconFontSize;
}

bool UserConfigBackend::weatherEnabled() const
{
    return m_weatherEnabled;
}

QString UserConfigBackend::weatherLocation() const
{
    return m_weatherLocation;
}

QString UserConfigBackend::weatherUnits() const
{
    return m_weatherUnits;
}

int UserConfigBackend::weatherRefreshInterval() const
{
    return m_weatherRefreshInterval;
}

bool UserConfigBackend::colorPaletteEnabled() const
{
    return m_colorPaletteEnabled;
}

QString UserConfigBackend::colorsFilePath() const
{
    return m_colorsFilePath;
}

bool UserConfigBackend::dynamicBatteryColorEnabled() const
{
    return m_dynamicBatteryColorEnabled;
}

bool UserConfigBackend::marqueeTrackTitleEnabled() const
{
    return m_marqueeTrackTitleEnabled;
}

bool UserConfigBackend::privacyCameraBubbleEnabled() const
{
    return m_privacyCameraBubbleEnabled;
}

bool UserConfigBackend::privacyMicBubbleEnabled() const
{
    return m_privacyMicBubbleEnabled;
}

QString UserConfigBackend::avatarPath() const
{
    return m_avatarPath;
}

void UserConfigBackend::setAvatarPath(const QString &path)
{
    QString clean = path.trimmed();
    if (clean.startsWith(QLatin1String("file://"))) {
        clean = QUrl(clean).toLocalFile();
    }
    if (clean.startsWith(QLatin1String("~"))) {
        clean.replace(0, 1, QDir::homePath());
    }
    if (m_avatarPath == clean)
        return;

    m_avatarPath = clean;
    emit avatarPathChanged();

    // Persist to userconfig.json
    writeConfigValue(QStringLiteral("avatarPath"), clean.isEmpty() ? QJsonValue(QJsonValue::Undefined) : QJsonValue(clean));
}

bool UserConfigBackend::doNotDisturb() const { return m_doNotDisturb; }
void UserConfigBackend::setDoNotDisturb(bool enabled)
{
    if (m_doNotDisturb == enabled) return;
    m_doNotDisturb = enabled;
    emit doNotDisturbChanged();
    writeConfigValue(QStringLiteral("doNotDisturb"), enabled);
}

void UserConfigBackend::setDefaultTlpSudoPassword(const QString &password)
{
    if (m_defaultTlpSudoPassword == password)
        return;

    m_defaultTlpSudoPassword = password;
    emit defaultTlpSudoPasswordChanged();
    loadConfig();
}

int UserConfigBackend::mouseButton(const QVariant &button) const
{
    bool ok = false;
    const int numericButton = button.toInt(&ok);
    if (!ok)
        return Qt::NoButton;

    switch (numericButton) {
    case 1:
        return Qt::LeftButton;
    case 2:
        return Qt::MiddleButton;
    case 3:
        return Qt::RightButton;
    default:
        return numericButton;
    }
}

int UserConfigBackend::mouseButtonsMask(const QVariant &buttons) const
{
    if (!buttons.isValid() || buttons.isNull())
        return Qt::NoButton;

    if (buttons.canConvert<QVariantList>()) {
        int mask = Qt::NoButton;
        const QVariantList buttonList = buttons.toList();
        for (const QVariant &button : buttonList)
            mask |= mouseButton(button);
        return mask;
    }

    return mouseButton(buttons);
}

void UserConfigBackend::reload()
{
    loadConfig();
}

void UserConfigBackend::scheduleReload()
{
    if (!m_reloadTimer.isActive())
        m_reloadTimer.start();
}

// Persist one key: read the current file (comments allowed, like loadConfig), change the key
// (an undefined value removes it) and write atomically. The file is re-serialised, so comments
// in it are not kept. An unreadable or invalid file is never overwritten; the change then only
// lives in memory.
bool UserConfigBackend::writeConfigValue(const QString &key, const QJsonValue &value)
{
    QJsonObject object;
    QFile current(m_userConfigPath);
    if (current.exists()) {
        if (!current.open(QIODevice::ReadOnly)) {
            qWarning().noquote() << QStringLiteral("[UserConfig] Not saving \"%1\": cannot read %2 (%3)")
                .arg(key, m_userConfigPath, current.errorString());
            return false;
        }
        const QByteArray bytes = current.readAll();
        current.close();
        if (!bytes.trimmed().isEmpty()) {
            QJsonParseError error;
            const QJsonDocument document = QJsonDocument::fromJson(JsonComments::strip(bytes), &error);
            if (error.error != QJsonParseError::NoError || !document.isObject()) {
                qWarning().noquote() << QStringLiteral("[UserConfig] Not saving \"%1\": %2 is not a valid JSON object")
                    .arg(key, m_userConfigPath);
                return false;
            }
            object = document.object();
        }
    }

    if (value.isUndefined())
        object.remove(key);
    else
        object.insert(key, value);

    QDir().mkpath(QFileInfo(m_userConfigPath).absolutePath());
    QSaveFile file(m_userConfigPath);
    const bool opened = file.open(QIODevice::WriteOnly);
    if (opened)
        UserConfigFile::restrictIfSecret(file, object);
    if (!opened
            || file.write(QJsonDocument(object).toJson(QJsonDocument::Indented)) < 0
            || !file.commit()) {
        qWarning().noquote() << QStringLiteral("[UserConfig] Could not save \"%1\" to %2: %3")
            .arg(key, m_userConfigPath, file.errorString());
        return false;
    }
    return true;
}

void UserConfigBackend::loadConfig()
{
    updateWatchedPaths();

    QJsonObject configObject;
    QString nextConfigError;

    QFile configFile(m_userConfigPath);
    if (configFile.exists()) {
        if (!configFile.open(QIODevice::ReadOnly)) {
            nextConfigError = QStringLiteral("Could not read %1: %2").arg(m_userConfigPath, configFile.errorString());
        } else {
            const QByteArray configBytes = configFile.readAll();
            if (!configBytes.trimmed().isEmpty()) {
                const QByteArray strippedBytes = JsonComments::strip(configBytes);
                QJsonParseError parseError;
                const QJsonDocument document = QJsonDocument::fromJson(strippedBytes, &parseError);
                if (parseError.error != QJsonParseError::NoError) {
                    nextConfigError = QStringLiteral("Invalid JSON in %1 at offset %2: %3")
                        .arg(m_userConfigPath)
                        .arg(parseError.offset)
                        .arg(parseError.errorString());
                } else if (!document.isObject()) {
                    nextConfigError = QStringLiteral("Invalid JSON in %1: root value must be an object").arg(m_userConfigPath);
                } else {
                    configObject = document.object();
                }
            }
        }
    }

    updateField(this, m_configError, nextConfigError, &UserConfigBackend::configErrorChanged);
    // A broken file must not reset everything to defaults; keep the last good values.
    if (!nextConfigError.isEmpty())
        return;

    updateField(this, m_iconFontFamily, jsonString(configObject, QLatin1String("iconFontFamily"), QStringLiteral("JetBrainsMono Nerd Font")), &UserConfigBackend::iconFontFamilyChanged);
    updateField(this, m_textFontFamily, jsonString(configObject, QLatin1String("textFontFamily"), QStringLiteral("Sans Serif")), &UserConfigBackend::textFontFamilyChanged);
    updateField(this, m_heroFontFamily, jsonString(configObject, QLatin1String("heroFontFamily"), QStringLiteral("Sans Serif")), &UserConfigBackend::heroFontFamilyChanged);
    updateField(this, m_timeFontFamily, jsonString(configObject, QLatin1String("timeFontFamily"), QStringLiteral("Sans Serif")), &UserConfigBackend::timeFontFamilyChanged);
    const QString configuredClockFormat = jsonString(configObject, QLatin1String("clockFormat"), QStringLiteral("12"));
    updateField(this, m_clockFormat, configuredClockFormat == QLatin1String("24") ? QStringLiteral("24") : QStringLiteral("12"), &UserConfigBackend::clockFormatChanged);
    updateField(this, m_tlpSudoPassword, jsonString(configObject, QLatin1String("tlpSudoPassword"), m_defaultTlpSudoPassword), &UserConfigBackend::tlpSudoPasswordChanged);
    updateField(this, m_tlpPermissionMode, jsonString(configObject, QLatin1String("tlpPermissionMode"), QStringLiteral("skip")), &UserConfigBackend::tlpPermissionModeChanged);
    updateField(this, m_powerProfileDriver, jsonString(configObject, QLatin1String("powerProfileDriver"), QStringLiteral("auto")), &UserConfigBackend::powerProfileDriverChanged);
    updateField(this, m_dynamicIslandPrimaryButton, jsonInt(configObject, QLatin1String("dynamicIslandPrimaryButton"), 1), &UserConfigBackend::dynamicIslandPrimaryButtonChanged);
    // The expanded player is no longer a click action: missing or legacy values mean "none".
    const QString primaryAction = jsonString(configObject, QLatin1String("dynamicIslandPrimaryAction"), QStringLiteral("none"));
    updateField(this, m_dynamicIslandPrimaryAction,
                primaryAction == QLatin1String("toggleExpandedPlayer") ? QStringLiteral("none") : primaryAction,
                &UserConfigBackend::dynamicIslandPrimaryActionChanged);
    updateField(this, m_dynamicIslandSecondaryButton, jsonInt(configObject, QLatin1String("dynamicIslandSecondaryButton"), 3), &UserConfigBackend::dynamicIslandSecondaryButtonChanged);
    const QString batteryMode = jsonString(configObject, QLatin1String("islandBatteryMode"), QStringLiteral("low")).trimmed().toLower();
    updateField(this, m_islandBatteryMode,
                (batteryMode == QLatin1String("always") || batteryMode == QLatin1String("never")) ? batteryMode : QStringLiteral("low"),
                &UserConfigBackend::islandBatteryModeChanged);
    updateField(this, m_islandAutoHideKeepActivities, jsonBool(configObject, QLatin1String("islandAutoHideKeepActivities"), true), &UserConfigBackend::islandAutoHideKeepActivitiesChanged);
    updateField(this, m_islandEdge,
                jsonString(configObject, QLatin1String("islandEdge"), QString()).trimmed().toLower() == QLatin1String("bottom")
                    ? QStringLiteral("bottom")
                    : QStringLiteral("top"),
                &UserConfigBackend::islandEdgeChanged);
    updateField(this, m_notificationTimeout, jsonBoundedInt(configObject, QLatin1String("notificationTimeout"), 8, 1, 600), &UserConfigBackend::notificationTimeoutChanged);
    updateField(this, m_notificationTimeoutLow, jsonBoundedInt(configObject, QLatin1String("notificationTimeoutLow"), 5, 1, 600), &UserConfigBackend::notificationTimeoutLowChanged);
    updateField(this, m_idleInhibitCommand,
                commandArguments(jsonString(configObject, QLatin1String("idleInhibitCommand"), QString())),
                &UserConfigBackend::idleInhibitCommandChanged);
    updateField(this, m_lockCommand,
                commandArguments(jsonString(configObject, QLatin1String("lockCommand"), QString())),
                &UserConfigBackend::lockCommandChanged);
    updateField(this, m_dynamicIslandSecondaryAction, jsonString(configObject, QLatin1String("dynamicIslandSecondaryAction"), QStringLiteral("toggleControlCenter")), &UserConfigBackend::dynamicIslandSecondaryActionChanged);
    updateField(this, m_dynamicIslandMiddleButton, jsonInt(configObject, QLatin1String("dynamicIslandMiddleButton"), 2), &UserConfigBackend::dynamicIslandMiddleButtonChanged);
    updateField(this, m_dynamicIslandMiddleAction, jsonString(configObject, QLatin1String("dynamicIslandMiddleAction"), QStringLiteral("toggleClipboard")), &UserConfigBackend::dynamicIslandMiddleActionChanged);
    // Hover opens only the control center (2); anything else, including the old 1 (expanded
    // player), means off.
    updateField(this, m_hoverExpandAction,
                jsonInt(configObject, QLatin1String("hoverExpandAction"), 0) == 2 ? 2 : 0,
                &UserConfigBackend::hoverExpandActionChanged);
    updateField(this, m_islandAutoHideEnabled, jsonBool(configObject, QLatin1String("islandAutoHideEnabled"), true), &UserConfigBackend::islandAutoHideEnabledChanged);
    updateField(this, m_islandAutoHideDelayMs, jsonBoundedInt(configObject, QLatin1String("islandAutoHideDelayMs"), 1000, 100, 10000), &UserConfigBackend::islandAutoHideDelayMsChanged);
    updateField(this, m_islandWidth, jsonInt(configObject, QLatin1String("islandWidth"), 140), &UserConfigBackend::islandWidthChanged);
    updateField(this, m_islandBackgroundOpacity, jsonBoundedInt(configObject, QLatin1String("islandBackgroundOpacity"), 60, 0, 100), &UserConfigBackend::islandBackgroundOpacityChanged);
    updateField(this, m_islandBlurEnabled, jsonBool(configObject, QLatin1String("islandBlurEnabled"), true), &UserConfigBackend::islandBlurEnabledChanged);
    updateField(this, m_islandHeight, jsonInt(configObject, QLatin1String("islandHeight"), 38), &UserConfigBackend::islandHeightChanged);
    updateField(this, m_islandExclusiveZone, jsonBoundedInt(configObject, QLatin1String("islandExclusiveZone"), 45, 0, 1000), &UserConfigBackend::islandExclusiveZoneChanged);
    updateField(this, m_islandTopMargin, jsonBoundedInt(configObject, QLatin1String("islandTopMargin"), 4, 0, 1000), &UserConfigBackend::islandTopMarginChanged);
    updateField(this, m_islandPositionX, jsonInt(configObject, QLatin1String("islandPositionX"), 50), &UserConfigBackend::islandPositionXChanged);
    updateField(this, m_bodyFontSize, jsonInt(configObject, QLatin1String("bodyFontSize"), 16), &UserConfigBackend::bodyFontSizeChanged);
    updateField(this, m_titleFontSize, jsonInt(configObject, QLatin1String("titleFontSize"), 20), &UserConfigBackend::titleFontSizeChanged);
    updateField(this, m_iconFontSize, jsonInt(configObject, QLatin1String("iconFontSize"), 18), &UserConfigBackend::iconFontSizeChanged);
    updateField(this, m_weatherEnabled, jsonBool(configObject, QLatin1String("weatherEnabled"), true), &UserConfigBackend::weatherEnabledChanged);
    updateField(this, m_weatherLocation, jsonString(configObject, QLatin1String("weatherLocation"), QString()), &UserConfigBackend::weatherLocationChanged);
    updateField(this, m_weatherUnits, jsonString(configObject, QLatin1String("weatherUnits"), QStringLiteral("metric")), &UserConfigBackend::weatherUnitsChanged);
    updateField(this, m_weatherRefreshInterval, jsonBoundedInt(configObject, QLatin1String("weatherRefreshInterval"), 1800000, 60000, 86400000), &UserConfigBackend::weatherRefreshIntervalChanged);
    updateField(this, m_colorPaletteEnabled, jsonBool(configObject, QLatin1String("colorPaletteEnabled"), true), &UserConfigBackend::colorPaletteEnabledChanged);
    updateField(this, m_colorsFilePath, jsonString(configObject, QLatin1String("colorsFilePath"), QString()), &UserConfigBackend::colorsFilePathChanged);
    updateField(this, m_dynamicBatteryColorEnabled, jsonBool(configObject, QLatin1String("dynamicBatteryColorEnabled"), true), &UserConfigBackend::dynamicBatteryColorEnabledChanged);
    updateField(this, m_marqueeTrackTitleEnabled, jsonBool(configObject, QLatin1String("marqueeTrackTitleEnabled"), true), &UserConfigBackend::marqueeTrackTitleEnabledChanged);
    updateField(this, m_privacyCameraBubbleEnabled, jsonBool(configObject, QLatin1String("privacyCameraBubbleEnabled"), true), &UserConfigBackend::privacyCameraBubbleEnabledChanged);
    updateField(this, m_privacyMicBubbleEnabled, jsonBool(configObject, QLatin1String("privacyMicBubbleEnabled"), true), &UserConfigBackend::privacyMicBubbleEnabledChanged);

    QString nextAvatarPath = jsonString(configObject, QLatin1String("avatarPath"), jsonString(configObject, QLatin1String("displayPicture"), QString())).trimmed();
    const QString home = QDir::homePath();
    if (nextAvatarPath.startsWith(QLatin1String("~"))) {
        nextAvatarPath.replace(0, 1, home);
    }
    if (nextAvatarPath.startsWith(QLatin1String("file://"))) {
        nextAvatarPath = QUrl(nextAvatarPath).toLocalFile();
    }
    if (!nextAvatarPath.isEmpty() && !QFileInfo::exists(nextAvatarPath)) {
        nextAvatarPath.clear();
    }
    if (nextAvatarPath.isEmpty()) {
        // Check ChillPill-Shell config for fallback
        QFile cpFile(home + QStringLiteral("/.config/chillpill-shell/config.jsonc"));
        if (cpFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QJsonDocument cpDoc = QJsonDocument::fromJson(JsonComments::strip(cpFile.readAll()));
            if (cpDoc.isObject()) {
                QString cpPic = cpDoc.object().value(QStringLiteral("displayPicture")).toString().trimmed();
                if (!cpPic.isEmpty()) {
                    if (cpPic.startsWith(QLatin1String("~"))) {
                        cpPic.replace(0, 1, home);
                    }
                    if (cpPic.startsWith(QLatin1String("file://"))) {
                        cpPic = QUrl(cpPic).toLocalFile();
                    }
                    if (QFileInfo::exists(cpPic)) {
                        nextAvatarPath = cpPic;
                    }
                }
            }
        }
    }
    if (nextAvatarPath.isEmpty()) {
        const QStringList candidates = {
            home + QStringLiteral("/.config/tide-island/avatar.png"),
            home + QStringLiteral("/.config/tide-island/avatar.jpg"),
            home + QStringLiteral("/.config/tide-island/avatar.jpeg"),
            home + QStringLiteral("/.pfp.png"),
            home + QStringLiteral("/.pfp.jpg"),
            home + QStringLiteral("/.pfp.jpeg"),
            home + QStringLiteral("/.face"),
            home + QStringLiteral("/.face.icon"),
            home + QStringLiteral("/.avatar.png"),
            home + QStringLiteral("/.avatar.jpg")
        };
        for (const QString &cand : candidates) {
            if (QFileInfo::exists(cand)) {
                nextAvatarPath = cand;
                break;
            }
        }
    }
    updateField(this, m_avatarPath, nextAvatarPath, &UserConfigBackend::avatarPathChanged);

    updateField(this, m_doNotDisturb, jsonBool(configObject, QLatin1String("doNotDisturb"), false), &UserConfigBackend::doNotDisturbChanged);

    updateWatchedPaths();
}

void UserConfigBackend::updateWatchedPaths()
{
    const QString configDirectory = QFileInfo(m_userConfigPath).absolutePath();
    const QString configParentDirectory = QFileInfo(configDirectory).absolutePath();
    const QSet<QString> wantedFiles = QFileInfo::exists(m_userConfigPath)
        ? QSet<QString>{m_userConfigPath}
        : QSet<QString>{};
    QSet<QString> wantedDirectories;
    if (QFileInfo::exists(configParentDirectory))
        wantedDirectories.insert(configParentDirectory);
    if (QFileInfo::exists(configDirectory))
        wantedDirectories.insert(configDirectory);

    const QStringList currentFiles = m_watcher.files();
    for (const QString &path : currentFiles) {
        if (!wantedFiles.contains(path))
            m_watcher.removePath(path);
    }

    const QStringList currentDirectories = m_watcher.directories();
    for (const QString &path : currentDirectories) {
        if (!wantedDirectories.contains(path))
            m_watcher.removePath(path);
    }

    for (const QString &path : wantedFiles) {
        if (!m_watcher.files().contains(path))
            m_watcher.addPath(path);
    }

    for (const QString &path : wantedDirectories) {
        if (!m_watcher.directories().contains(path))
            m_watcher.addPath(path);
    }
}

QString UserConfigBackend::configHome() const
{
    const QByteArray xdgConfigHome = qgetenv("XDG_CONFIG_HOME");
    if (!xdgConfigHome.isEmpty())
        return QString::fromLocal8Bit(xdgConfigHome);

    const QByteArray home = qgetenv("HOME");
    return home.isEmpty()
        ? QStringLiteral(".")
        : QString::fromLocal8Bit(home) + QStringLiteral("/.config");
}
