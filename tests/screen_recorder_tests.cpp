#include <QTest>
#include <QDir>
#include <QFile>
#include <QCoreApplication>
#include <QFileInfo>
#include <QProcess>
#include <QScopeGuard>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <memory>
#include "ScreenRecorderController.h"
#include "../common/ScopedLaunch.h"

class ScreenRecorderTests : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void testInitialState();
    void testTimeFormatting();
    void testPropertySetters();
    void testAvailabilityFollowsWfRecorder();
    void testWfRecorderArgumentsAndStartFailure();
    void constructionCreatesNoDirectories();
    void staleStateFilesAreRemoved();
    void aRunningRecorderIsAdoptedAndSavesItsFile();
    void aRecorderExitingOnItsOwnEndsTheRecording();
    void symlinkedStateFilesAreNotFollowed();
    void stoppingWhileTheScopeIsStartingStopsTheRecorder();
    void aScopeThatNeverStartsTheRecorderIsGivenUp();

private:
    QString stateDir() const { return m_tempDir->path() + QStringLiteral("/tide-island-recorder"); }
    void writeState(qint64 pid, const QString &output) const;

    std::unique_ptr<QTemporaryDir> m_tempDir;
};

// HOME and the runtime dir point into the temporary dir: tests never touch the real ones.
void ScreenRecorderTests::initTestCase() {
    m_tempDir = std::make_unique<QTemporaryDir>();
    QVERIFY(m_tempDir->isValid());
    qputenv("XDG_RUNTIME_DIR", m_tempDir->path().toUtf8());
    qputenv("HOME", (m_tempDir->path() + QStringLiteral("/home")).toUtf8());
}

void ScreenRecorderTests::writeState(qint64 pid, const QString &output) const {
    QVERIFY(QDir().mkpath(stateDir()));
    QFile pidFile(stateDir() + QStringLiteral("/record.pid"));
    QVERIFY(pidFile.open(QIODevice::WriteOnly));
    pidFile.write(QByteArray::number(pid) + '\n');
    QFile outputFile(stateDir() + QStringLiteral("/record.output"));
    QVERIFY(outputFile.open(QIODevice::WriteOnly));
    outputFile.write(output.toUtf8() + '\n');
}

void ScreenRecorderTests::testInitialState() {
    ScreenRecorderController controller;
    QCOMPARE(ScreenRecorderController::instance(), &controller);
    QCOMPARE(controller.isRecording(), false);
    QCOMPARE(controller.recordingSeconds(), 0);
    QCOMPARE(controller.recordingTimeFormatted(), QStringLiteral("00:00"));
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

void ScreenRecorderTests::testAvailabilityFollowsWfRecorder() {
    const QByteArray originalPath = qgetenv("PATH");
    const auto restorePath = qScopeGuard([&originalPath] { qputenv("PATH", originalPath); });
    const QString binDir = m_tempDir->path() + QStringLiteral("/bin");
    QVERIFY(QDir().mkpath(binDir));
    qputenv("PATH", binDir.toUtf8());

    {
        ScreenRecorderController controller;
        QCOMPARE(controller.isAvailable(), false);
    }

    QVERIFY(writeFakeExecutable(binDir + QStringLiteral("/wf-recorder")));
    {
        ScreenRecorderController controller;
        QCOMPARE(controller.isAvailable(), true);
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
    // No forced framerate: wf-recorder keeps each frame's real timestamp.
    QVERIFY(!args.contains(QStringLiteral("-r")));
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

void ScreenRecorderTests::constructionCreatesNoDirectories() {
    QVERIFY(QDir(stateDir()).removeRecursively());
    ScreenRecorderController controller;
    QVERIFY(!QFileInfo::exists(m_tempDir->path() + QStringLiteral("/home/Videos")));
    QVERIFY(!QFileInfo::exists(stateDir()));
}

void ScreenRecorderTests::staleStateFilesAreRemoved() {
    // Our own pid: running, but not a wf-recorder.
    writeState(QCoreApplication::applicationPid(), m_tempDir->path() + QStringLiteral("/stale.mp4"));

    ScreenRecorderController controller;
    QVERIFY(!controller.isRecording());
    QVERIFY(!QFileInfo::exists(stateDir() + QStringLiteral("/record.pid")));
    QVERIFY(!QFileInfo::exists(stateDir() + QStringLiteral("/record.output")));
}

void ScreenRecorderTests::aRunningRecorderIsAdoptedAndSavesItsFile() {
    const QString binDir = m_tempDir->path() + QStringLiteral("/adopt-bin");
    QVERIFY(QDir().mkpath(binDir));
    const QString recorder = binDir + QStringLiteral("/wf-recorder");
    QVERIFY(writeFakeExecutable(recorder,
        "#!/bin/sh\ntrap 'kill $child 2>/dev/null; exit 0' INT TERM\n/bin/sleep 30 & child=$!\nwait $child\n"));
    const QString output = m_tempDir->path() + QStringLiteral("/adopted.mp4");
    QFile outputFile(output);
    QVERIFY(outputFile.open(QIODevice::WriteOnly));
    outputFile.close();

    QProcess process;
    process.start(recorder, {});
    QVERIFY(process.waitForStarted());
    const auto cleanup = qScopeGuard([&process] { process.kill(); process.waitForFinished(); });
    QTRY_COMPARE(QString::fromUtf8([&process] {
        QFile comm(QStringLiteral("/proc/%1/comm").arg(process.processId()));
        return comm.open(QIODevice::ReadOnly) ? comm.readAll().trimmed() : QByteArray();
    }()), QStringLiteral("wf-recorder"));
    writeState(process.processId(), output);

    ScreenRecorderController controller;
    QVERIFY(controller.isRecording());
    QSignalSpy notificationSpy(&controller, &ScreenRecorderController::notificationRequested);
    controller.stopRecording();
    QVERIFY(!controller.isRecording());

    QTRY_VERIFY(!notificationSpy.isEmpty());
    QCOMPARE(notificationSpy.last().at(0).toString(), QStringLiteral("Recording Saved"));
    QCOMPARE(notificationSpy.last().at(1).toString(), output);
    QCOMPARE(controller.lastSavedFile(), output);
    QVERIFY(!QFileInfo::exists(stateDir() + QStringLiteral("/record.pid")));
}

void ScreenRecorderTests::aRecorderExitingOnItsOwnEndsTheRecording() {
    const QByteArray originalPath = qgetenv("PATH");
    const auto restorePath = qScopeGuard([&originalPath] { qputenv("PATH", originalPath); });
    const QString binDir = m_tempDir->path() + QStringLiteral("/exit-bin");
    QVERIFY(QDir().mkpath(binDir));
    // Runs until told to exit, like a recorder whose output goes away.
    const QString exitNow = m_tempDir->path() + QStringLiteral("/exit-now");
    QVERIFY(writeFakeExecutable(binDir + QStringLiteral("/wf-recorder"),
        "#!/bin/sh\nwhile [ ! -e '" + exitNow.toUtf8() + "' ]; do /bin/sleep 0.05; done\n"));
    QVERIFY(writeFakeExecutable(binDir + QStringLiteral("/pactl"), "#!/bin/sh\nexit 1\n"));
    qputenv("PATH", binDir.toUtf8());

    ScreenRecorderController controller;
    controller.setRecordingsDir(m_tempDir->path() + QStringLiteral("/exit-recordings"));
    QSignalSpy notificationSpy(&controller, &ScreenRecorderController::notificationRequested);
    controller.startRecording(false);
    QVERIFY(controller.isRecording());
    QTest::qWait(1200);
    QVERIFY(controller.isRecording());

    QFile marker(exitNow);
    QVERIFY(marker.open(QIODevice::WriteOnly));
    marker.close();
    QTRY_VERIFY_WITH_TIMEOUT(!controller.isRecording(), 6000);
    QCOMPARE(notificationSpy.last().at(0).toString(), QStringLiteral("Recording Stopped"));
    QVERIFY(!QFileInfo::exists(stateDir() + QStringLiteral("/record.pid")));
    QVERIFY(!QFileInfo::exists(stateDir() + QStringLiteral("/record.output")));
}

void ScreenRecorderTests::symlinkedStateFilesAreNotFollowed() {
    const QString binDir = m_tempDir->path() + QStringLiteral("/symlink-bin");
    QVERIFY(QDir().mkpath(binDir));
    const QString recorder = binDir + QStringLiteral("/wf-recorder");
    QVERIFY(writeFakeExecutable(recorder, "#!/bin/sh\n/bin/sleep 30\n"));
    QProcess process;
    process.start(recorder, {});
    QVERIFY(process.waitForStarted());
    const auto cleanup = qScopeGuard([&process] { process.kill(); process.waitForFinished(); });

    QVERIFY(QDir().mkpath(stateDir()));
    const QString elsewhere = m_tempDir->path() + QStringLiteral("/elsewhere.pid");
    QFile target(elsewhere);
    QVERIFY(target.open(QIODevice::WriteOnly));
    target.write(QByteArray::number(process.processId()) + '\n');
    target.close();
    QFile::remove(stateDir() + QStringLiteral("/record.pid"));
    QVERIFY(QFile::link(elsewhere, stateDir() + QStringLiteral("/record.pid")));
    QTRY_COMPARE(QString::fromUtf8([&process] {
        QFile comm(QStringLiteral("/proc/%1/comm").arg(process.processId()));
        return comm.open(QIODevice::ReadOnly) ? comm.readAll().trimmed() : QByteArray();
    }()), QStringLiteral("wf-recorder"));

    ScreenRecorderController controller;
    QVERIFY(!controller.isRecording());
    QFile::remove(stateDir() + QStringLiteral("/record.pid"));
}

// A fake systemd-run that takes its time before it execs the program, so the recorder's pid is
// still named systemd-run when the recording is stopped.
static void installSlowScopes(const QString &directory, const QString &delay) {
    QVERIFY(QDir().mkpath(directory + QStringLiteral("/systemd")));
    QFile socket(directory + QStringLiteral("/systemd/private"));
    QVERIFY(socket.open(QIODevice::WriteOnly));
    socket.close();
    QVERIFY(writeFakeExecutable(directory + QStringLiteral("/bin/systemd-run"),
        "#!/bin/sh\nif [ \"$1\" = --version ]; then echo 'systemd 262'; exit 0; fi\n"
        "while [ $# -gt 0 ]; do if [ \"$1\" = -- ]; then shift; break; fi; shift; done\n"
        "if [ \"$1\" = true ]; then exit 0; fi\n/bin/sleep " + delay.toUtf8() + "\nexec \"$@\"\n"));
    ScopedLaunch::resetProbe();
    ScopedLaunch::probe();
    QTRY_VERIFY(ScopedLaunch::scopesAvailable());
}

void ScreenRecorderTests::stoppingWhileTheScopeIsStartingStopsTheRecorder() {
    const QString binDir = m_tempDir->path() + QStringLiteral("/bin");
    QVERIFY(QDir().mkpath(binDir));
    const QString started = m_tempDir->path() + QStringLiteral("/recorder-started");
    QVERIFY(writeFakeExecutable(binDir + QStringLiteral("/wf-recorder"),
        "#!/bin/sh\n: > '" + started.toUtf8() + "'\n/bin/sleep 30\n"));
    QVERIFY(writeFakeExecutable(binDir + QStringLiteral("/pactl"), "#!/bin/sh\nexit 1\n"));
    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", binDir.toUtf8());
    const auto restore = qScopeGuard([&originalPath] { qputenv("PATH", originalPath); ScopedLaunch::resetProbe(); });
    installSlowScopes(m_tempDir->path(), QStringLiteral("1"));

    ScreenRecorderController controller;
    controller.setRecordingsDir(m_tempDir->path() + QStringLiteral("/race-recordings"));
    controller.startRecording(false);
    QVERIFY(controller.isRecording());
    controller.stopRecording();
    QVERIFY(!controller.isRecording());

    // The scope was signalled before it started the recorder, so nothing records untracked.
    QTest::qWait(2000);
    QVERIFY(!QFileInfo::exists(started));
}

void ScreenRecorderTests::aScopeThatNeverStartsTheRecorderIsGivenUp() {
    const QString binDir = m_tempDir->path() + QStringLiteral("/bin");
    QVERIFY(QDir().mkpath(binDir));
    QVERIFY(writeFakeExecutable(binDir + QStringLiteral("/wf-recorder"), "#!/bin/sh\n/bin/sleep 30\n"));
    QVERIFY(writeFakeExecutable(binDir + QStringLiteral("/pactl"), "#!/bin/sh\nexit 1\n"));
    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", binDir.toUtf8());
    const auto restore = qScopeGuard([&originalPath] { qputenv("PATH", originalPath); ScopedLaunch::resetProbe(); });
    installSlowScopes(m_tempDir->path(), QStringLiteral("60"));

    ScreenRecorderController controller;
    controller.setRecordingsDir(m_tempDir->path() + QStringLiteral("/stuck-recordings"));
    QSignalSpy notificationSpy(&controller, &ScreenRecorderController::notificationRequested);
    controller.startRecording(false);
    QVERIFY(controller.isRecording());

    QTRY_VERIFY_WITH_TIMEOUT(!controller.isRecording(), 10000);
    QCOMPARE(notificationSpy.last().at(0).toString(), QStringLiteral("Recording Failed"));
    QVERIFY(notificationSpy.last().at(1).toString().contains(QStringLiteral("did not start in time")));
}

QTEST_GUILESS_MAIN(ScreenRecorderTests)
#include "screen_recorder_tests.moc"
