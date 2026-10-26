#include "backend.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QTest>

namespace {
bool writeTextFile(const QString &path, const QByteArray &contents, QFileDevice::Permissions permissions = {})
{
    QFileInfo info(path);
    if (!QDir().mkpath(info.absolutePath()))
        return false;

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        return false;
    file.write(contents);
    file.close();

    if (permissions != QFileDevice::Permissions{})
        return file.setPermissions(permissions);
    return true;
}

QString readTextFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    return QString::fromUtf8(file.readAll());
}
}

class ConfigAppTests : public QObject {
    Q_OBJECT

private slots:
    void configAppColorSchemePersists();
    void powerProfileDetectionResolvesCorrectly();
    void saveWritesOnlyChangedKeysOverCurrentFile();
    void saveRefusesToOverwriteInvalidConfig();
};

void ConfigAppTests::configAppColorSchemePersists()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());

    Backend backend;
    QCOMPARE(backend.colorScheme(), QStringLiteral("light"));
    backend.setColorScheme(QStringLiteral("dark"));
    QCOMPARE(backend.colorScheme(), QStringLiteral("dark"));

    Backend reloaded;
    QCOMPARE(reloaded.colorScheme(), QStringLiteral("dark"));
    reloaded.setColorScheme(QStringLiteral("unsupported"));
    QCOMPARE(reloaded.colorScheme(), QStringLiteral("light"));
}

void ConfigAppTests::powerProfileDetectionResolvesCorrectly()
{
    QTemporaryDir fakeBin;
    QVERIFY(fakeBin.isValid());

    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", fakeBin.path().toLocal8Bit());

    {
        Backend backend;
        QVERIFY(!backend.hasPowerProfilesCtl());
        QVERIFY(!backend.hasTlp());
        QCOMPARE(backend.detectedPowerProfileDriver(), QStringLiteral("none"));
    }

    const QString fakePpc = fakeBin.path() + QStringLiteral("/powerprofilesctl");
    QVERIFY(writeTextFile(fakePpc, "#!/bin/sh\nexit 0\n", QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));

    {
        Backend backend;
        QVERIFY(backend.hasPowerProfilesCtl());
        QCOMPARE(backend.detectedPowerProfileDriver(), QStringLiteral("powerprofilesctl"));
    }

    QFile::remove(fakePpc);

    const QString fakeTlp = fakeBin.path() + QStringLiteral("/tlp");
    QVERIFY(writeTextFile(fakeTlp, "#!/bin/sh\nexit 0\n", QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));

    {
        Backend backend;
        QVERIFY(!backend.hasPowerProfilesCtl());
        QVERIFY(backend.hasTlp());
        QCOMPARE(backend.detectedPowerProfileDriver(), QStringLiteral("tlp"));
    }

    qputenv("PATH", originalPath);
}

void ConfigAppTests::saveWritesOnlyChangedKeysOverCurrentFile()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());

    const QString configPath = configHome.path() + QStringLiteral("/tide-island/userconfig.json");
    QVERIFY(writeTextFile(configPath,
        "{ \"doNotDisturb\": false, \"islandWidth\": 140, \"avatarPath\": \"/a.png\" }\n"));

    Backend backend;
    QCOMPARE(backend.userConfig().value(QStringLiteral("doNotDisturb")).toBool(), false);

    // The shell changes the file after the app has loaded it.
    QVERIFY(writeTextFile(configPath,
        "// toggled from the island\n"
        "{ \"doNotDisturb\": true, \"islandWidth\": 140, \"avatarPath\": \"/a.png\" }\n"));

    QVariantMap changes;
    changes.insert(QStringLiteral("islandWidth"), 200);
    QVERIFY(backend.save(changes, {QStringLiteral("avatarPath")}));

    const QJsonObject saved = QJsonDocument::fromJson(readTextFile(configPath).toUtf8()).object();
    QCOMPARE(saved.value(QStringLiteral("doNotDisturb")).toBool(), true);
    QCOMPARE(saved.value(QStringLiteral("islandWidth")).toInt(), 200);
    QVERIFY(!saved.contains(QStringLiteral("avatarPath")));
    QCOMPARE(backend.userConfig().value(QStringLiteral("doNotDisturb")).toBool(), true);
    QVERIFY(backend.errorString().isEmpty());
}

void ConfigAppTests::saveRefusesToOverwriteInvalidConfig()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());

    const QString configPath = configHome.path() + QStringLiteral("/tide-island/userconfig.json");
    const QByteArray broken = "{ \"doNotDisturb\": true,\n";
    QVERIFY(writeTextFile(configPath, broken));

    Backend backend;
    QVERIFY(!backend.errorString().isEmpty());

    QVariantMap changes;
    changes.insert(QStringLiteral("islandWidth"), 200);
    QVERIFY(!backend.save(changes));
    QCOMPARE(readTextFile(configPath), QString::fromUtf8(broken));
    QVERIFY(!backend.errorString().isEmpty());
}

QTEST_GUILESS_MAIN(ConfigAppTests)

#include "config_app_tests.moc"
