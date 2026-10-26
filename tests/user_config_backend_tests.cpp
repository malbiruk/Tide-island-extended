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
            << QByteArray(R"json({"weatherLocation":"printf '/*literal*/'"})json")
            << QStringLiteral("printf '/*literal*/'");
        QTest::newRow("even-backslashes-before-quote")
            << QByteArray("{\"weatherLocation\":\"C:\\\\\", // real comment\r\n\"wallpaperPath\":\"https://example.com/a/*b*/\"}")
            << QStringLiteral("C:\\");
        for (const auto &command : {QStringLiteral("printf \"quoted // /* text */\""),
                                   QStringLiteral("\\\\\"// still a string /* */\\\\"),
                                   QStringLiteral("第一行\n第二行\t/*文字*/ https://example.com/😀")}) {
            auto input = QJsonDocument(QJsonObject {{"weatherLocation", command}}).toJson();
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
        QCOMPARE(runtime.weatherLocation(), command);
        QCOMPARE(settings.userConfig().value("weatherLocation").toString(), command);

        // A settings save and live runtime reload must retain the same bytes.
        QVERIFY(settings.save(settings.userConfig()));
        runtime.reload();
        QCOMPARE(runtime.configError(), QString());
        QCOMPARE(runtime.weatherLocation(), command);
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
        const QByteArray input = "/* 注释\r\n保留位置 */\r\n{\"weatherLocation\": #}\r\n";
        QVERIFY(writeConfig(directory.path(), input));
        UserConfigBackend runtime;
        Backend settings;
        QVERIFY(!runtime.configError().isEmpty());
        QVERIFY(!settings.errorString().isEmpty());
        QCOMPARE(runtime.configError(), settings.errorString());
        QVERIFY2(runtime.configError().contains(QStringLiteral("offset %1:").arg(input.indexOf('#'))),
                 qPrintable(runtime.configError()));
        QCOMPARE(runtime.weatherLocation(), QString());
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
            "// personal settings\n{\n    \"hoverExpandAction\": 2, /* keep */\n    \"islandBlurEnabled\": false\n}\n"));

        UserConfigBackend runtime;
        QCOMPARE(runtime.configError(), QString());
        runtime.setDoNotDisturb(true);

        QFile file(directory.path() + "/tide-island/userconfig.json");
        QVERIFY(file.open(QIODevice::ReadOnly));
        QJsonParseError error;
        const QJsonObject saved = QJsonDocument::fromJson(file.readAll(), &error).object();
        QCOMPARE(error.error, QJsonParseError::NoError);
        QCOMPARE(saved.value("hoverExpandAction").toInt(), 2);
        QCOMPARE(saved.value("islandBlurEnabled").toBool(true), false);
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
        QCOMPARE(runtime.idleInhibitCommand(), QStringList());
        QCOMPARE(runtime.lockCommand(), QStringList());

        QVERIFY(writeConfig(directory.path(),
            "{\"islandBatteryMode\": \"Always\", \"islandAutoHideKeepActivities\": false,"
            " \"idleInhibitCommand\": \"~/bin/caffeine.sh\","
            " \"lockCommand\": \" gtklock -d -b \\\"/home/x/My Pictures/bg.png\\\" \"}"));
        runtime.reload();
        QCOMPARE(runtime.islandBatteryMode(), QStringLiteral("always"));
        QCOMPARE(runtime.islandAutoHideKeepActivities(), false);
        QCOMPARE(runtime.idleInhibitCommand(), QStringList{QDir::homePath() + QStringLiteral("/bin/caffeine.sh")});
        QCOMPARE(runtime.lockCommand(), (QStringList{QStringLiteral("gtklock"), QStringLiteral("-d"), QStringLiteral("-b"),
                                                     QStringLiteral("/home/x/My Pictures/bg.png")}));

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

    void emptyOrLegacyActionsOnAnyButtonMeanNone() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), "{}"));

        UserConfigBackend runtime;
        QCOMPARE(runtime.dynamicIslandSecondaryAction(), QStringLiteral("toggleControlCenter"));
        QCOMPARE(runtime.dynamicIslandMiddleAction(), QStringLiteral("toggleClipboard"));

        QVERIFY(writeConfig(directory.path(),
            "{\"dynamicIslandPrimaryAction\": \"\", \"dynamicIslandSecondaryAction\": \"toggleExpandedPlayer\","
            " \"dynamicIslandMiddleAction\": \" \"}"));
        runtime.reload();
        QCOMPARE(runtime.dynamicIslandPrimaryAction(), QStringLiteral("none"));
        QCOMPARE(runtime.dynamicIslandSecondaryAction(), QStringLiteral("none"));
        QCOMPARE(runtime.dynamicIslandMiddleAction(), QStringLiteral("none"));
    }

    void islandGeometryIsClampedLikeTheSettingsApp() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(),
            "{\"islandWidth\": 0, \"islandHeight\": 5000, \"islandPositionX\": 140}"));

        UserConfigBackend runtime;
        QCOMPARE(runtime.islandWidth(), 1);
        QCOMPARE(runtime.islandHeight(), 1000);
        QCOMPARE(runtime.islandPositionX(), 100);

        QVERIFY(writeConfig(directory.path(), "{\"islandPositionX\": -3}"));
        runtime.reload();
        QCOMPARE(runtime.islandPositionX(), 0);
        QCOMPARE(runtime.islandWidth(), 140);
    }

    void notificationTimeoutsDefaultToEightAndFiveSeconds() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), "{}"));

        UserConfigBackend runtime;
        QCOMPARE(runtime.notificationTimeout(), 8);
        QCOMPARE(runtime.notificationTimeoutLow(), 5);

        QVERIFY(writeConfig(directory.path(), "{\"notificationTimeout\": 12, \"notificationTimeoutLow\": 0}"));
        runtime.reload();
        QCOMPARE(runtime.notificationTimeout(), 12);
        QCOMPARE(runtime.notificationTimeoutLow(), 1);
    }

    void islandBatteryThresholdDefaultsToFortyAndIsClamped() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), "{}"));

        UserConfigBackend runtime;
        QCOMPARE(runtime.islandBatteryThreshold(), 40);

        QVERIFY(writeConfig(directory.path(), "{\"islandBatteryThreshold\": 25}"));
        runtime.reload();
        QCOMPARE(runtime.islandBatteryThreshold(), 25);

        QVERIFY(writeConfig(directory.path(), "{\"islandBatteryThreshold\": 0}"));
        runtime.reload();
        QCOMPARE(runtime.islandBatteryThreshold(), 5);

        QVERIFY(writeConfig(directory.path(), "{\"islandBatteryThreshold\": 150}"));
        runtime.reload();
        QCOMPARE(runtime.islandBatteryThreshold(), 100);

        QVERIFY(writeConfig(directory.path(), "{\"islandBatteryThreshold\": \"30\"}"));
        runtime.reload();
        QCOMPARE(runtime.islandBatteryThreshold(), 40);
    }

    void islandEdgeIsTopUnlessBottom() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), "{}"));

        UserConfigBackend runtime;
        QCOMPARE(runtime.islandEdge(), QStringLiteral("top"));

        QVERIFY(writeConfig(directory.path(), "{\"islandEdge\": \"Bottom\"}"));
        runtime.reload();
        QCOMPARE(runtime.islandEdge(), QStringLiteral("bottom"));

        QVERIFY(writeConfig(directory.path(), "{\"islandEdge\": \"left\"}"));
        runtime.reload();
        QCOMPARE(runtime.islandEdge(), QStringLiteral("top"));
    }

    void commandsSplitLikeAShell_data() {
        QTest::addColumn<QByteArray>("json");
        QTest::addColumn<QStringList>("expected");
        const QString home = QDir::homePath();
        QTest::newRow("single quotes") << QByteArray("\"gtklock -d -b '/x/My Pictures/bg.png'\"")
            << QStringList{"gtklock", "-d", "-b", "/x/My Pictures/bg.png"};
        QTest::newRow("double quotes and escapes") << QByteArray("\"sh -c \\\"echo \\\\\\\"hi\\\\\\\" \\\\$HOME\\\"\"")
            << QStringList{"sh", "-c", "echo \"hi\" $HOME"};
        QTest::newRow("backslash space") << QByteArray("\"my\\\\ locker now\"")
            << QStringList{"my locker", "now"};
        QTest::newRow("tilde in any unquoted word") << QByteArray("\"~/bin/lock --image ~/Pictures/x.png '~/kept' ~user\"")
            << QStringList{home + "/bin/lock", "--image", home + "/Pictures/x.png", "~/kept", "~user"};
        QTest::newRow("empty argument") << QByteArray("\"cmd '' x\"") << QStringList{"cmd", "", "x"};
        QTest::newRow("unterminated quote") << QByteArray("\"gtklock 'oops\"") << QStringList{};
    }

    void commandsSplitLikeAShell() {
        QFETCH(QByteArray, json);
        QFETCH(QStringList, expected);
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), "{\"lockCommand\": " + json + "}"));

        UserConfigBackend runtime;
        QCOMPARE(runtime.lockCommand(), expected);
    }

    void loadingTightensAReadableFileWithAPassword() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), "{\"tlpSudoPassword\": \"secret\"}"));
        const QString path = directory.path() + QStringLiteral("/tide-island/userconfig.json");
        QVERIFY(QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner
                                                | QFileDevice::ReadGroup | QFileDevice::ReadOther));

        UserConfigBackend runtime;
        QCOMPARE(runtime.tlpSudoPassword(), QStringLiteral("secret"));
        const QFileDevice::Permissions permissions = QFile::permissions(path);
        QVERIFY(permissions & QFileDevice::ReadOwner);
        QVERIFY(!(permissions & (QFileDevice::ReadGroup | QFileDevice::ReadOther)));
    }

    void savingKeepsAFileWithAPasswordOwnerOnly() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(writeConfig(directory.path(), "{\"tlpSudoPassword\": \"secret\"}"));
        const QString path = directory.path() + QStringLiteral("/tide-island/userconfig.json");
        QVERIFY(QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner
                                                | QFileDevice::ReadGroup | QFileDevice::ReadOther));

        UserConfigBackend runtime;
        runtime.setDoNotDisturb(!runtime.doNotDisturb());

        const QFileDevice::Permissions permissions = QFile::permissions(path);
        QVERIFY(permissions & QFileDevice::ReadOwner);
        QVERIFY(!(permissions & (QFileDevice::ReadGroup | QFileDevice::ReadOther
                                 | QFileDevice::WriteGroup | QFileDevice::WriteOther)));
    }
};

QTEST_GUILESS_MAIN(UserConfigBackendTests)
#include "user_config_backend_tests.moc"
