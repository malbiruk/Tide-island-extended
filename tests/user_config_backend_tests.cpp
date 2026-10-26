#include "UserConfigBackend.h"
#include "../Tide-island-app/backend.hpp"
#include "../common/JsonComments.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

namespace {
bool writeConfig(const QString &home, const QByteArray &contents) {
    if (!QDir().mkpath(home + "/tide-island")) return false;
    QFile file(home + "/tide-island/userconfig.json");
    return file.open(QIODevice::WriteOnly) && file.write(contents) == contents.size();
}
}

class UserConfigBackendTests : public QObject {
    Q_OBJECT
private slots:
    void blurDefaultsAndLiveReloadPreserveOpacity() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), "{}"));
        UserConfigBackend runtime;
        QVERIFY(runtime.islandBlurEnabled());
        QCOMPARE(runtime.islandBackgroundOpacity(), 60);
        QSignalSpy changed(&runtime, &UserConfigBackend::islandBlurEnabledChanged);

        Backend settings;
        auto config = settings.userConfig();
        config.insert("islandBlurEnabled", false);
        config.insert("islandBackgroundOpacity", 60);
        QVERIFY(settings.save(config));
        runtime.reload();
        QVERIFY(!runtime.islandBlurEnabled());
        QCOMPARE(runtime.islandBackgroundOpacity(), 60);
        QCOMPARE(changed.count(), 1);

        config.insert("islandBlurEnabled", true);
        QVERIFY(settings.save(config));
        runtime.reload();
        QVERIFY(runtime.islandBlurEnabled());
        QCOMPARE(runtime.islandBackgroundOpacity(), 60);
        QCOMPARE(changed.count(), 2);

        QVERIFY(writeConfig(directory.path(), "{\"islandBlurEnabled\":\"false\"}"));
        runtime.reload();
        QVERIFY(runtime.islandBlurEnabled());
    }

    void stringsAndCommentsMatchAcrossBothConsumers_data() {
        QTest::addColumn<QByteArray>("input");
        QTest::addColumn<QString>("command");
        QTest::newRow("literal-block-comment")
            << QByteArray(R"json({"wallpaperCustomCommand":"printf '/*literal*/'"})json")
            << QStringLiteral("printf '/*literal*/'");
        QTest::newRow("even-backslashes-before-quote")
            << QByteArray("{\"wallpaperCustomCommand\":\"C:\\\\\", // real comment\r\n\"wallpaperPath\":\"https://example.com/a/*b*/\"}")
            << QStringLiteral("C:\\");
        for (const auto &command : {QStringLiteral("printf \"quoted // /* text */\""),
                                   QStringLiteral("\\\\\"// still a string /* */\\\\"),
                                   QStringLiteral("第一行\n第二行\t/*文字*/ https://example.com/😀")}) {
            auto input = QJsonDocument(QJsonObject {{"wallpaperCustomCommand", command}}).toJson();
            input.prepend("/* heading\r\n comment */\r\n// line comment\r\n");
            input.append("// trailing comment without newline");
            QTest::newRow(qPrintable(command)) << input << command;
        }
    }

    void stringsAndCommentsMatchAcrossBothConsumers() {
        QFETCH(QByteArray, input);
        QFETCH(QString, command);
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), input));

        UserConfigBackend runtime;
        Backend settings;
        QVERIFY2(runtime.configError().isEmpty(), qPrintable(runtime.configError()));
        QVERIFY2(settings.errorString().isEmpty(), qPrintable(settings.errorString()));
        QCOMPARE(runtime.wallpaperCustomCommand(), command);
        QCOMPARE(settings.userConfig().value("wallpaperCustomCommand").toString(), command);

        // A settings save and live runtime reload must retain the same bytes.
        QVERIFY(settings.save(settings.userConfig()));
        runtime.reload();
        QCOMPARE(runtime.configError(), QString());
        QCOMPARE(runtime.wallpaperCustomCommand(), command);
    }

    void commentMaskPreservesStringsWhitespaceAndByteOffsets() {
        const QByteArray input = "// hi\r\n{\"v\":\"/*文字*/ //\",/*\r\n字*/\"n\":1}\n";
        const auto output = JsonComments::strip(input);
        QCOMPARE(output.size(), input.size());
        for (qsizetype i = 0; i < input.size(); ++i) {
            if (input[i] == '\r' || input[i] == '\n') QCOMPARE(output[i], input[i]);
        }
        QVERIFY(output.startsWith("     \r\n"));
        QVERIFY(output.contains("\"/*文字*/ //\""));
        QJsonParseError error;
        const auto document = QJsonDocument::fromJson(output, &error);
        QCOMPARE(error.error, QJsonParseError::NoError);
        QCOMPARE(document.object().value("v").toString(), QStringLiteral("/*文字*/ //"));

        // Removing the comment entirely would silently change 1/*...*/2 to 12.
        const auto invalid = JsonComments::strip("{\"n\":1/* comment */2}");
        QJsonDocument::fromJson(invalid, &error);
        QVERIFY(error.error != QJsonParseError::NoError);
    }

    void malformedJsonReportsTheSameOriginalByteOffset() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        const QByteArray input = "/* 注释\r\n保留位置 */\r\n{\"wallpaperCustomCommand\": #}\r\n";
        QVERIFY(writeConfig(directory.path(), input));
        UserConfigBackend runtime;
        Backend settings;
        QVERIFY(!runtime.configError().isEmpty());
        QVERIFY(!settings.errorString().isEmpty());
        QCOMPARE(runtime.configError(), settings.errorString());
        QVERIFY2(runtime.configError().contains(QStringLiteral("offset %1:").arg(input.indexOf('#'))),
                 qPrintable(runtime.configError()));
        QCOMPARE(runtime.wallpaperCustomCommand(), QString());
    }

    void doNotDisturbPersistsAcrossRestartsAndSettingsSaves() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), "{\"hoverExpandAction\": 2}"));

        {
            UserConfigBackend runtime;
            QCOMPARE(runtime.doNotDisturb(), false);
            QSignalSpy spy(&runtime, &UserConfigBackend::doNotDisturbChanged);
            runtime.setDoNotDisturb(true);
            QCOMPARE(runtime.doNotDisturb(), true);
            QCOMPARE(spy.count(), 1);
        }

        QFile file(directory.path() + "/tide-island/userconfig.json");
        QVERIFY(file.open(QIODevice::ReadOnly));
        const QJsonObject saved = QJsonDocument::fromJson(file.readAll()).object();
        file.close();
        QCOMPARE(saved.value("doNotDisturb").toBool(), true);
        QCOMPARE(saved.value("hoverExpandAction").toInt(), 2);

        // A settings-app save keeps the key, and a fresh runtime reads it back.
        Backend settings;
        QVERIFY(settings.save(settings.userConfig()));
        UserConfigBackend restarted;
        QCOMPARE(restarted.doNotDisturb(), true);
    }

    void commentedConfigSurvivesADoNotDisturbToggle() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(),
            "// personal settings\n{\n    \"hoverExpandAction\": 2, /* keep */\n    \"lockscreenBlur\": false\n}\n"));

        UserConfigBackend runtime;
        QCOMPARE(runtime.configError(), QString());
        runtime.setDoNotDisturb(true);

        QFile file(directory.path() + "/tide-island/userconfig.json");
        QVERIFY(file.open(QIODevice::ReadOnly));
        QJsonParseError error;
        const QJsonObject saved = QJsonDocument::fromJson(file.readAll(), &error).object();
        QCOMPARE(error.error, QJsonParseError::NoError);
        QCOMPARE(saved.value("hoverExpandAction").toInt(), 2);
        QCOMPARE(saved.value("lockscreenBlur").toBool(true), false);
        QCOMPARE(saved.value("doNotDisturb").toBool(), true);
    }

    void invalidConfigIsNeverOverwritten() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        const QByteArray broken = "{ \"hoverExpandAction\": 2, ";
        QVERIFY(writeConfig(directory.path(), broken));

        UserConfigBackend runtime;
        QVERIFY(!runtime.configError().isEmpty());
        runtime.setDoNotDisturb(true);
        QCOMPARE(runtime.doNotDisturb(), true);

        QFile file(directory.path() + "/tide-island/userconfig.json");
        QVERIFY(file.open(QIODevice::ReadOnly));
        QCOMPARE(file.readAll(), broken);
    }

    void invalidReloadKeepsTheLastGoodValues() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), "{\"doNotDisturb\": true, \"hoverExpandAction\": 2}"));

        UserConfigBackend runtime;
        QCOMPARE(runtime.doNotDisturb(), true);
        QCOMPARE(runtime.hoverExpandAction(), 2);

        QVERIFY(writeConfig(directory.path(), "{ broken"));
        runtime.reload();
        QVERIFY(!runtime.configError().isEmpty());
        QCOMPARE(runtime.doNotDisturb(), true);
        QCOMPARE(runtime.hoverExpandAction(), 2);
    }

    void islandActivityKeysHaveDefaultsAndAreNormalized() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), "{}"));

        UserConfigBackend runtime;
        QCOMPARE(runtime.islandBatteryMode(), QStringLiteral("low"));
        QCOMPARE(runtime.islandAutoHideKeepActivities(), true);
        QCOMPARE(runtime.idleInhibitCommand(), QString());

        QVERIFY(writeConfig(directory.path(),
            "{\"islandBatteryMode\": \"Always\", \"islandAutoHideKeepActivities\": false,"
            " \"idleInhibitCommand\": \"~/bin/caffeine.sh\"}"));
        runtime.reload();
        QCOMPARE(runtime.islandBatteryMode(), QStringLiteral("always"));
        QCOMPARE(runtime.islandAutoHideKeepActivities(), false);
        QCOMPARE(runtime.idleInhibitCommand(), QDir::homePath() + QStringLiteral("/bin/caffeine.sh"));

        QVERIFY(writeConfig(directory.path(), "{\"islandBatteryMode\": \"sometimes\"}"));
        runtime.reload();
        QCOMPARE(runtime.islandBatteryMode(), QStringLiteral("low"));
    }

    void expandedPlayerIsNeitherAClickNorAHoverAction() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), "{}"));

        UserConfigBackend runtime;
        QCOMPARE(runtime.dynamicIslandPrimaryAction(), QStringLiteral("none"));
        QCOMPARE(runtime.hoverExpandAction(), 0);

        QVERIFY(writeConfig(directory.path(),
            "{\"dynamicIslandPrimaryAction\": \"toggleExpandedPlayer\", \"hoverExpandAction\": 1}"));
        runtime.reload();
        QCOMPARE(runtime.dynamicIslandPrimaryAction(), QStringLiteral("none"));
        QCOMPARE(runtime.hoverExpandAction(), 0);

        QVERIFY(writeConfig(directory.path(),
            "{\"dynamicIslandPrimaryAction\": \"toggleClipboard\", \"hoverExpandAction\": 2}"));
        runtime.reload();
        QCOMPARE(runtime.dynamicIslandPrimaryAction(), QStringLiteral("toggleClipboard"));
        QCOMPARE(runtime.hoverExpandAction(), 2);
    }
};

QTEST_GUILESS_MAIN(UserConfigBackendTests)
#include "user_config_backend_tests.moc"
