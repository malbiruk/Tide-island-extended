#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QtQml/qqml.h>

// Screen recording through wf-recorder (wlr-screencopy).
class ScreenRecorderController final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(ScreenRecorder)
    QML_SINGLETON

    Q_PROPERTY(bool isRecording READ isRecording NOTIFY recordingStateChanged FINAL)
    Q_PROPERTY(int recordingSeconds READ recordingSeconds NOTIFY recordingSecondsChanged FINAL)
    Q_PROPERTY(QString recordingTimeFormatted READ recordingTimeFormatted NOTIFY recordingSecondsChanged FINAL)
    Q_PROPERTY(bool micEnabled READ micEnabled WRITE setMicEnabled NOTIFY micEnabledChanged FINAL)
    Q_PROPERTY(int fps READ fps WRITE setFps NOTIFY fpsChanged FINAL)
    Q_PROPERTY(QString screenName READ screenName WRITE setScreenName NOTIFY screenNameChanged FINAL)
    Q_PROPERTY(QString recordingsDir READ recordingsDir WRITE setRecordingsDir NOTIFY recordingsDirChanged FINAL)
    Q_PROPERTY(bool isAvailable READ isAvailable CONSTANT FINAL)
    Q_PROPERTY(QString lastSavedFile READ lastSavedFile NOTIFY lastSavedFileChanged FINAL)

public:
    explicit ScreenRecorderController(QObject *parent = nullptr);
    ~ScreenRecorderController() override;

    static ScreenRecorderController *instance();

    bool isRecording() const;
    int recordingSeconds() const;
    QString recordingTimeFormatted() const;
    bool micEnabled() const;
    void setMicEnabled(bool enabled);
    int fps() const;
    void setFps(int value);
    QString screenName() const;
    void setScreenName(const QString &name);
    QString recordingsDir() const;
    void setRecordingsDir(const QString &dir);
    bool isAvailable() const;
    QString lastSavedFile() const;

    Q_INVOKABLE void startRecording(bool withMic = false);
    Q_INVOKABLE void stopRecording();
    Q_INVOKABLE void toggleRecording();

    Q_INVOKABLE void toggleMic();
    Q_INVOKABLE void openRecordingsFolder();

signals:
    void recordingStateChanged();
    void recordingSecondsChanged();
    void micEnabledChanged();
    void fpsChanged();
    void screenNameChanged();
    void recordingsDirChanged();
    void lastSavedFileChanged();
    void notificationRequested(const QString &title, const QString &message);

private slots:
    void onTick();
    void pollExternalState();
    void pollStoppingRecorder();

private:
    void ensureDirectories();
    QString stateDir() const;
    QString recordPidFilePath() const;
    QString recordOutputFilePath() const;
    qint64 readPidFromFile(const QString &path) const;
    bool ensureStateDir() const;
    QByteArray readStateFile(const QString &path) const;
    bool writeStateFile(const QString &path, const QByteArray &contents) const;
    void writeRecordingState(qint64 pid, const QString &outputFile) const;
    QString readRecordingOutput() const;
    void clearRecordingState() const;
    void adoptRunningRecorder();
    QString processName(qint64 pid) const;
    bool isProcessRunning(qint64 pid) const;
    bool isOwnRecorderRunning(qint64 pid) const;
    QString outputName() const;
    QString uniqueRecordingPath() const;
    void checkRecorderStarted(qint64 pid, const QString &screen);
    void finishStoppedRecording(bool forced);
    QString resolveAudioDevice(bool withMic) const;

    static ScreenRecorderController *s_instance;

    QString m_wfRecorderPath;

    bool m_isRecording = false;
    int m_recordingSeconds = 0;
    bool m_micEnabled = false;
    int m_fps = 60;
    QString m_screenName;
    QString m_recordingsDir;
    QString m_lastSavedFile;
    QString m_currentRecordingFile;

    qint64 m_recordPid = 0;

    QTimer m_tickTimer;
    QTimer m_pollTimer;

    // A recorder that was just started is checked once shortly afterwards (m_startCheckPid);
    // a stopped one is tracked until it exits so "Recording Saved" means the file is final.
    qint64 m_startCheckPid = 0;
    int m_startCheckAttempts = 0;
    static constexpr int MaxStartChecks = 10;
    qint64 m_stoppingPid = 0;
    int m_stopEscalation = 0;
    QString m_stoppingFile;
    QElapsedTimer m_stopElapsed;
    QTimer m_stopPollTimer;
};
