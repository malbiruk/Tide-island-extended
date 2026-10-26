#include "ScreenRecorderController.h"
#include "SystemServices.h"
#include "../common/ScopedLaunch.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcess>
#include <QScreen>
#include <QStandardPaths>

#include <algorithm>
#include <csignal>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

ScreenRecorderController *ScreenRecorderController::s_instance = nullptr;

ScreenRecorderController::ScreenRecorderController(QObject *parent)
    : QObject(parent)
{
    s_instance = this;

    m_wfRecorderPath = QStandardPaths::findExecutable(QStringLiteral("wf-recorder"));

    const QString home = QDir::homePath();
    m_recordingsDir = home + QStringLiteral("/Videos/ScreenRecordings/Recordings");

    connect(&m_tickTimer, &QTimer::timeout, this, &ScreenRecorderController::onTick);
    m_tickTimer.setInterval(1000);

    // Only while recording: notices a recorder that exits on its own.
    connect(&m_pollTimer, &QTimer::timeout, this, &ScreenRecorderController::pollExternalState);
    m_pollTimer.setInterval(1200);

    connect(&m_stopPollTimer, &QTimer::timeout, this, &ScreenRecorderController::pollStoppingRecorder);
    m_stopPollTimer.setInterval(250);

    adoptRunningRecorder();
}

// A recording started before the shell (re)started keeps going: pick it up from the state
// files, or remove them if that recorder is gone.
void ScreenRecorderController::adoptRunningRecorder() {
    const qint64 pid = readPidFromFile(recordPidFilePath());
    if (pid <= 0)
        return;
    if (!isProcessRunning(pid)) {
        clearRecordingState();
        return;
    }

    m_recordPid = pid;
    m_currentRecordingFile = readRecordingOutput();
    const QDateTime startedAt = QFileInfo(recordPidFilePath()).lastModified();
    m_recordingSeconds = startedAt.isValid() ? std::max<qint64>(0, startedAt.secsTo(QDateTime::currentDateTime())) : 0;
    m_isRecording = true;
    m_tickTimer.start();
    m_pollTimer.start();
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
    return !m_wfRecorderPath.isEmpty();
}

bool ScreenRecorderController::isRecording() const {
    return m_isRecording;
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
    emit recordingsDirChanged();
}

QString ScreenRecorderController::lastSavedFile() const {
    return m_lastSavedFile;
}

// In the user's runtime directory only (never a shared /tmp); empty when there is none.
QString ScreenRecorderController::stateDir() const {
    const QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    return runtimeDir.isEmpty() ? QString() : runtimeDir + QStringLiteral("/tide-island-recorder");
}

// The state directory exists, is a real directory (not a symlink) and is ours.
bool ScreenRecorderController::ensureStateDir() const {
    const QString dir = stateDir();
    if (dir.isEmpty())
        return false;
    const QByteArray path = QFile::encodeName(dir);
    ::mkdir(path.constData(), 0700);
    struct stat info {};
    return ::lstat(path.constData(), &info) == 0 && S_ISDIR(info.st_mode) && info.st_uid == ::getuid();
}

// State files are never followed through symlinks.
QByteArray ScreenRecorderController::readStateFile(const QString &path) const {
    if (stateDir().isEmpty())
        return QByteArray();
    const int fd = ::open(QFile::encodeName(path).constData(), O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0)
        return QByteArray();
    QFile file;
    if (!file.open(fd, QIODevice::ReadOnly, QFileDevice::AutoCloseHandle)) {
        ::close(fd);
        return QByteArray();
    }
    return file.read(4096);
}

bool ScreenRecorderController::writeStateFile(const QString &path, const QByteArray &contents) const {
    if (!ensureStateDir())
        return false;
    const int fd = ::open(QFile::encodeName(path).constData(), O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (fd < 0)
        return false;
    QFile file;
    if (!file.open(fd, QIODevice::WriteOnly, QFileDevice::AutoCloseHandle)) {
        ::close(fd);
        return false;
    }
    return file.write(contents) == contents.size();
}

QString ScreenRecorderController::recordPidFilePath() const {
    return stateDir() + QStringLiteral("/record.pid");
}

// The output file of the running recorder, kept beside its pid for a shell that adopts it.
QString ScreenRecorderController::recordOutputFilePath() const {
    return stateDir() + QStringLiteral("/record.output");
}

void ScreenRecorderController::ensureDirectories() {
    QDir().mkpath(m_recordingsDir);
}

void ScreenRecorderController::writeRecordingState(qint64 pid, const QString &outputFile) const {
    writeStateFile(recordPidFilePath(), QByteArray::number(pid) + '\n');
    writeStateFile(recordOutputFilePath(), outputFile.toUtf8() + '\n');
}

QString ScreenRecorderController::readRecordingOutput() const {
    return QString::fromUtf8(readStateFile(recordOutputFilePath())).trimmed();
}

void ScreenRecorderController::clearRecordingState() const {
    if (stateDir().isEmpty())
        return;
    QFile::remove(recordPidFilePath());
    QFile::remove(recordOutputFilePath());
}

qint64 ScreenRecorderController::readPidFromFile(const QString &path) const {
    bool ok = false;
    const qint64 pid = QString::fromUtf8(readStateFile(path)).trimmed().toLongLong(&ok);
    return ok ? pid : 0;
}

// The process name, empty when there is no such process or it has already exited (zombie).
QString ScreenRecorderController::processName(qint64 pid) const {
    if (pid <= 0 || kill(static_cast<pid_t>(pid), 0) != 0)
        return QString();
    QFile stat(QStringLiteral("/proc/%1/stat").arg(pid));
    if (!stat.open(QIODevice::ReadOnly))
        return QString();
    const QByteArray fields = stat.readAll();
    const qsizetype nameEnd = fields.lastIndexOf(')');
    if (nameEnd < 0 || nameEnd + 2 >= fields.size() || fields.at(nameEnd + 2) == 'Z')
        return QString();
    QFile comm(QStringLiteral("/proc/%1/comm").arg(pid));
    if (!comm.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    return QString::fromUtf8(comm.readAll()).trimmed();
}

// Only a process named wf-recorder counts: the pid may have been reused.
bool ScreenRecorderController::isProcessRunning(qint64 pid) const {
    return processName(pid) == QLatin1String("wf-recorder");
}

// A recorder this controller started may still be systemd-run setting up its scope; it becomes
// wf-recorder in place, so it is alive and must be signalled like one.
bool ScreenRecorderController::isOwnRecorderRunning(qint64 pid) const {
    const QString name = processName(pid);
    return name == QLatin1String("wf-recorder") || name == QLatin1String("systemd-run");
}

// wf-recorder output: the configured screen, else the current wl_output name as Qt sees it
// (primary first; looked up at every start, not cached). Empty means "omit -o": wf-recorder
// then records the only output, or asks which one when there are several.
QString ScreenRecorderController::outputName() const {
    if (!m_screenName.isEmpty())
        return m_screenName;

    QList<QScreen *> screens = QGuiApplication::screens();
    if (QScreen *primary = QGuiApplication::primaryScreen())
        screens.prepend(primary);
    for (const QScreen *screen : std::as_const(screens)) {
        if (screen && !screen->name().isEmpty())
            return screen->name();
    }
    return QString();
}

// Millisecond timestamp plus a numeric suffix if that name is somehow taken; the recorder is
// never asked to overwrite.
QString ScreenRecorderController::uniqueRecordingPath() const {
    const QString base = m_recordingsDir + QStringLiteral("/recording_")
        + QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd_hh-mm-ss-zzz"));
    QString path = base + QStringLiteral(".mp4");
    for (int suffix = 1; QFileInfo::exists(path); ++suffix)
        path = base + QStringLiteral("_%1.mp4").arg(suffix);
    return path;
}

// wf-recorder captures a single PulseAudio source: with the mic enabled the default source
// (the mic), otherwise the default sink's monitor (desktop audio). Empty if pactl can't tell.
QString ScreenRecorderController::resolveAudioDevice(bool withMic) const {
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

    if (m_stoppingPid > 0) {
        emit notificationRequested(QStringLiteral("Screen Recorder"), QStringLiteral("Still saving the previous recording…"));
        return;
    }

    if (!isAvailable()) {
        emit notificationRequested(QStringLiteral("Screen Recorder"),
                                   QStringLiteral("wf-recorder is not installed."));
        return;
    }

    if (!ensureStateDir()) {
        emit notificationRequested(QStringLiteral("Screen Recorder"),
                                   QStringLiteral("No private runtime directory to keep the recording state in."));
        return;
    }
    ensureDirectories();

    const bool useMic = withMic || m_micEnabled;
    m_currentRecordingFile = uniqueRecordingPath();

    const QString screen = outputName();

    // CPU H.264 (veryfast preset, cheap enough for real time) in yuv420p for broad player
    // compatibility; the container comes from the .mp4 extension. The target path is unique,
    // so wf-recorder never asks about overwriting.
    QStringList args;
    if (!screen.isEmpty())
        args << QStringLiteral("-o") << screen;
    args << QStringLiteral("-f") << m_currentRecordingFile;
    args << QStringLiteral("-r") << QString::number(m_fps);
    args << QStringLiteral("-c") << QStringLiteral("libx264");
    args << QStringLiteral("-p") << QStringLiteral("preset=veryfast");
    args << QStringLiteral("-x") << QStringLiteral("yuv420p");
    // The device names come from pactl, so use the PulseAudio backend explicitly.
    QString audioStatus;
    const QString audioDevice = resolveAudioDevice(useMic);
    if (!audioDevice.isEmpty()) {
        args << QStringLiteral("--audio-backend=pulse");
        args << QStringLiteral("--audio=%1").arg(audioDevice);
        audioStatus = useMic ? QStringLiteral("Mic only") : QStringLiteral("Desktop audio");
    } else {
        audioStatus = QStringLiteral("No audio (audio device not found)");
    }

    qint64 pid = 0;
    // The scope execs wf-recorder in place, so pid is wf-recorder's own (signals, /proc/comm).
    const bool started = ScopedLaunch::startDetached(QStringList{m_wfRecorderPath} + args, &pid);
    if (!started || pid <= 0) {
        emit notificationRequested(QStringLiteral("Screen Recorder"), QStringLiteral("Failed to start wf-recorder."));
        return;
    }

    m_recordPid = pid;
    writeRecordingState(pid, m_currentRecordingFile);

    m_isRecording = true;
    m_recordingSeconds = 0;
    m_tickTimer.start();
    m_pollTimer.start();

    emit recordingStateChanged();
    emit recordingSecondsChanged();

    emit notificationRequested(QStringLiteral("Recording Started"),
                               QStringLiteral("%1 • %2 FPS • %3")
                                   .arg(screen.isEmpty() ? QStringLiteral("Default output") : screen)
                                   .arg(m_fps).arg(audioStatus));

    if (SystemServices::instance())
        SystemServices::instance()->updateScreenRecordingActive();

    // A recorder that rejects its arguments or output exits right away.
    m_startCheckPid = pid;
    m_startCheckAttempts = 0;
    QTimer::singleShot(800, this, [this, pid, screen]() {
        checkRecorderStarted(pid, screen);
    });
}

void ScreenRecorderController::checkRecorderStarted(qint64 pid, const QString &screen) {
    if (m_startCheckPid != pid)
        return;

    // Still systemd-run setting up its scope (a slow user manager): look again for a while,
    // then give up and stop it so no recording can start untracked.
    const QString name = processName(pid);
    if (m_recordPid == pid && name == QLatin1String("systemd-run") && ++m_startCheckAttempts <= MaxStartChecks) {
        QTimer::singleShot(500, this, [this, pid, screen]() { checkRecorderStarted(pid, screen); });
        return;
    }
    m_startCheckPid = 0;

    if (m_recordPid != pid || name == QLatin1String("wf-recorder"))
        return;

    const bool gaveUp = name == QLatin1String("systemd-run");
    if (gaveUp)
        kill(static_cast<pid_t>(pid), SIGKILL);

    m_isRecording = false;
    m_recordPid = 0;
    clearRecordingState();
    m_tickTimer.stop();
    m_pollTimer.stop();
    emit recordingStateChanged();
    if (SystemServices::instance())
        SystemServices::instance()->updateScreenRecordingActive();

    emit notificationRequested(QStringLiteral("Recording Failed"), gaveUp
        ? QStringLiteral("wf-recorder did not start in time; nothing is being recorded.")
        : QStringLiteral("wf-recorder exited right after starting. Check the output name (%1) and that the "
                         "compositor supports screencopy.").arg(screen.isEmpty() ? QStringLiteral("default") : screen));
}

void ScreenRecorderController::stopRecording() {
    if (m_stoppingPid > 0)
        return;

    qint64 pid = m_recordPid;
    const bool ownPid = pid > 0;
    if (!ownPid)
        pid = readPidFromFile(recordPidFilePath());

    m_pollTimer.stop();
    if (pid <= 0 || !(ownPid ? isOwnRecorderRunning(pid) : isProcessRunning(pid))) {
        m_isRecording = false;
        m_recordPid = 0;
        clearRecordingState();
        m_tickTimer.stop();
        emit recordingStateChanged();
        if (SystemServices::instance())
            SystemServices::instance()->updateScreenRecordingActive();
        return;
    }

    // SIGINT cleanly finishes the MP4 container. Keep tracking the process (and its pid file)
    // until it has exited, so "Recording Saved" is only announced for a finished file.
    kill(static_cast<pid_t>(pid), SIGINT);
    m_startCheckPid = 0;
    m_stoppingPid = pid;
    m_stoppingFile = m_currentRecordingFile;
    m_stopEscalation = 0;
    m_stopElapsed.start();
    m_stopPollTimer.start();

    m_isRecording = false;
    m_recordPid = 0;
    m_tickTimer.stop();
    emit recordingStateChanged();

    if (SystemServices::instance())
        SystemServices::instance()->updateScreenRecordingActive();
}

// wf-recorder only notices SIGINT once the compositor delivers its next frame, which with
// damage-driven capture can wait until something on the output changes. Escalate gently.
void ScreenRecorderController::pollStoppingRecorder() {
    if (m_stoppingPid <= 0) {
        m_stopPollTimer.stop();
        return;
    }

    if (!isOwnRecorderRunning(m_stoppingPid)) {
        finishStoppedRecording(m_stopEscalation >= 2);
        return;
    }

    const qint64 elapsed = m_stopElapsed.elapsed();
    if (m_stopEscalation == 0 && elapsed >= 10000) {
        kill(static_cast<pid_t>(m_stoppingPid), SIGINT);
        m_stopEscalation = 1;
    } else if (m_stopEscalation == 1 && elapsed >= 20000) {
        kill(static_cast<pid_t>(m_stoppingPid), SIGTERM);
        m_stopEscalation = 2;
    } else if (m_stopEscalation == 2 && elapsed >= 30000) {
        kill(static_cast<pid_t>(m_stoppingPid), SIGKILL);
        m_stopEscalation = 3;
    }
}

void ScreenRecorderController::finishStoppedRecording(bool forced) {
    m_stopPollTimer.stop();
    if (readPidFromFile(recordPidFilePath()) == m_stoppingPid)
        clearRecordingState();
    m_stoppingPid = 0;

    const QString file = m_stoppingFile;
    m_stoppingFile.clear();

    if (!QFileInfo::exists(file)) {
        emit notificationRequested(QStringLiteral("Recording Failed"), QStringLiteral("No recording was written."));
        return;
    }

    m_lastSavedFile = file;
    emit lastSavedFileChanged();
    if (forced) {
        emit notificationRequested(QStringLiteral("Recording Stopped"),
                                   QStringLiteral("The recorder did not stop cleanly; %1 may be incomplete.").arg(file));
    } else {
        emit notificationRequested(QStringLiteral("Recording Saved"), file);
    }
}

void ScreenRecorderController::toggleRecording() {
    if (m_isRecording)
        stopRecording();
    else
        startRecording(m_micEnabled);
}

void ScreenRecorderController::toggleMic() {
    setMicEnabled(!m_micEnabled);
    emit notificationRequested(QStringLiteral("Microphone Audio"),
                               m_micEnabled ? QStringLiteral("Microphone capture enabled.") : QStringLiteral("Microphone capture disabled."));
}

void ScreenRecorderController::openRecordingsFolder() {
    ensureDirectories();
    ScopedLaunch::startDetached({QStringLiteral("xdg-open"), m_recordingsDir});
}

void ScreenRecorderController::onTick() {
    if (!m_isRecording)
        return;

    m_recordingSeconds++;
    emit recordingSecondsChanged();
}

// The recorder exited on its own (crash, output gone, killed): end the recording here too.
void ScreenRecorderController::pollExternalState() {
    if (!m_isRecording || m_startCheckPid > 0 || m_stoppingPid > 0) {
        if (!m_isRecording)
            m_pollTimer.stop();
        return;
    }
    if (isOwnRecorderRunning(m_recordPid))
        return;

    const QString file = m_currentRecordingFile;
    m_isRecording = false;
    m_recordPid = 0;
    clearRecordingState();
    m_tickTimer.stop();
    m_pollTimer.stop();
    emit recordingStateChanged();
    if (SystemServices::instance())
        SystemServices::instance()->updateScreenRecordingActive();

    emit notificationRequested(QStringLiteral("Recording Stopped"),
        !file.isEmpty() && QFileInfo::exists(file)
            ? QStringLiteral("wf-recorder exited on its own; what was recorded is in %1.").arg(file)
            : QStringLiteral("wf-recorder exited on its own."));
}
