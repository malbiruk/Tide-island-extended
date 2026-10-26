#include <QTest>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QScopeGuard>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <memory>
#include "ScreenRecorderController.h"

class ScreenRecorderTests : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void testInitialState();
    void testTimeFormatting();
    void testPropertySetters();
    void testBackendCapabilities();
    void testWfRecorderArgumentsAndStartFailure();

private:
    std::unique_ptr<QTemporaryDir> m_tempDir;
};

void ScreenRecorderTests::initTestCase() {
    m_tempDir = std::make_unique<QTemporaryDir>();
    QVERIFY(m_tempDir->isValid());
    qputenv("XDG_RUNTIME_DIR", m_tempDir->path().toUtf8());
}

void ScreenRecorderTests::testInitialState() {
    ScreenRecorderController controller;
    QCOMPARE(ScreenRecorderController::instance(), &controller);
    QCOMPARE(controller.isRecording(), false);
    QCOMPARE(controller.isPaused(), false);
    QCOMPARE(controller.isReplayActive(), false);
    QCOMPARE(controller.recordingSeconds(), 0);
    QCOMPARE(controller.recordingTimeFormatted(), QStringLiteral("00:00"));
    QCOMPARE(controller.fps(), 60);
    QCOMPARE(controller.replaySeconds(), 60);
}

void ScreenRecorderTests::testTimeFormatting() {
    ScreenRecorderController controller;
    QCOMPARE(controller.recordingTimeFormatted(), QStringLiteral("00:00"));
}

void ScreenRecorderTests::testPropertySetters() {
    ScreenRecorderController controller;

    QSignalSpy micSpy(&controller, &ScreenRecorderController::micEnabledChanged);
    controller.setMicEnabled(true);
    QCOMPARE(controller.micEnabled(), true);
    QCOMPARE(micSpy.count(), 1);

    QSignalSpy fpsSpy(&controller, &ScreenRecorderController::fpsChanged);
    controller.setFps(120);
    QCOMPARE(controller.fps(), 120);
    QCOMPARE(fpsSpy.count(), 1);

    QSignalSpy replaySpy(&controller, &ScreenRecorderController::replaySecondsChanged);
    controller.setReplaySeconds(30);
    QCOMPARE(controller.replaySeconds(), 30);
    QCOMPARE(replaySpy.count(), 1);

    QSignalSpy screenSpy(&controller, &ScreenRecorderController::screenNameChanged);
    controller.setScreenName(QStringLiteral("DP-1"));
    QCOMPARE(controller.screenName(), QStringLiteral("DP-1"));
    QCOMPARE(screenSpy.count(), 1);
}

static bool writeFakeExecutable(const QString &path, const QByteArray &script = "#!/bin/sh\nexit 0\n") {
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    file.write(script);
    file.close();
    return file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
}

void ScreenRecorderTests::testBackendCapabilities() {
    const QByteArray originalPath = qgetenv("PATH");
    const auto restorePath = qScopeGuard([&originalPath] { qputenv("PATH", originalPath); });
    const QString binDir = m_tempDir->path() + QStringLiteral("/bin");
    QVERIFY(QDir().mkpath(binDir));
    qputenv("PATH", binDir.toUtf8());

    {
        ScreenRecorderController controller;
        QCOMPARE(controller.isAvailable(), false);
    }

    // wf-recorder only: recording works, pause and the replay buffer do not.
    QVERIFY(writeFakeExecutable(binDir + QStringLiteral("/wf-recorder")));
    {
        ScreenRecorderController controller;
        QCOMPARE(controller.isAvailable(), true);
        QCOMPARE(controller.canPause(), false);
        QCOMPARE(controller.canReplay(), false);

        QSignalSpy notificationSpy(&controller, &ScreenRecorderController::notificationRequested);
        controller.startReplay();
        QCOMPARE(controller.isReplayActive(), false);
        controller.pauseRecording();
        QCOMPARE(controller.isPaused(), false);
        QCOMPARE(notificationSpy.count(), 2);
    }

    // gpu-screen-recorder present: it is preferred and supports pause and replay.
    QVERIFY(writeFakeExecutable(binDir + QStringLiteral("/gpu-screen-recorder")));
    {
        ScreenRecorderController controller;
        QCOMPARE(controller.isAvailable(), true);
        QCOMPARE(controller.canPause(), true);
        QCOMPARE(controller.canReplay(), true);
    }
}

void ScreenRecorderTests::testWfRecorderArgumentsAndStartFailure() {
    const QByteArray originalPath = qgetenv("PATH");
    const auto restorePath = qScopeGuard([&originalPath] { qputenv("PATH", originalPath); });
    const QString binDir = m_tempDir->path() + QStringLiteral("/wf-bin");
    const QString argsFile = m_tempDir->path() + QStringLiteral("/wf-args.txt");
    const QString recordingsDir = m_tempDir->path() + QStringLiteral("/recordings");
    QVERIFY(QDir().mkpath(binDir));

    // The fake recorder records its arguments and exits at once, like a failed start.
    QVERIFY(writeFakeExecutable(binDir + QStringLiteral("/wf-recorder"),
                                "#!/bin/sh\nprintf '%s\\n' \"$@\" > '" + argsFile.toUtf8() + "'\n"));
    QVERIFY(writeFakeExecutable(binDir + QStringLiteral("/pactl"), "#!/bin/sh\necho fake_sink\n"));
    qputenv("PATH", binDir.toUtf8());

    ScreenRecorderController controller;
    controller.setRecordingsDir(recordingsDir);
    QSignalSpy notificationSpy(&controller, &ScreenRecorderController::notificationRequested);

    controller.startRecording(false);
    QVERIFY(controller.isRecording());

    QTRY_VERIFY(QFileInfo(argsFile).size() > 0);
    QFile file(argsFile);
    QVERIFY(file.open(QIODevice::ReadOnly));
    const QStringList args = QString::fromUtf8(file.readAll()).split(QLatin1Char('\n'), Qt::SkipEmptyParts);

    const auto valueAfter = [&args](const QString &flag) {
        const qsizetype index = args.indexOf(flag);
        return index >= 0 && index + 1 < args.size() ? args.at(index + 1) : QString();
    };
    QVERIFY(valueAfter(QStringLiteral("-f")).startsWith(recordingsDir + QStringLiteral("/recording_")));
    QVERIFY(valueAfter(QStringLiteral("-f")).endsWith(QStringLiteral(".mp4")));
    QCOMPARE(valueAfter(QStringLiteral("-r")), QStringLiteral("60"));
    QCOMPARE(valueAfter(QStringLiteral("-c")), QStringLiteral("libx264"));
    QCOMPARE(valueAfter(QStringLiteral("-p")), QStringLiteral("preset=veryfast"));
    QCOMPARE(valueAfter(QStringLiteral("-x")), QStringLiteral("yuv420p"));
    QVERIFY(args.contains(QStringLiteral("--audio-backend=pulse")));
    QVERIFY(args.contains(QStringLiteral("--audio=fake_sink.monitor")));
    QVERIFY(!args.contains(QStringLiteral("-y")));
    // No screens without a GUI application, so the output is left to wf-recorder.
    QVERIFY(!args.contains(QStringLiteral("-o")));

    // The recorder is already gone: the start check resets the state and reports it.
    QTRY_COMPARE(controller.isRecording(), false);
    QVERIFY(!notificationSpy.isEmpty());
    QCOMPARE(notificationSpy.last().at(0).toString(), QStringLiteral("Recording Failed"));
}

QTEST_GUILESS_MAIN(ScreenRecorderTests)
#include "screen_recorder_tests.moc"
