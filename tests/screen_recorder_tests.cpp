#include <QTest>
#include <QDir>
#include <QFile>
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

static bool writeFakeExecutable(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    file.write("#!/bin/sh\nexit 0\n");
    file.close();
    return file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
}

void ScreenRecorderTests::testBackendCapabilities() {
    const QByteArray originalPath = qgetenv("PATH");
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

    qputenv("PATH", originalPath);
}

QTEST_MAIN(ScreenRecorderTests)
#include "screen_recorder_tests.moc"
