#pragma once

#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QVariantList>

#include <unordered_map>

struct QStringHash {
    std::size_t operator()(const QString &key) const noexcept;
};

using UserConfigMap = std::unordered_map<QString, QVariant, QStringHash>;

class Backend final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString userConfigPath READ userConfigPath CONSTANT)
    Q_PROPERTY(QString homeDirectory READ homeDirectory CONSTANT)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)
    Q_PROPERTY(QVariantMap userConfig READ userConfig NOTIFY userConfigChanged)
    Q_PROPERTY(QString colorScheme READ colorScheme WRITE setColorScheme NOTIFY colorSchemeChanged)

public:
    explicit Backend(QObject *parent = nullptr);

    QString userConfigPath() const;
    QString homeDirectory() const;
    QString errorString() const;
    QVariantMap userConfig() const;
    QString colorScheme() const;

    Q_INVOKABLE bool save(const QVariantMap &changes, const QStringList &removedKeys = QStringList());
    Q_INVOKABLE void setColorScheme(const QString &colorScheme);
    Q_INVOKABLE bool copyToClipboard(const QString &text);
    Q_INVOKABLE bool hasPowerProfilesCtl() const;
    Q_INVOKABLE bool hasTlp() const;
    Q_INVOKABLE QString detectedPowerProfileDriver() const;
    Q_INVOKABLE QString matugenTemplateContent() const;
    Q_INVOKABLE QString matugenTemplatePath() const;
    Q_INVOKABLE bool isMatugenTemplateInstalled() const;
    Q_INVOKABLE bool installMatugenTemplate();
    Q_INVOKABLE QString matugenTomlSnippet() const;
    Q_INVOKABLE QString detectActiveWallpaper() const;

signals:
    void errorStringChanged();
    void colorSchemeChanged();
    void userConfigChanged();

private:
    void load();
    bool readUserConfigObject(QJsonObject &object);
    void setErrorString(const QString &errorString);
    QVariantMap toVariantMap() const;
    void setUserConfig(const QVariantMap &userConfig);

    QString m_userConfigPath;
    QString m_errorString;
    QString m_colorScheme;
    UserConfigMap m_userConfig;
};
