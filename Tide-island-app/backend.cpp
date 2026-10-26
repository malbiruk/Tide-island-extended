#include "backend.hpp"
#include "../common/JsonComments.h"
#include "../common/UserConfigFile.h"

#include <QClipboard>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
#include <QVariant>

namespace {
constexpr auto colorSchemeKey = "appearance/colorScheme";

QString configHome()
{
    const QByteArray xdgConfigHome = qgetenv("XDG_CONFIG_HOME");
    if (!xdgConfigHome.isEmpty())
        return QString::fromLocal8Bit(xdgConfigHome);

    return QDir::homePath() + QStringLiteral("/.config");
}

QString configAppSettingsPath()
{
    return configHome() + QStringLiteral("/tide-island/config-app.ini");
}

QString normalizedColorScheme(const QString &colorScheme)
{
    return colorScheme.trimmed().compare(QStringLiteral("dark"), Qt::CaseInsensitive) == 0
        ? QStringLiteral("dark")
        : QStringLiteral("light");
}

UserConfigMap toUserConfigMap(const QVariantMap &userConfig){
    UserConfigMap result;
    result.reserve(static_cast<std::size_t>(userConfig.size()));

    for (auto it = userConfig.cbegin(); it != userConfig.cend(); ++it)
        result.emplace(it.key(), it.value());

    return result;
}
}

std::size_t QStringHash::operator()(const QString &key) const noexcept{
    return static_cast<std::size_t>(qHash(key));
}

Backend::Backend(QObject *parent)
    : QObject(parent)
    , m_userConfigPath(configHome() + QStringLiteral("/tide-island/userconfig.json"))
{
    QSettings settings(configAppSettingsPath(), QSettings::IniFormat);
    m_colorScheme = normalizedColorScheme(
        settings.value(QString::fromLatin1(colorSchemeKey), QStringLiteral("light")).toString());

    // The shell writes some keys itself (doNotDisturb, avatarPath): follow the file so the
    // pages never show stale values. Saves replace the file, so its directory is watched too.
    m_reloadTimer.setSingleShot(true);
    m_reloadTimer.setInterval(150);
    connect(&m_reloadTimer, &QTimer::timeout, this, &Backend::reload);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, &m_reloadTimer, qOverload<>(&QTimer::start));
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, &m_reloadTimer, qOverload<>(&QTimer::start));
    reload();
}

void Backend::reload(){
    load();
    const QFileInfo configInfo(m_userConfigPath);
    if (configInfo.dir().exists() && !m_watcher.directories().contains(configInfo.absolutePath()))
        m_watcher.addPath(configInfo.absolutePath());
    if (configInfo.exists() && !m_watcher.files().contains(configInfo.absoluteFilePath()))
        m_watcher.addPath(configInfo.absoluteFilePath());
}

QString Backend::userConfigPath() const{
    return m_userConfigPath;
}

QString Backend::homeDirectory() const{
    return QDir::homePath();
}

QString Backend::errorString() const{
    return m_errorString;
}

QVariantMap Backend::userConfig() const{
    return toVariantMap();
}

QString Backend::colorScheme() const{
    return m_colorScheme;
}

void Backend::setColorScheme(const QString &colorScheme){
    const QString normalized = normalizedColorScheme(colorScheme);
    if (m_colorScheme == normalized)
        return;

    m_colorScheme = normalized;
    QSettings settings(configAppSettingsPath(), QSettings::IniFormat);
    settings.setValue(QString::fromLatin1(colorSchemeKey), m_colorScheme);
    settings.sync();
    emit colorSchemeChanged();
}

// Applies only the given keys on top of the file as it is now, so values written
// by the shell since the app loaded (e.g. doNotDisturb) are not reverted.
bool Backend::save(const QVariantMap &changes, const QStringList &removedKeys){
    QJsonObject current;
    if (!readUserConfigObject(current))
        return false;

    QJsonObject merged = current;
    for (auto it = changes.cbegin(); it != changes.cend(); ++it)
        merged.insert(it.key(), QJsonValue::fromVariant(it.value()));
    for (const QString &key : removedKeys)
        merged.remove(key);

    if (merged == current) {
        setUserConfig(current.toVariantMap());
        setErrorString(QString());
        return true;
    }

    const QFileInfo configInfo(m_userConfigPath);
    QDir directory(configInfo.absolutePath());
    if (!directory.exists() && !QDir().mkpath(configInfo.absolutePath())) {
        setErrorString(QStringLiteral("Could not create %1").arg(configInfo.absolutePath()));
        return false;
    }

    const QJsonDocument document(merged);
    QSaveFile file(m_userConfigPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setErrorString(QStringLiteral("Could not write %1: %2").arg(m_userConfigPath, file.errorString()));
        return false;
    }

    UserConfigFile::restrictIfSecret(file, merged);
    file.write(document.toJson(QJsonDocument::Indented));
    if (!file.commit()) {
        setErrorString(QStringLiteral("Could not save %1: %2").arg(m_userConfigPath, file.errorString()));
        return false;
    }

    setUserConfig(merged.toVariantMap());
    setErrorString(QString());
    return true;
}

bool Backend::copyToClipboard(const QString &text){
    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        setErrorString(QStringLiteral("Clipboard is not available."));
        return false;
    }

    clipboard->setText(text);
    setErrorString(QString());
    return true;
}

void Backend::load(){
    QJsonObject object;
    if (!readUserConfigObject(object)) {
        setUserConfig({});
        return;
    }

    setUserConfig(object.toVariantMap());
    setErrorString(QString());
}

// A missing or empty file reads as an empty object; an unreadable or invalid one
// sets the error string and returns false so callers never write over it.
bool Backend::readUserConfigObject(QJsonObject &object){
    object = QJsonObject();
    QFile file(m_userConfigPath);
    if (!file.exists())
        return true;

    if (!file.open(QIODevice::ReadOnly)) {
        setErrorString(QStringLiteral("Could not read %1: %2").arg(m_userConfigPath, file.errorString()));
        return false;
    }

    const QByteArray contents = JsonComments::strip(file.readAll());
    if (contents.trimmed().isEmpty())
        return true;

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(contents, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        setErrorString(QStringLiteral("Invalid JSON in %1 at offset %2: %3")
            .arg(m_userConfigPath)
            .arg(parseError.offset)
            .arg(parseError.errorString()));
        return false;
    }

    if (!document.isObject()) {
        setErrorString(QStringLiteral("Invalid JSON in %1: root value must be an object.").arg(m_userConfigPath));
        return false;
    }

    object = document.object();
    return true;
}

void Backend::setErrorString(const QString &errorString){
    if (m_errorString == errorString)
        return;

    m_errorString = errorString;
    emit errorStringChanged();
}

QVariantMap Backend::toVariantMap() const{
    QVariantMap result;
    for (const auto &[key, value] : m_userConfig)
        result.insert(key, value);
    return result;
}

void Backend::setUserConfig(const QVariantMap &userConfig){
    m_userConfig = toUserConfigMap(userConfig);
    emit userConfigChanged();
}

bool Backend::hasPowerProfilesCtl() const
{
    return !QStandardPaths::findExecutable(QStringLiteral("powerprofilesctl")).isEmpty();
}

bool Backend::hasTlp() const
{
    return !QStandardPaths::findExecutable(QStringLiteral("tlp")).isEmpty();
}

QString Backend::detectedPowerProfileDriver() const
{
    if (hasPowerProfilesCtl())
        return QStringLiteral("powerprofilesctl");
    if (hasTlp())
        return QStringLiteral("tlp");
    return QStringLiteral("none");
}

