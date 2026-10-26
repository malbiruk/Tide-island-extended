#include "ScreenRecorderController.h"
#include "SystemServices.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcess>
#include <QScreen>
#include <QStandardPaths>

#include <csignal>
#include <sys/types.h>
#include <unistd.h>

ScreenRecorderController *ScreenRecorderController::s_instance = nullptr;

ScreenRecorderController::ScreenRecorderController(QObject *parent)
    : QObject(parent)
{
    s_instance = this;

    m_gsrPath = QStandardPaths::findExecutable(QStringLiteral("gpu-screen-recorder"));
    m_wfRecorderPath = QStandardPaths::findExecutable(QStringLiteral("wf-recorder"));

    const QString home = QDir::homePath();
    m_recordingsDir = home + QStringLiteral("/Videos/ScreenRecordings/Recordings");
    m_replaysDir = home + QStringLiteral("/Videos/ScreenRecordings/Replays");

    ensureDirectories();

    connect(&m_tickTimer, &QTimer::timeout, this, &ScreenRecorderController::onTick);
    m_tickTimer.setInterval(1000);

    connect(&m_pollTimer, &QTimer::timeout, this, &ScreenRecorderController::pollExternalState);
    m_pollTimer.setInterval(1200);
    m_pollTimer.start();

    // Initial check for already-running instances
    pollExternalState();
}

ScreenRecorderController::~ScreenRecorderController() {
    if (s_instance == this) {
        s_instance = nullptr;
    }
}

ScreenRecorderController *ScreenRecorderController::instance() {
    return s_instance;
}

bool ScreenRecorderController::isAvailable() const {
    return !m_gsrPath.isEmpty() || !m_wfRecorderPath.isEmpty();
}

// Pause (SIGUSR2) and the replay buffer are gpu-screen-recorder features.
bool ScreenRecorderController::canPause() const {
    return !m_gsrPath.isEmpty();
}

bool ScreenRecorderController::canReplay() const {
    return !m_gsrPath.isEmpty();
}

bool ScreenRecorderController::isRecording() const {
    return m_isRecording;
}

bool ScreenRecorderController::isPaused() const {
    return m_isPaused;
}

bool ScreenRecorderController::isReplayActive() const {
    return m_isReplayActive;
}

int ScreenRecorderController::recordingSeconds() const {
    return m_recordingSeconds;
}

QString ScreenRecorderController::recordingTimeFormatted() const {
    const int minutes = m_recordingSeconds / 60;
    const int seconds = m_recordingSeconds % 60;
    return QStringLiteral("%1:%2")
        .arg(minutes, 2, 10, QLatin1Char('0'))
        .arg(seconds, 2, 10, QLatin1Char('0'));
}

bool ScreenRecorderController::micEnabled() const {
    return m_micEnabled;
}

void ScreenRecorderController::setMicEnabled(bool enabled) {
    if (m_micEnabled == enabled)
        return;
    m_micEnabled = enabled;
    emit micEnabledChanged();
}

int ScreenRecorderController::fps() const {
    return m_fps;
}

void ScreenRecorderController::setFps(int value) {
    if (value <= 0 || m_fps == value)
        return;
    m_fps = value;
    emit fpsChanged();
}

int ScreenRecorderController::replaySeconds() const {
    return m_replaySeconds;
}

void ScreenRecorderController::setReplaySeconds(int value) {
    if (value <= 0 || m_replaySeconds == value)
        return;
    m_replaySeconds = value;
    emit replaySecondsChanged();
}

QString ScreenRecorderController::screenName() const {
    return m_screenName;
}

void ScreenRecorderController::setScreenName(const QString &name) {
    if (m_screenName == name)
        return;
    m_screenName = name;
    emit screenNameChanged();
}

QString ScreenRecorderController::recordingsDir() const {
    return m_recordingsDir;
}

void ScreenRecorderController::setRecordingsDir(const QString &dir) {
    if (m_recordingsDir == dir)
        return;
    m_recordingsDir = dir;
    ensureDirectories();
    emit recordingsDirChanged();
}

QString ScreenRecorderController::replaysDir() const {
    return m_replaysDir;
}

void ScreenRecorderController::setReplaysDir(const QString &dir) {
    if (m_replaysDir == dir)
        return;
    m_replaysDir = dir;
    ensureDirectories();
    emit replaysDirChanged();
}

QString ScreenRecorderController::lastSavedFile() const {
    return m_lastSavedFile;
}

QString ScreenRecorderController::stateDir() const {
    const QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR");
    return (runtimeDir.isEmpty() ? QStringLiteral("/tmp") : runtimeDir) + QStringLiteral("/gsr");
}

QString ScreenRecorderController::recordPidFilePath() const {
    return stateDir() + QStringLiteral("/record.pid");
}

QString ScreenRecorderController::replayPidFilePath() const {
    return stateDir() + QStringLiteral("/replay.pid");
}

void ScreenRecorderController::ensureDirectories() {
    QDir().mkpath(m_recordingsDir);
    QDir().mkpath(m_replaysDir);
    QDir().mkpath(stateDir());
}

qint64 ScreenRecorderController::readPidFromFile(const QString &path) const {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return 0;
    const QString content = QString::fromUtf8(file.readAll()).trimmed();
    bool ok = false;
    const qint64 pid = content.toLongLong(&ok);
    return ok ? pid : 0;
}

void ScreenRecorderController::writePidToFile(const QString &path, qint64 pid) const {
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        file.write(QByteArray::number(pid) + '\n');
        file.close();
    }
}

void ScreenRecorderController::removePidFile(const QString &path) const {
    QFile::remove(path);
}

bool ScreenRecorderController::isProcessRunning(qint64 pid) const {
    if (pid <= 0)
        return false;
    if (kill(static_cast<pid_t>(pid), 0) != 0)
        return false;

    // Verify it is actually gpu-screen-recorder or wf-recorder
    const QString commPath = QStringLiteral("/proc/%1/comm").arg(pid);
    QFile file(commPath);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString comm = QString::fromUtf8(file.readAll()).trimmed();
        if (comm.contains(QStringLiteral("gpu-screen-reco")) || comm.contains(QStringLiteral("gpu-screen"))
                || comm == QStringLiteral("wf-recorder"))
            return true;
    }

    const QString cmdlinePath = QStringLiteral("/proc/%1/cmdline").arg(pid);
    QFile cmdFile(cmdlinePath);
    if (cmdFile.open(QIODevice::ReadOnly)) {
        const QString cmd = QString::fromUtf8(cmdFile.readAll());
        if (cmd.contains(QStringLiteral("gpu-screen-recorder")) || cmd.contains(QStringLiteral("wf-recorder")))
            return true;
    }

    return false;
}

QString ScreenRecorderController::detectDefaultScreen() const {
    if (!m_screenName.isEmpty())
        return m_screenName;
    if (!m_cachedDetectedScreen.isEmpty())
        return m_cachedDetectedScreen;

    const QString gsr = m_gsrPath;
    if (gsr.isEmpty()) {
        // wf-recorder mode: wl_output names as Qt sees them (primary screen first).
        QList<QScreen *> screens = QGuiApplication::screens();
        if (QScreen *primary = QGuiApplication::primaryScreen())
            screens.prepend(primary);
        for (const QScreen *screen : std::as_const(screens)) {
            if (screen && !screen->name().isEmpty()) {
                m_cachedDetectedScreen = screen->name();
                return m_cachedDetectedScreen;
            }
        }
    } else {
        QProcess proc;
        proc.start(gsr, {QStringLiteral("--list-monitors")});
        if (proc.waitForFinished(300)) {
            const QString out = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
            const QStringList lines = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
            for (const QString &line : lines) {
                const QString mon = line.section(QLatin1Char('|'), 0, 0).trimmed();
                if (!mon.isEmpty()) {
                    m_cachedDetectedScreen = mon;
                    return m_cachedDetectedScreen;
                }
            }
        }
    }

    m_cachedDetectedScreen = QStringLiteral("eDP-1");
    return m_cachedDetectedScreen;
}

QString ScreenRecorderController::resolveAudioSource(bool withMic) const {
    if (withMic)
        return QStringLiteral("default_output|default_input");
    return QStringLiteral("default_output");
}

// wf-recorder captures a single PulseAudio source, so gsr's "desktop + mic" mix has no
// equivalent: with the mic enabled we record the default source (the mic), otherwise the
// default sink's monitor (desktop audio). Returns an empty string if pactl can't tell us.
QString ScreenRecorderController::resolveWfRecorderAudioDevice(bool withMic) const {
    QProcess pactl;
    pactl.start(QStringLiteral("pactl"),
                {withMic ? QStringLiteral("get-default-source") : QStringLiteral("get-default-sink")});
    if (!pactl.waitForFinished(500) || pactl.exitStatus() != QProcess::NormalExit || pactl.exitCode() != 0)
        return QString();

    const QString device = QString::fromUtf8(pactl.readAllStandardOutput()).trimmed();
    if (device.isEmpty())
        return QString();
    return withMic ? device : device + QStringLiteral(".monitor");
}

void ScreenRecorderController::startRecording(bool withMic) {
    if (m_isRecording) {
        emit notificationRequested(QStringLiteral("Screen Recorder"), QStringLiteral("Recording is already in progress."));
        return;
    }

    if (!isAvailable()) {
        emit notificationRequested(QStringLiteral("Screen Recorder"),
                                   QStringLiteral("Neither gpu-screen-recorder nor wf-recorder is installed."));
        return;
    }

    ensureDirectories();

    const bool useMic = withMic || m_micEnabled;
    const QString timestamp = QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd_hh-mm-ss"));
    m_currentRecordingFile = m_recordingsDir + QStringLiteral("/recording_%1.mp4").arg(timestamp);

    const QString screen = detectDefaultScreen();
    const bool useGsr = !m_gsrPath.isEmpty();

    QStringList args;
    if (useGsr) {
        const QString audio = resolveAudioSource(useMic);
        args << QStringLiteral("-w") << screen;
        args << QStringLiteral("-f") << QString::number(m_fps);
        args << QStringLiteral("-a") << audio;
        args << QStringLiteral("-cursor") << QStringLiteral("yes");
        args << QStringLiteral("-q") << QStringLiteral("very_high");
        args << QStringLiteral("-o") << m_currentRecordingFile;
    } else {
        // CPU H.264 in yuv420p for broad player compatibility; the container comes from the
        // .mp4 extension and -y avoids an overwrite prompt on stdin.
        args << QStringLiteral("-o") << screen;
        args << QStringLiteral("-f") << m_currentRecordingFile;
        args << QStringLiteral("-r") << QString::number(m_fps);
        args << QStringLiteral("-c") << QStringLiteral("libx264");
        args << QStringLiteral("-x") << QStringLiteral("yuv420p");
        args << QStringLiteral("-y");
        const QString audioDevice = resolveWfRecorderAudioDevice(useMic);
        if (!audioDevice.isEmpty())
            args << QStringLiteral("--audio=%1").arg(audioDevice);
    }

    const QString program = useGsr ? QStringLiteral("gpu-screen-recorder") : QStringLiteral("wf-recorder");
    qint64 pid = 0;
    const bool started = QProcess::startDetached(program, args, QString(), &pid);
    if (!started || pid <= 0) {
        emit notificationRequested(QStringLiteral("Screen Recorder"), QStringLiteral("Failed to start %1.").arg(program));
        return;
    }

    m_recordPid = pid;
    writePidToFile(recordPidFilePath(), pid);

    m_isRecording = true;
    m_isPaused = false;
    m_recordingSeconds = 0;
    m_tickTimer.start();

    emit recordingStateChanged();
    emit recordingSecondsChanged();

    const QString micStatus = useMic ? QStringLiteral("Mic ON") : QStringLiteral("Mic OFF");
    emit notificationRequested(QStringLiteral("Recording Started"),
                               QStringLiteral("%1 • %2 FPS • %3").arg(screen).arg(m_fps).arg(micStatus));

    if (SystemServices::instance())
        SystemServices::instance()->updateScreenRecordingActive();
}

void ScreenRecorderController::stopRecording() {
    qint64 pid = m_recordPid;
    if (pid <= 0)
        pid = readPidFromFile(recordPidFilePath());

    if (pid <= 0 || !isProcessRunning(pid)) {
        m_isRecording = false;
        m_isPaused = false;
        m_recordPid = 0;
        removePidFile(recordPidFilePath());
        m_tickTimer.stop();
        emit recordingStateChanged();
        if (SystemServices::instance())
            SystemServices::instance()->updateScreenRecordingActive();
        return;
    }

    // SIGINT cleanly finishes the MP4 container
    kill(static_cast<pid_t>(pid), SIGINT);
    removePidFile(recordPidFilePath());

    m_isRecording = false;
    m_isPaused = false;
    m_recordPid = 0;
    m_tickTimer.stop();

    m_lastSavedFile = m_currentRecordingFile;
    emit lastSavedFileChanged();
    emit recordingStateChanged();

    emit notificationRequested(QStringLiteral("Recording Saved"),
                               m_currentRecordingFile.isEmpty() ? m_recordingsDir : m_currentRecordingFile);

    if (SystemServices::instance())
        SystemServices::instance()->updateScreenRecordingActive();
}

void ScreenRecorderController::toggleRecording() {
    if (m_isRecording)
        stopRecording();
    else
        startRecording(m_micEnabled);
}

void ScreenRecorderController::pauseRecording() {
    if (!canPause()) {
        emit notificationRequested(QStringLiteral("Recording"), QStringLiteral("Pausing requires gpu-screen-recorder."));
        return;
    }

    qint64 pid = m_recordPid;
    if (pid <= 0)
        pid = readPidFromFile(recordPidFilePath());

    if (pid <= 0 || !isProcessRunning(pid))
        return;

    // SIGUSR2 toggles pause/unpause in gpu-screen-recorder
    kill(static_cast<pid_t>(pid), SIGUSR2);

    m_isPaused = !m_isPaused;
    if (m_isPaused)
        m_tickTimer.stop();
    else
        m_tickTimer.start();

    emit recordingStateChanged();
    emit notificationRequested(QStringLiteral("Recording"),
                               m_isPaused ? QStringLiteral("Recording paused") : QStringLiteral("Recording resumed"));
}

void ScreenRecorderController::startReplay(bool withMic) {
    if (m_isReplayActive) {
        emit notificationRequested(QStringLiteral("Replay Buffer"), QStringLiteral("Replay buffer is already running."));
        return;
    }

    if (!canReplay()) {
        emit notificationRequested(QStringLiteral("Replay Buffer"),
                                   QStringLiteral("The replay buffer requires gpu-screen-recorder."));
        return;
    }

    ensureDirectories();

    const bool useMic = withMic || m_micEnabled;
    const QString screen = detectDefaultScreen();
    const QString audio = resolveAudioSource(useMic);

    QStringList args;
    args << QStringLiteral("-w") << screen;
    args << QStringLiteral("-f") << QString::number(m_fps);
    args << QStringLiteral("-a") << audio;
    args << QStringLiteral("-cursor") << QStringLiteral("yes");
    args << QStringLiteral("-c") << QStringLiteral("mp4");
    args << QStringLiteral("-bm") << QStringLiteral("cbr");
    args << QStringLiteral("-q") << QString::number(m_replayBitrate);
    args << QStringLiteral("-r") << QString::number(m_replaySeconds);
    args << QStringLiteral("-replay-storage") << QStringLiteral("ram");
    args << QStringLiteral("-o") << m_replaysDir;

    qint64 pid = 0;
    const bool started = QProcess::startDetached(QStringLiteral("gpu-screen-recorder"), args, QString(), &pid);
    if (!started || pid <= 0) {
        emit notificationRequested(QStringLiteral("Replay Buffer"), QStringLiteral("Failed to start replay buffer."));
        return;
    }

    m_replayPid = pid;
    writePidToFile(replayPidFilePath(), pid);

    m_isReplayActive = true;
    emit replayStateChanged();

    const QString micStatus = useMic ? QStringLiteral("Mic ON") : QStringLiteral("Mic OFF");
    emit notificationRequested(QStringLiteral("Replay Buffer Started"),
                               QStringLiteral("Buffering last %1s • %2").arg(m_replaySeconds).arg(micStatus));
}

void ScreenRecorderController::stopReplay() {
    qint64 pid = m_replayPid;
    if (pid <= 0)
        pid = readPidFromFile(replayPidFilePath());

    if (pid <= 0 || !isProcessRunning(pid)) {
        m_isReplayActive = false;
        m_replayPid = 0;
        removePidFile(replayPidFilePath());
        emit replayStateChanged();
        return;
    }

    kill(static_cast<pid_t>(pid), SIGINT);
    removePidFile(replayPidFilePath());

    m_isReplayActive = false;
    m_replayPid = 0;
    emit replayStateChanged();

    emit notificationRequested(QStringLiteral("Replay Buffer Stopped"), QStringLiteral("Replay buffer deactivated."));
}

void ScreenRecorderController::toggleReplay() {
    if (m_isReplayActive)
        stopReplay();
    else
        startReplay(m_micEnabled);
}

void ScreenRecorderController::saveReplay(int seconds) {
    qint64 pid = m_replayPid;
    if (pid <= 0)
        pid = readPidFromFile(replayPidFilePath());

    if (pid <= 0 || !isProcessRunning(pid)) {
        emit notificationRequested(QStringLiteral("Replay Buffer"), QStringLiteral("Replay buffer is not currently running."));
        return;
    }

    if (seconds == 10) {
        kill(static_cast<pid_t>(pid), SIGRTMIN + 1);
        emit notificationRequested(QStringLiteral("Replay Saved"), QStringLiteral("Saved last 10 seconds to Replays folder."));
    } else if (seconds == 30) {
        kill(static_cast<pid_t>(pid), SIGRTMIN + 2);
        emit notificationRequested(QStringLiteral("Replay Saved"), QStringLiteral("Saved last 30 seconds to Replays folder."));
    } else if (seconds == 60) {
        kill(static_cast<pid_t>(pid), SIGRTMIN + 3);
        emit notificationRequested(QStringLiteral("Replay Saved"), QStringLiteral("Saved last 60 seconds to Replays folder."));
    } else {
        // SIGUSR1 saves the entire configured buffer
        kill(static_cast<pid_t>(pid), SIGUSR1);
        emit notificationRequested(QStringLiteral("Replay Saved"),
                                   QStringLiteral("Saved last %1 seconds to Replays folder.").arg(m_replaySeconds));
    }
}

void ScreenRecorderController::toggleMic() {
    setMicEnabled(!m_micEnabled);
    emit notificationRequested(QStringLiteral("Microphone Audio"),
                               m_micEnabled ? QStringLiteral("Microphone capture enabled.") : QStringLiteral("Microphone capture disabled."));
}

void ScreenRecorderController::openRecordingsFolder() {
    ensureDirectories();
    QProcess::startDetached(QStringLiteral("xdg-open"), {m_recordingsDir});
}

void ScreenRecorderController::openReplaysFolder() {
    ensureDirectories();
    QProcess::startDetached(QStringLiteral("xdg-open"), {m_replaysDir});
}

void ScreenRecorderController::onTick() {
    if (!m_isRecording || m_isPaused)
        return;

    m_recordingSeconds++;
    emit recordingSecondsChanged();
}

void ScreenRecorderController::pollExternalState() {
    // Check recording PID
    const qint64 recPid = readPidFromFile(recordPidFilePath());
    const bool recRunning = isProcessRunning(recPid);

    if (recRunning != m_isRecording) {
        m_isRecording = recRunning;
        m_recordPid = recRunning ? recPid : 0;
        if (m_isRecording) {
            if (!m_tickTimer.isActive())
                m_tickTimer.start();
        } else {
            m_tickTimer.stop();
            m_isPaused = false;
        }
        emit recordingStateChanged();
        if (SystemServices::instance())
            SystemServices::instance()->updateScreenRecordingActive();
    }

    // Check replay PID
    const qint64 repPid = readPidFromFile(replayPidFilePath());
    const bool repRunning = isProcessRunning(repPid);

    if (repRunning != m_isReplayActive) {
        m_isReplayActive = repRunning;
        m_replayPid = repRunning ? repPid : 0;
        emit replayStateChanged();
    }
}
