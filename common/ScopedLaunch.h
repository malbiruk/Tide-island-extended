#pragma once

#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>
#include <QStringList>

// User-facing programs (apps, lockers, the recorder) run in their own transient systemd scope,
// outside tide-island.service's cgroup, so restarting or stopping the shell never takes them
// down. `systemd-run --scope` and `env` both exec in place: the PID, exit code and signals are
// the program's own. The scope still inherits this process's environment, so `env -u` drops
// what only the shell's service and launcher set.
namespace ScopedLaunch {

inline const QStringList &serviceOnlyVariables()
{
    static const QStringList names = {
        QStringLiteral("INVOCATION_ID"), QStringLiteral("JOURNAL_STREAM"), QStringLiteral("MANAGERPID"),
        QStringLiteral("MANAGERPIDFDID"), QStringLiteral("SYSTEMD_EXEC_PID"),
        QStringLiteral("MEMORY_PRESSURE_WATCH"), QStringLiteral("MEMORY_PRESSURE_WRITE"),
        QStringLiteral("MALLOC_CONF"), QStringLiteral("QML_IMPORT_PATH"),
        QStringLiteral("QUICKSHELL_LYRICS_BACKEND"), QStringLiteral("QS_ICON_THEME"),
    };
    return names;
}

// `systemd-run --user --scope …`, or empty when there is no systemd-run. Newer systemd-run
// expands $VARIABLES in the command line; arguments (URLs, file names) must reach the program as is.
inline const QStringList &scopePrefix()
{
    static const QStringList prefix = [] {
        const QString executable = QStandardPaths::findExecutable(QStringLiteral("systemd-run"));
        if (executable.isEmpty())
            return QStringList();
        QStringList result{executable, QStringLiteral("--user"), QStringLiteral("--scope"),
                           QStringLiteral("--quiet"), QStringLiteral("--collect")};
        QProcess help;
        help.start(executable, {QStringLiteral("--help")});
        if (help.waitForFinished(1000) && help.readAllStandardOutput().contains("--expand-environment"))
            result << QStringLiteral("--expand-environment=no");
        result << QStringLiteral("--");
        return result;
    }();
    return prefix;
}

// Scopes need the user manager; without one (tests, a non-systemd session) the program runs
// as a plain child.
inline bool userManagerAvailable()
{
    const QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR");
    return !runtimeDir.isEmpty() && QFileInfo::exists(runtimeDir + QStringLiteral("/systemd/private"));
}

inline QStringList command(const QStringList &argv)
{
    if (argv.isEmpty() || argv.first().isEmpty())
        return {};

    QStringList result;
    if (userManagerAvailable())
        result << scopePrefix();
    result << QStringLiteral("/usr/bin/env");
    for (const QString &name : serviceOnlyVariables())
        result << QStringLiteral("-u") << name;
    result << QStringLiteral("--") << argv;
    return result;
}

inline bool startDetached(const QStringList &argv, qint64 *pid = nullptr)
{
    const QStringList full = command(argv);
    if (full.isEmpty())
        return false;
    return QProcess::startDetached(full.first(), full.mid(1), QString(), pid);
}

} // namespace ScopedLaunch
