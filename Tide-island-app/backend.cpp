#include "backend.hpp"
#include "../common/JsonComments.h"

#include <QClipboard>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
#include <QTemporaryFile>
#include <QVariant>
#include <QVariantList>

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

QString expandedPath(const QString &path)
{
    return path.startsWith(QStringLiteral("~/")) ? QDir::homePath() + path.sliced(1) : path;
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
    load();
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

QString Backend::matugenTemplatePath() const
{
    const QString xdgConfig = QString::fromLocal8Bit(qgetenv("XDG_CONFIG_HOME"));
    const QString configBase = !xdgConfig.isEmpty() ? xdgConfig : (QDir::homePath() + QStringLiteral("/.config"));
    return configBase + QStringLiteral("/matugen/templates/tide-island-colors.json");
}

bool Backend::isMatugenTemplateInstalled() const
{
    return QFileInfo::exists(matugenTemplatePath());
}

QString Backend::matugenTemplateContent() const
{
    return QStringLiteral("{\n"
                          "  \"colors\": {\n"
                          "    \"primary\": \"{{colors.primary.default.hex}}\",\n"
                          "    \"on_primary\": \"{{colors.on_primary.default.hex}}\",\n"
                          "    \"primary_container\": \"{{colors.primary_container.default.hex}}\",\n"
                          "    \"on_primary_container\": \"{{colors.on_primary_container.default.hex}}\",\n"
                          "    \"secondary\": \"{{colors.secondary.default.hex}}\",\n"
                          "    \"on_secondary\": \"{{colors.on_secondary.default.hex}}\",\n"
                          "    \"secondary_container\": \"{{colors.secondary_container.default.hex}}\",\n"
                          "    \"on_secondary_container\": \"{{colors.on_secondary_container.default.hex}}\",\n"
                          "    \"tertiary\": \"{{colors.tertiary.default.hex}}\",\n"
                          "    \"on_tertiary\": \"{{colors.on_tertiary.default.hex}}\",\n"
                          "    \"tertiary_container\": \"{{colors.tertiary_container.default.hex}}\",\n"
                          "    \"on_tertiary_container\": \"{{colors.on_tertiary_container.default.hex}}\",\n"
                          "    \"error\": \"{{colors.error.default.hex}}\",\n"
                          "    \"on_error\": \"{{colors.on_error.default.hex}}\",\n"
                          "    \"surface\": \"{{colors.surface.default.hex}}\",\n"
                          "    \"on_surface\": \"{{colors.on_surface.default.hex}}\",\n"
                          "    \"surface_variant\": \"{{colors.surface_variant.default.hex}}\",\n"
                          "    \"on_surface_variant\": \"{{colors.on_surface_variant.default.hex}}\",\n"
                          "    \"outline\": \"{{colors.outline.default.hex}}\",\n"
                          "    \"outline_variant\": \"{{colors.outline_variant.default.hex}}\",\n"
                          "    \"inverse_primary\": \"{{colors.inverse_primary.default.hex}}\",\n"
                          "    \"surface_container_lowest\": \"{{colors.surface_container_lowest.default.hex}}\",\n"
                          "    \"surface_container_low\": \"{{colors.surface_container_low.default.hex}}\",\n"
                          "    \"surface_container\": \"{{colors.surface_container.default.hex}}\",\n"
                          "    \"surface_container_high\": \"{{colors.surface_container_high.default.hex}}\",\n"
                          "    \"surface_container_highest\": \"{{colors.surface_container_highest.default.hex}}\",\n"
                          "    \"battery_charging\": \"{{colors.primary.default.hex}}\",\n"
                          "    \"battery_high\": \"{{colors.primary.default.hex}}\",\n"
                          "    \"battery_medium\": \"{{colors.secondary.default.hex}}\",\n"
                          "    \"battery_low\": \"{{colors.tertiary.default.hex}}\",\n"
                          "    \"battery_critical\": \"{{colors.error.default.hex}}\"\n"
                          "  }\n"
                          "}\n");
}

bool Backend::installMatugenTemplate()
{
    const QString targetPath = matugenTemplatePath();
    const QDir targetDir = QFileInfo(targetPath).dir();
    if (!targetDir.exists() && !targetDir.mkpath(QStringLiteral("."))) {
        setErrorString(QStringLiteral("Failed to create directory: %1").arg(targetDir.absolutePath()));
        return false;
    }

    QFile file(targetPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        setErrorString(QStringLiteral("Failed to write template to %1: %2").arg(targetPath, file.errorString()));
        return false;
    }

    const QByteArray data = matugenTemplateContent().toUtf8();
    if (file.write(data) != data.size()) {
        setErrorString(QStringLiteral("Incomplete write to %1").arg(targetPath));
        return false;
    }

    return true;
}

QString Backend::matugenTomlSnippet() const
{
    return QStringLiteral(
        "[templates.tide_island]\n"
        "input_path = \"~/.config/matugen/templates/tide-island-colors.json\"\n"
        "output_path = \"~/.config/tide-island/colors.json\""
    );
}

