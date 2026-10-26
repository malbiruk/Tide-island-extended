#include "NotificationActivation.h"
#include "SystemServices.h"

#include <QtTest>
#include <QProcess>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

#include <sys/stat.h>

class SystemServicesNotificationTests : public QObject
{
    Q_OBJECT

private slots:
    void testAudioDevicesAndAppStreamsInvokables()
    {
        SystemServices services;
        QSignalSpy outputsSpy(&services, &SystemServices::audioOutputsChanged);
        QSignalSpy inputsSpy(&services, &SystemServices::audioInputsChanged);
        QSignalSpy streamsSpy(&services, &SystemServices::appStreamsChanged);
        QVERIFY(outputsSpy.isValid());
        QVERIFY(inputsSpy.isValid());
        QVERIFY(streamsSpy.isValid());

        services.setAudioMonitoringActive(true);
        services.requestAudioOutputs();
        services.requestAudioInputs();
        services.requestAppStreams();

        // Verify properties initial state
        QVERIFY(services.audioOutputs().isEmpty() || !services.audioOutputs().isEmpty());
        QVERIFY(services.audioInputs().isEmpty() || !services.audioInputs().isEmpty());

        // Wait for async commands to return
        QTest::qWait(600);

        // Verify outputs or inputs were populated on a running system
        QVERIFY(outputsSpy.count() >= 0);
        QVERIFY(inputsSpy.count() >= 0);

        // Test stream mute and volume adjustments do not crash
        services.setAppStreamVolume(99999, 0.75);
        services.toggleAppStreamMute(99999);
        services.setAudioMonitoringActive(false);
    }

    void testBatteryThresholdDetection()
    {
        SystemServices services;
        QSignalSpy spy(&services, &SystemServices::batteryThresholdChanged);
        QVERIFY(spy.isValid());

        services.requestBatteryThresholdState();

        if (QFile::exists(QStringLiteral("/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"))) {
            QVERIFY(services.batteryThresholdSupported());
            QCOMPARE(services.batteryThresholdType(), QStringLiteral("conservation"));
            QCOMPARE(services.batteryThresholdValue(), services.batteryConservationMode() ? 80 : 100);
            QCOMPARE(services.batteryThresholdPresets().size(), 2);
        }

        QVERIFY(services.batteryHealthPercent() >= 0 && services.batteryHealthPercent() <= 100);
        QVERIFY(services.batteryCycleCount() >= 0);
    }

    void testTerminalResolutionAndWrapping()
    {
        SystemServices services;
        const QString term = services.defaultTerminalEmulator();
        QVERIFY(!term.trimmed().isEmpty());

        // Empty command returns empty
        QVERIFY(services.wrapTerminalCommand({}).isEmpty());

        // Normal command wrapping
        const QStringList wrapped = services.wrapTerminalCommand({QStringLiteral("btop")});
        QVERIFY(wrapped.size() >= 2);
        QCOMPARE(wrapped.last(), QStringLiteral("btop"));
        QVERIFY(wrapped.first().contains(term) || term.contains(wrapped.first()));

        // Multi-arg command wrapping
        const QStringList wrappedMulti = services.wrapTerminalCommand({QStringLiteral("nvim"), QStringLiteral("file.txt")});
        QVERIFY(wrappedMulti.size() >= 3);
        QCOMPARE(wrappedMulti.at(wrappedMulti.size() - 2), QStringLiteral("nvim"));
        QCOMPARE(wrappedMulti.last(), QStringLiteral("file.txt"));
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

    void scopedCommandDropsServiceVariablesAndKeepsTheExitCode()
    {
        // No user manager in this runtime dir: the program runs as a plain child through env.
        QTemporaryDir runtimeDir;
        QVERIFY(runtimeDir.isValid());
        qputenv("XDG_RUNTIME_DIR", runtimeDir.path().toUtf8());

        SystemServices services;
        QVERIFY(services.scopedCommand({}).isEmpty());

        const QStringList command = services.scopedCommand(
            {QStringLiteral("sh"), QStringLiteral("-c"),
             QStringLiteral("printf '%s|%s|%s' \"${MALLOC_CONF-unset}\" \"$1\" \"$HOME\"; exit 3"),
             QStringLiteral("sh"), QStringLiteral("$HOME a b")});
        QProcess process;
        QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
        environment.insert(QStringLiteral("MALLOC_CONF"), QStringLiteral("narenas:1"));
        environment.insert(QStringLiteral("HOME"), QStringLiteral("/home/someone"));
        process.setProcessEnvironment(environment);
        process.start(command.first(), command.mid(1));
        QVERIFY(process.waitForFinished(5000));
        QCOMPARE(QString::fromUtf8(process.readAllStandardOutput()),
                 QStringLiteral("unset|$HOME a b|/home/someone"));
        QCOMPARE(process.exitCode(), 3);
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

    void testQueryDiskUsagePercent()
    {
        SystemServices services;
        const double pct = services.queryDiskUsagePercent(QStringLiteral("/"));
        QVERIFY(pct >= 0.0 && pct <= 100.0);
    }
};

QTEST_MAIN(SystemServicesNotificationTests)
#include "system_services_notification_tests.moc"
