#include "NotificationActivation.h"
#include "SystemServices.h"
#include "../common/ScopedLaunch.h"

#include <QtTest>
#include <QProcess>
#include <QSignalSpy>
#include <QDir>
#include <QFileInfo>
#include <QScopeGuard>
#include <QTemporaryDir>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

#include <csignal>
#include <memory>
#include <sys/stat.h>

class SystemServicesNotificationTests : public QObject
{
    Q_OBJECT

    QTemporaryDir m_emptyDirectory;

private slots:
    // No monitor or pactl processes: nothing the tests run is found on PATH.
    void initTestCase()
    {
        QVERIFY(m_emptyDirectory.isValid());
        qputenv("PATH", m_emptyDirectory.path().toUtf8());
        qputenv("XDG_RUNTIME_DIR", m_emptyDirectory.path().toUtf8());
    }

    void testPrivacyIndicators()
    {
        SystemServices services;
        QSignalSpy privacySpy(&services, &SystemServices::privacyIndicatorsChanged);
        QVERIFY(privacySpy.isValid());

        // Check property getters
        QCOMPARE(services.privacyActive(), services.micActive() || services.cameraActive());

        // Simulate privacy snapshot output parsing
        const QString sampleOutput = QStringLiteral(
            "[{\"index\":10,\"source\":1,\"corked\":false,\"properties\":{\"application.name\":\"TestMicApp\",\"application.process.id\":\"1234\",\"application.process.binary\":\"testapp\"}}]"
            "\n---TIDE-PRIVACY-SEP---\n"
            "id 88, type PipeWire:Interface:Node/3\n"
            "media.class = \"Stream/Input/Video\"\n"
            "application.name = \"TestCamApp\"\n"
            "application.process.id = \"5678\"\n"
        );

        QMetaObject::invokeMethod(&services, "handlePrivacySnapshotOutput",
                                  Qt::DirectConnection,
                                  Q_ARG(QString, sampleOutput));

        QVERIFY(services.micActive());
        QVERIFY(services.cameraActive());
        QVERIFY(services.privacyActive());
        QCOMPARE(services.activePrivacyApps().size(), 2);

        const QVariantMap app1 = services.activePrivacyApps().at(0).toMap();
        QCOMPARE(app1.value(QStringLiteral("name")).toString(), QStringLiteral("TestMicApp"));
        QCOMPARE(app1.value(QStringLiteral("type")).toString(), QStringLiteral("mic"));
        QCOMPARE(app1.value(QStringLiteral("pid")).toInt(), 1234);

        const QVariantMap app2 = services.activePrivacyApps().at(1).toMap();
        QCOMPARE(app2.value(QStringLiteral("name")).toString(), QStringLiteral("TestCamApp"));
        QCOMPARE(app2.value(QStringLiteral("type")).toString(), QStringLiteral("camera"));
        QCOMPARE(app2.value(QStringLiteral("pid")).toInt(), 5678);

        QVERIFY(privacySpy.count() >= 1);

        // Test 3-part format with fuser PID detection
        const QString sampleOutput3Part = QStringLiteral(
            "[]\n---TIDE-PRIVACY-SEP---\n99999\n---TIDE-PRIVACY-SEP---\n"
        );
        QMetaObject::invokeMethod(&services, "handlePrivacySnapshotOutput",
                                  Qt::DirectConnection,
                                  Q_ARG(QString, sampleOutput3Part));
        QVERIFY(services.cameraActive());
        QVERIFY(!services.micActive());
        QVERIFY(services.privacyActive());

        // Test that screen share stream (e.g. Discord with media.role="Screen") does NOT trigger cameraActive
        const QString sampleScreenShare = QStringLiteral(
            "[]\n---TIDE-PRIVACY-SEP---\n\n---TIDE-PRIVACY-SEP---\n"
            "id 82, type PipeWire:Interface:Node/3\n"
            "media.class = \"Stream/Input/Video\"\n"
            "media.role = \"Screen\"\n"
            "application.name = \"Discord\"\n"
            "application.process.id = \"1708\"\n"
        );
        QMetaObject::invokeMethod(&services, "handlePrivacySnapshotOutput",
                                  Qt::DirectConnection,
                                  Q_ARG(QString, sampleScreenShare));
        QVERIFY(!services.cameraActive());
        QVERIFY(services.screenRecordingActive());
        QCOMPARE(services.activePrivacyApps().size(), 1);
        const QVariantMap scApp = services.activePrivacyApps().at(0).toMap();
        QCOMPARE(scApp.value(QStringLiteral("name")).toString(), QStringLiteral("Discord"));
        QCOMPARE(scApp.value(QStringLiteral("type")).toString(), QStringLiteral("screen"));
        QCOMPARE(scApp.value(QStringLiteral("pid")).toInt(), 1708);
    }

    void activationTokenSignalFollowsTheNotificationSpec()
    {
        const QDBusMessage message = NotificationActivation::activationTokenSignal(42, QStringLiteral("token-1"));
        QCOMPARE(message.type(), QDBusMessage::SignalMessage);
        QCOMPARE(message.path(), QStringLiteral("/org/freedesktop/Notifications"));
        QCOMPARE(message.interface(), QStringLiteral("org.freedesktop.Notifications"));
        QCOMPARE(message.member(), QStringLiteral("ActivationToken"));
        QCOMPARE(message.arguments().size(), 2);
        QCOMPARE(message.arguments().at(0).metaType(), QMetaType::fromType<uint>());
        QCOMPARE(message.arguments().at(0).toUInt(), 42u);
        QCOMPARE(message.arguments().at(1).toString(), QStringLiteral("token-1"));
    }

    void activationTokenRequestWithoutWaylandAnswersEmptyAndAsynchronously()
    {
        NotificationActivation activation;
        QSignalSpy readySpy(&activation, &NotificationActivation::tokenReady);
        activation.requestToken(nullptr, 7);
        QCOMPARE(readySpy.count(), 0);
        QVERIFY(readySpy.wait(1000));
        QCOMPARE(readySpy.at(0).at(0).toUInt(), 7u);
        QVERIFY(readySpy.at(0).at(1).toString().isEmpty());
    }

    void childrenGetTheUsersEnvironmentBack()
    {
        QProcessEnvironment launched;
        launched.insert(QStringLiteral("HOME"), QStringLiteral("/home/someone"));
        launched.insert(QStringLiteral("INVOCATION_ID"), QStringLiteral("abc"));
        launched.insert(QStringLiteral("JOURNAL_STREAM"), QStringLiteral("8:1"));
        launched.insert(QStringLiteral("TIDE_ISLAND_LAUNCHER"), QStringLiteral("1"));
        launched.insert(QStringLiteral("MALLOC_CONF"), QStringLiteral("narenas:1"));
        launched.insert(QStringLiteral("QML_IMPORT_PATH"), QStringLiteral("/usr/lib/qt6/qml:/mine"));
        launched.insert(QStringLiteral("TIDE_ISLAND_ORIGINAL_QML_IMPORT_PATH"), QStringLiteral("/mine"));
        launched.insert(QStringLiteral("QUICKSHELL_LYRICS_BACKEND"), QStringLiteral("/usr/share/x"));
        launched.insert(QStringLiteral("QS_ICON_THEME"), QStringLiteral("Papirus"));

        const QProcessEnvironment child = ScopedLaunch::childEnvironment(launched);
        QCOMPARE(child.value(QStringLiteral("HOME")), QStringLiteral("/home/someone"));
        QCOMPARE(child.value(QStringLiteral("QS_ICON_THEME")), QStringLiteral("Papirus"));
        QCOMPARE(child.value(QStringLiteral("QML_IMPORT_PATH")), QStringLiteral("/mine"));
        for (const char *gone : {"INVOCATION_ID", "JOURNAL_STREAM", "MALLOC_CONF", "QUICKSHELL_LYRICS_BACKEND",
                                 "TIDE_ISLAND_LAUNCHER", "TIDE_ISLAND_ORIGINAL_QML_IMPORT_PATH"})
            QVERIFY2(!child.contains(QString::fromLatin1(gone)), gone);

        // Not started by the launcher: a user's own MALLOC_CONF is not touched.
        QProcessEnvironment direct;
        direct.insert(QStringLiteral("MALLOC_CONF"), QStringLiteral("mine"));
        QCOMPARE(ScopedLaunch::childEnvironment(direct).value(QStringLiteral("MALLOC_CONF")), QStringLiteral("mine"));
    }

    // A fake systemd-run that logs its arguments and runs what follows "--".
    void scopesUseAFixedDescriptionAndNoVariableExpansion_data()
    {
        QTest::addColumn<QString>("version");
        QTest::addColumn<bool>("scopeWorks");
        QTest::addColumn<bool>("expectExpandFlag");
        QTest::newRow("systemd 262") << QStringLiteral("systemd 262 (262.1-1-arch)") << true << true;
        QTest::newRow("systemd 249") << QStringLiteral("systemd 249 (249.11)") << true << false;
        QTest::newRow("no user manager behind the socket") << QStringLiteral("systemd 262") << false << false;
    }

    void scopesUseAFixedDescriptionAndNoVariableExpansion()
    {
        QFETCH(QString, version);
        QFETCH(bool, scopeWorks);
        QFETCH(bool, expectExpandFlag);

        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const QString log = directory.path() + QStringLiteral("/systemd-run.log");
        QVERIFY(QDir().mkpath(directory.path() + QStringLiteral("/runtime/systemd")));
        QFile socket(directory.path() + QStringLiteral("/runtime/systemd/private"));
        QVERIFY(socket.open(QIODevice::WriteOnly));
        socket.close();
        QFile fake(directory.path() + QStringLiteral("/systemd-run"));
        QVERIFY(fake.open(QIODevice::WriteOnly));
        fake.write("#!/bin/sh\nprintf '%s\\n' \"$*\" >> '" + log.toUtf8() + "'\n"
                   "if [ \"$1\" = --version ]; then echo '" + version.toUtf8() + "'; exit 0; fi\n"
                   + QByteArray(scopeWorks ? "" : "exit 1\n") +
                   "while [ $# -gt 0 ]; do if [ \"$1\" = -- ]; then shift; break; fi; shift; done\n"
                   "exec \"$@\"\n");
        fake.close();
        QVERIFY(fake.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));

        const QByteArray originalPath = qgetenv("PATH");
        const QByteArray originalRuntime = qgetenv("XDG_RUNTIME_DIR");
        qputenv("PATH", directory.path().toUtf8());
        qputenv("XDG_RUNTIME_DIR", (directory.path() + QStringLiteral("/runtime")).toUtf8());
        const auto restore = qScopeGuard([&]() {
            qputenv("PATH", originalPath);
            qputenv("XDG_RUNTIME_DIR", originalRuntime);
            ScopedLaunch::resetProbe();
        });

        ScopedLaunch::resetProbe();
        ScopedLaunch::probe();
        QTRY_VERIFY(ScopedLaunch::scopeSupport().state != ScopedLaunch::ScopeSupport::Probing);
        QCOMPARE(ScopedLaunch::scopesAvailable(), scopeWorks);

        const QString out = directory.path() + QStringLiteral("/out");
        QVERIFY(ScopedLaunch::startDetached({QStringLiteral("/bin/sh"), QStringLiteral("-c"),
                                            QStringLiteral("printf '%s' \"$1\" > '") + out + QStringLiteral("'"),
                                            QStringLiteral("sh"), QStringLiteral("$HOME https://x.org/?a=1&b=$c")}));
        QTRY_VERIFY(QFileInfo(out).size() > 0);
        QFile result(out);
        QVERIFY(result.open(QIODevice::ReadOnly));
        QCOMPARE(QString::fromUtf8(result.readAll()), QStringLiteral("$HOME https://x.org/?a=1&b=$c"));

        QFile logFile(log);
        QVERIFY(logFile.open(QIODevice::ReadOnly));
        const QStringList calls = QString::fromUtf8(logFile.readAll()).split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        const QString launch = calls.last();
        if (!scopeWorks) {
            QVERIFY2(!launch.contains(QStringLiteral("/bin/sh -c")), qPrintable(launch));
            return;
        }
        QVERIFY2(launch.startsWith(QStringLiteral("--user --scope --quiet --collect --description=Tide Island launch ")),
                 qPrintable(launch));
        QCOMPARE(launch.contains(QStringLiteral("--expand-environment=no")), expectExpandFlag);
        QVERIFY2(launch.contains(QStringLiteral(" -- /bin/sh -c ")), qPrintable(launch));
    }

    void runCommandReportsFailuresAndOutlivesItsOwner()
    {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        auto services = std::make_unique<SystemServices>();
        QSignalSpy notices(services.get(), &SystemServices::noticeRequested);
        QSignalSpy finished(services.get(), &SystemServices::commandFinished);

        const int failing = services->runCommand({QStringLiteral("/bin/sh"), QStringLiteral("-c"), QStringLiteral("exit 3")},
                                                 QStringLiteral("Power"), QStringLiteral("Lock failed"));
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(finished.at(0).at(0).toInt(), failing);
        QCOMPARE(finished.at(0).at(1).toInt(), 3);
        QCOMPARE(notices.count(), 1);
        QCOMPARE(notices.at(0).at(1).toString(), QStringLiteral("Lock failed"));
        QCOMPARE(notices.at(0).at(2).toString(), QStringLiteral("sh exited with code 3."));

        services->runCommand({QStringLiteral("no-such-locker-xyz")}, QStringLiteral("Power"), QStringLiteral("Lock failed"),
                             QStringLiteral("Install a locker."));
        QTRY_COMPARE(notices.count(), 2);
        QCOMPARE(notices.at(1).at(2).toString(), QStringLiteral("Install a locker."));

        services->runCommand({QStringLiteral("/bin/true")}, QStringLiteral("Power"), QStringLiteral("Lock failed"));
        QTRY_COMPARE(finished.count(), 3);
        QCOMPARE(notices.count(), 2);

        // A locker still running when its owner goes away keeps running.
        const QString marker = directory.path() + QStringLiteral("/still-running");
        services->runCommand({QStringLiteral("/bin/sh"), QStringLiteral("-c"),
                              QStringLiteral("/bin/sleep 0.3; : > '") + marker + QStringLiteral("'")},
                             QStringLiteral("Power"), QStringLiteral("Lock failed"));
        services.reset();
        QTRY_VERIFY(QFileInfo::exists(marker));
    }

    void cavaFeedsFiveBarsAndStopsWithoutBlocking()
    {
        QTemporaryDir binDirectory;
        QVERIFY(binDirectory.isValid());
        const QString pidFile = binDirectory.path() + QStringLiteral("/cava.pid");
        // Ignores SIGTERM, like a cava stuck on its audio backend.
        QFile script(binDirectory.path() + QStringLiteral("/cava"));
        QVERIFY(script.open(QIODevice::WriteOnly));
        script.write("#!/bin/sh\ntrap '' TERM\necho $$ > '" + pidFile.toUtf8() + "'\n"
                     "while true; do echo '7;0;7;0;7;'; /bin/sleep 0.05; done\n");
        script.close();
        QVERIFY(script.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));
        const QByteArray originalPath = qgetenv("PATH");
        qputenv("PATH", binDirectory.path().toUtf8());
        const auto restorePath = qScopeGuard([&originalPath] { qputenv("PATH", originalPath); });

        SystemServices services;
        services.setCavaClientActive(QStringLiteral("test"), true);
        QTRY_COMPARE(services.cavaLevels(), (QVariantList{1.0, 0.0, 1.0, 0.0, 1.0}));
        QTRY_VERIFY(QFileInfo(pidFile).size() > 0);
        QFile pidSource(pidFile);
        QVERIFY(pidSource.open(QIODevice::ReadOnly));
        const pid_t pid = pidSource.readAll().trimmed().toInt();
        QVERIFY(pid > 0);

        // A blocking stop would have waited and killed it; it is still there right after, then goes.
        services.setCavaClientActive(QStringLiteral("test"), false);
        QCOMPARE(::kill(pid, 0), 0);
        QTRY_VERIFY_WITH_TIMEOUT(::kill(pid, 0) != 0, 3000);
    }

    void onlyRegularFilesCountAsNotificationImages()
    {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const QString image = directory.path() + QStringLiteral("/image.png");
        QFile file(image);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("png");
        file.close();
        const QString link = directory.path() + QStringLiteral("/link.png");
        QVERIFY(QFile::link(image, link));
        const QString fifo = directory.path() + QStringLiteral("/fifo");
        QCOMPARE(::mkfifo(QFile::encodeName(fifo).constData(), 0600), 0);

        SystemServices services;
        QVERIFY(services.isRegularFile(image));
        QVERIFY(services.isRegularFile(QUrl::fromLocalFile(image).toString()));
        QVERIFY(services.isRegularFile(link));
        QVERIFY(!services.isRegularFile(fifo));
        QVERIFY(!services.isRegularFile(directory.path()));
        QVERIFY(!services.isRegularFile(QStringLiteral("/dev/zero")));
        QVERIFY(!services.isRegularFile(directory.path() + QStringLiteral("/missing.png")));
        QVERIFY(!services.isRegularFile(QString()));
    }
};

QTEST_MAIN(SystemServicesNotificationTests)
#include "system_services_notification_tests.moc"
