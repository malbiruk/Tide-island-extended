#pragma once

#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QStringList>
#include <QTimer>

#include <functional>
#include <memory>

// User-facing programs (apps, lockers, the recorder) run in their own transient systemd scope,
// outside tide-island.service's cgroup, so restarting or stopping the shell never takes them
// down. `systemd-run --scope` execs the program in place: the PID, exit code and signals are the
// program's own. Scopes are used only once a probe scope has worked; until then, or without a
// user manager, programs start as plain children.
//
// Children get the environment the shell was started with, not the one Quickshell adjusted for
// itself (it forces its own Qt style variables), minus what the service adds, and with the
// launcher's own variables (MALLOC_CONF, QML_IMPORT_PATH, QUICKSHELL_LYRICS_BACKEND) put back
// to the user's values.
namespace ScopedLaunch {

inline const QStringList &serviceVariables()
{
    static const QStringList names = {
        QStringLiteral("INVOCATION_ID"), QStringLiteral("JOURNAL_STREAM"), QStringLiteral("MANAGERPID"),
        QStringLiteral("MANAGERPIDFDID"), QStringLiteral("SYSTEMD_EXEC_PID"),
        QStringLiteral("MEMORY_PRESSURE_WATCH"), QStringLiteral("MEMORY_PRESSURE_WRITE"),
        // Startup notification belongs to the shell's own start, never to what it launches.
        QStringLiteral("XDG_ACTIVATION_TOKEN"), QStringLiteral("DESKTOP_STARTUP_ID"),
    };
    return names;
}

inline const QStringList &launcherVariables()
{
    static const QStringList names = {
        QStringLiteral("MALLOC_CONF"), QStringLiteral("QML_IMPORT_PATH"), QStringLiteral("QUICKSHELL_LYRICS_BACKEND"),
    };
    return names;
}

// The launcher sets TIDE_ISLAND_LAUNCHER=1 and keeps a variable's previous value, if it had one,
// in TIDE_ISLAND_ORIGINAL_<name>.
inline QProcessEnvironment childEnvironment(QProcessEnvironment environment)
{
    for (const QString &name : serviceVariables())
        environment.remove(name);
    if (environment.contains(QStringLiteral("TIDE_ISLAND_LAUNCHER"))) {
        for (const QString &name : launcherVariables()) {
            const QString original = QStringLiteral("TIDE_ISLAND_ORIGINAL_") + name;
            if (environment.contains(original))
                environment.insert(name, environment.value(original));
            else
                environment.remove(name);
            environment.remove(original);
        }
        environment.remove(QStringLiteral("TIDE_ISLAND_LAUNCHER"));
    }
    return environment;
}

// The process's environment as it was at exec (setenv/unsetenv never change this block).
inline QProcessEnvironment initialEnvironment()
{
    QFile file(QStringLiteral("/proc/self/environ"));
    if (!file.open(QIODevice::ReadOnly))
        return QProcessEnvironment::systemEnvironment();
    QProcessEnvironment environment;
    const QList<QByteArray> entries = file.readAll().split('\0');
    for (const QByteArray &entry : entries) {
        const qsizetype separator = entry.indexOf('=');
        if (separator > 0)
            environment.insert(QString::fromLocal8Bit(entry.left(separator)),
                               QString::fromLocal8Bit(entry.mid(separator + 1)));
    }
    return environment;
}

inline QProcessEnvironment environment()
{
    return childEnvironment(initialEnvironment());
}

struct ScopeSupport {
    enum State { Unknown, Probing, Supported, Unsupported };
    State state = Unknown;
    QStringList prefix;
    qint64 retryAfterMs = 0;
};

inline ScopeSupport &scopeSupport()
{
    static ScopeSupport support;
    return support;
}

inline constexpr int ProbeTimeoutMs = 5000;
inline constexpr qint64 ProbeRetryMs = 60000;

using ProbeStepDone = std::function<void(int exitCode, bool timedOut, const QByteArray &output)>;

// One probe step without blocking. `done` gets the exit code (-1 when it could not start or
// crashed), or timedOut, which is no verdict: the probe is simply run again on a later launch.
inline void runProbeStep(const QStringList &argv, ProbeStepDone done)
{
    auto *process = new QProcess;
    auto settled = std::make_shared<bool>(false);
    process->setProcessEnvironment(environment());
    process->setStandardInputFile(QProcess::nullDevice());
    QObject::connect(process, &QProcess::finished, process,
                     [process, settled, done](int exitCode, QProcess::ExitStatus status) {
        if (*settled)
            return;
        *settled = true;
        done(status == QProcess::NormalExit ? exitCode : -1, false, process->readAllStandardOutput());
        process->deleteLater();
    });
    QObject::connect(process, &QProcess::errorOccurred, process, [process, settled, done](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart || *settled)
            return;
        *settled = true;
        done(-1, false, QByteArray());
        process->deleteLater();
    });
    QTimer::singleShot(ProbeTimeoutMs, process, [process, settled, done]() {
        if (*settled)
            return;
        *settled = true;
        process->disconnect();
        QObject::connect(process, &QProcess::finished, process, &QObject::deleteLater);
        process->kill();
        done(-1, true, QByteArray());
    });
    process->start(argv.first(), argv.mid(1));
}

inline void settleProbe(ScopeSupport::State state, const QStringList &prefix = {})
{
    ScopeSupport &support = scopeSupport();
    support.state = state;
    support.prefix = prefix;
    support.retryAfterMs = QDateTime::currentMSecsSinceEpoch() + ProbeRetryMs;
}

// Asks systemd-run for its version (systemd 254+ expands $VARIABLES in the command line unless
// told not to), then starts a real test scope; scopes are used only after that worked. A failed
// probe is retried after a minute, a timed-out one on the next launch.
inline void probe()
{
    ScopeSupport &support = scopeSupport();
    if (support.state == ScopeSupport::Probing || support.state == ScopeSupport::Supported)
        return;
    if (support.state == ScopeSupport::Unsupported && QDateTime::currentMSecsSinceEpoch() < support.retryAfterMs)
        return;

    const QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR");
    const QString systemdRun = QStandardPaths::findExecutable(QStringLiteral("systemd-run"));
    if (runtimeDir.isEmpty() || systemdRun.isEmpty()
            || !QFileInfo::exists(runtimeDir + QStringLiteral("/systemd/private"))) {
        settleProbe(ScopeSupport::Unsupported);
        return;
    }

    support.state = ScopeSupport::Probing;
    runProbeStep({systemdRun, QStringLiteral("--version")}, [systemdRun](int exitCode, bool timedOut, const QByteArray &output) {
        if (timedOut || exitCode != 0) {
            settleProbe(timedOut ? ScopeSupport::Unknown : ScopeSupport::Unsupported);
            return;
        }
        static const QRegularExpression versionPattern(QStringLiteral("^systemd (\\d+)"));
        const QRegularExpressionMatch match = versionPattern.match(QString::fromUtf8(output));
        // A fixed description: the default one is the command line, URLs and file names included.
        QStringList prefix{systemdRun, QStringLiteral("--user"), QStringLiteral("--scope"), QStringLiteral("--quiet"),
                           QStringLiteral("--collect"), QStringLiteral("--description=Tide Island launch")};
        if (match.hasMatch() && match.captured(1).toInt() >= 254)
            prefix << QStringLiteral("--expand-environment=no");
        prefix << QStringLiteral("--");

        runProbeStep(prefix + QStringList{QStringLiteral("true")}, [prefix](int exitCode, bool timedOut, const QByteArray &) {
            if (timedOut)
                settleProbe(ScopeSupport::Unknown);
            else if (exitCode == 0)
                settleProbe(ScopeSupport::Supported, prefix);
            else
                settleProbe(ScopeSupport::Unsupported);
        });
    });
}

inline bool scopesAvailable()
{
    return scopeSupport().state == ScopeSupport::Supported;
}

// The command line that runs argv in its own scope, or argv itself while scopes are not (yet)
// available; that also starts the probe when one is due.
inline QStringList command(const QStringList &argv)
{
    if (argv.isEmpty() || argv.first().isEmpty())
        return {};
    if (scopesAvailable())
        return scopeSupport().prefix + argv;
    probe();
    return argv;
}

inline bool startDetached(const QStringList &argv, qint64 *pid = nullptr)
{
    const QStringList full = command(argv);
    if (full.isEmpty())
        return false;
    QProcess process;
    process.setProgram(full.first());
    process.setArguments(full.mid(1));
    process.setProcessEnvironment(environment());
    process.setStandardInputFile(QProcess::nullDevice());
    return process.startDetached(pid);
}

// Runs argv without tying it to whoever asked: the QProcess has no parent, so neither an
// unloaded QML layer nor a QML engine reload kills the program. `finished` gets the exit code,
// or -1 when it could not be started or crashed.
inline void run(const QStringList &argv, std::function<void(int exitCode)> finished)
{
    const QStringList full = command(argv);
    auto *process = new QProcess;
    QObject::connect(process, &QProcess::finished, process, [process, finished](int exitCode, QProcess::ExitStatus status) {
        finished(status == QProcess::NormalExit ? exitCode : -1);
        process->deleteLater();
    });
    QObject::connect(process, &QProcess::errorOccurred, process, [process, finished](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart)
            return;
        finished(-1);
        process->deleteLater();
    });
    if (full.isEmpty()) {
        QTimer::singleShot(0, process, [process, finished]() {
            finished(-1);
            process->deleteLater();
        });
        return;
    }
    process->setProcessEnvironment(environment());
    process->setStandardInputFile(QProcess::nullDevice());
    process->setProcessChannelMode(QProcess::ForwardedChannels);
    process->start(full.first(), full.mid(1));
}

// Forgets the probe result (tests).
inline void resetProbe()
{
    scopeSupport() = ScopeSupport();
}

} // namespace ScopedLaunch
