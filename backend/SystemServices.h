#pragma once

#include <QObject>
#include <QByteArray>
#include <QPointer>
#include <QProcess>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariant>
#include <QVariantList>
#include <QtQml/qqml.h>

#include <functional>

class SystemServices final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool screenRecordingActive READ screenRecordingActive NOTIFY screenRecordingActiveChanged FINAL)
    Q_PROPERTY(bool micActive READ micActive NOTIFY privacyIndicatorsChanged FINAL)
    Q_PROPERTY(bool cameraActive READ cameraActive NOTIFY privacyIndicatorsChanged FINAL)
    Q_PROPERTY(bool privacyActive READ privacyActive NOTIFY privacyIndicatorsChanged FINAL)
    Q_PROPERTY(QVariantList activePrivacyApps READ activePrivacyApps NOTIFY privacyIndicatorsChanged FINAL)
    Q_PROPERTY(QVariantList cavaLevels READ cavaLevels NOTIFY cavaLevelsChanged FINAL)
    Q_PROPERTY(QVariantList audioOutputs READ audioOutputs NOTIFY audioOutputsChanged FINAL)
    Q_PROPERTY(QVariantList audioInputs READ audioInputs NOTIFY audioInputsChanged FINAL)
    Q_PROPERTY(QVariantList appStreams READ appStreams NOTIFY appStreamsChanged FINAL)
    Q_PROPERTY(QString defaultAudioSink READ defaultAudioSink NOTIFY defaultAudioSinkChanged FINAL)
    Q_PROPERTY(QString defaultAudioSource READ defaultAudioSource NOTIFY defaultAudioSourceChanged FINAL)
    Q_PROPERTY(bool batteryThresholdSupported READ batteryThresholdSupported NOTIFY batteryThresholdChanged FINAL)
    Q_PROPERTY(QString batteryThresholdType READ batteryThresholdType NOTIFY batteryThresholdChanged FINAL)
    Q_PROPERTY(bool batteryConservationMode READ batteryConservationMode NOTIFY batteryThresholdChanged FINAL)
    Q_PROPERTY(int batteryThresholdValue READ batteryThresholdValue NOTIFY batteryThresholdChanged FINAL)
    Q_PROPERTY(QVariantList batteryThresholdPresets READ batteryThresholdPresets NOTIFY batteryThresholdChanged FINAL)
    Q_PROPERTY(bool batteryThresholdWritable READ batteryThresholdWritable NOTIFY batteryThresholdChanged FINAL)
    Q_PROPERTY(bool batteryThresholdBusy READ batteryThresholdBusy NOTIFY batteryThresholdBusyChanged FINAL)
    Q_PROPERTY(QString batteryThresholdError READ batteryThresholdError NOTIFY batteryThresholdChanged FINAL)
    Q_PROPERTY(int batteryCycleCount READ batteryCycleCount NOTIFY batteryHealthMetricsChanged FINAL)
    Q_PROPERTY(int batteryHealthPercent READ batteryHealthPercent NOTIFY batteryHealthMetricsChanged FINAL)
    Q_PROPERTY(QString batteryChargeState READ batteryChargeState NOTIFY batteryHealthMetricsChanged FINAL)
    // Profiles the resolved power driver offers (power-saver / balanced / performance); empty
    // when there is no driver or it has not been queried yet.
    Q_PROPERTY(QStringList powerProfiles READ powerProfiles NOTIFY powerProfilesChanged FINAL)

public:
    explicit SystemServices(QObject *parent = nullptr);
    ~SystemServices() override;

    static SystemServices *instance();

    bool screenRecordingActive() const;
    bool micActive() const { return m_micActive; }
    bool cameraActive() const { return m_cameraActive; }
    bool privacyActive() const { return m_micActive || m_cameraActive; }
    QVariantList activePrivacyApps() const { return m_activePrivacyApps; }
    QVariantList cavaLevels() const;
    QVariantList audioOutputs() const { return m_audioOutputs; }
    QVariantList audioInputs() const { return m_audioInputs; }
    QVariantList appStreams() const { return m_appStreams; }
    QString defaultAudioSink() const { return m_defaultAudioSink; }
    QString defaultAudioSource() const { return m_defaultAudioSource; }
    bool batteryThresholdSupported() const { return m_batteryThresholdSupported; }
    QString batteryThresholdType() const { return m_batteryThresholdType; }
    bool batteryConservationMode() const { return m_batteryConservationMode; }
    int batteryThresholdValue() const { return m_batteryThresholdValue; }
    QVariantList batteryThresholdPresets() const { return m_batteryThresholdPresets; }
    bool batteryThresholdWritable() const { return m_batteryThresholdWritable; }
    bool batteryThresholdBusy() const { return m_batteryThresholdBusy; }
    QString batteryThresholdError() const { return m_batteryThresholdError; }
    int batteryCycleCount() const { return m_batteryCycleCount; }
    int batteryHealthPercent() const { return m_batteryHealthPercent; }
    QString batteryChargeState() const { return m_batteryChargeState; }
    QStringList powerProfiles() const { return m_powerProfiles; }
    void updateScreenRecordingActive();

    Q_INVOKABLE void requestScreenRecordingSnapshot();
    Q_INVOKABLE void requestPrivacySnapshot();
    Q_INVOKABLE void requestBrightness();
    Q_INVOKABLE void setBrightness(double value);
    Q_INVOKABLE void requestVolume();
    Q_INVOKABLE void setVolume(double value);
    Q_INVOKABLE void toggleVolumeMute();
    Q_INVOKABLE void requestMicVolume();
    Q_INVOKABLE void setMicVolume(double value);
    Q_INVOKABLE void toggleMicMute();
    Q_INVOKABLE void requestAudioOutputs();
    Q_INVOKABLE void requestAudioInputs();
    Q_INVOKABLE void requestAppStreams();
    Q_INVOKABLE void setAudioOutput(const QString &sinkName, const QString &portName = QString());
    Q_INVOKABLE void setAudioInput(const QString &sourceName, const QString &portName = QString());
    Q_INVOKABLE void setAppStreamVolume(int streamIndex, double volume);
    Q_INVOKABLE void toggleAppStreamMute(int streamIndex);
    Q_INVOKABLE void setAudioMonitoringActive(bool active);
    void refreshAudioIfActive();
    Q_INVOKABLE void requestTlpState();
    Q_INVOKABLE void setTlpMode(const QString &mode,
                                const QString &sudoPassword = QString(),
                                bool promptForPassword = false);
    Q_INVOKABLE void cancelTlpApply();
    Q_INVOKABLE void requestPowerProfileState(const QString &driver = QString());
    Q_INVOKABLE void setPowerProfileMode(const QString &driver,
                                        const QString &mode,
                                        const QString &sudoPassword = QString(),
                                        bool promptForPassword = false);
    Q_INVOKABLE void cancelPowerProfileApply();
    Q_INVOKABLE void setCavaClientActive(const QString &clientId, bool active);
    Q_INVOKABLE void ensureUserConfigAvailable();
    Q_INVOKABLE void logNotificationDaemonOwner() const;
    Q_INVOKABLE void copyToClipboard(const QString &text);
    Q_INVOKABLE void requestBatteryThresholdState();
    Q_INVOKABLE void setBatteryConservationMode(bool enabled);
    Q_INVOKABLE void setBatteryThreshold(int threshold);
    // User-facing programs run in their own systemd scope (common/ScopedLaunch.h).
    Q_INVOKABLE QStringList scopedCommand(const QStringList &argv) const;
    Q_INVOKABLE bool launchDetached(const QStringList &argv) const;
    // An existing regular file (symlinks followed), given as a path or file:// URL. Notification
    // images must not point the image loader at FIFOs, devices or directories.
    Q_INVOKABLE bool isRegularFile(const QString &pathOrUrl) const;

signals:
    void screenRecordingActiveChanged();
    void privacyIndicatorsChanged();
    void brightnessSnapshotReady(double value, const QString &errorString);
    void brightnessSetFinished(double value, bool success, const QString &errorString);
    void volumeSnapshotReady(double value, bool muted, const QString &errorString);
    void volumeSetFinished(double value, bool success, const QString &errorString);
    void micVolumeSnapshotReady(double value, bool muted, const QString &errorString);
    void micVolumeSetFinished(double value, bool success, const QString &errorString);
    void tlpStateReady(bool available, const QString &profile, const QString &output, const QString &errorString);
    void tlpSetFinished(bool success, int exitCode, const QString &output, const QString &errorString);
    void batteryThresholdChanged();
    void batteryThresholdBusyChanged();
    void batteryHealthMetricsChanged();
    void powerProfilesChanged();
    void batteryThresholdFinished(bool success, const QString &errorString);
    void cavaLevelsChanged();
    void audioOutputsChanged();
    void audioInputsChanged();
    void appStreamsChanged();
    void defaultAudioSinkChanged();
    void defaultAudioSourceChanged();

private:
    struct CommandResult {
        int exitCode = -1;
        QProcess::ExitStatus exitStatus = QProcess::NormalExit;
        QByteArray stdoutData;
        QByteArray stderrData;
        QString errorString;
        bool timedOut = false;
    };

    using CommandCallback = std::function<void(const CommandResult &)>;

    QProcess *startCommand(const QString &program,
                           const QStringList &arguments,
                           int timeoutMs,
                           CommandCallback callback,
                           const QByteArray &stdinData = QByteArray());
    QString findExecutable(const QString &program) const;
    QString commandErrorText(const QString &program, const CommandResult &result) const;
    QString resolvePowerProfileDriver(const QString &requestedDriver) const;

    void detectBatteryThresholdSupport();
    void updateBatteryMetrics();
    void applyBatteryThresholdValue(const QString &targetValue);

    void startBusMonitor();
    void startPipeWireMonitor();
    void stopProcess(QProcess *&process);
    void setPortalPipeWireActive(bool active);

    void handleBusMonitorOutput();
    void handlePipeWireOutput();
    void processLines(QByteArray &buffer, const QByteArray &chunk, const std::function<void(const QString &)> &handler);
    void handleBusMonitorLine(const QString &line);
    void handlePipeWireLine(const QString &line);
    void handleRecordingPortalLine(const QString &line);
    void applyPipeWireSnapshot(const QString &text);
    Q_INVOKABLE void handlePrivacySnapshotOutput(const QString &output);

    QString extractHeaderPath(const QString &line) const;
    QString extractObjectPath(const QString &line) const;
    bool screenCastMemberHasSessionArgument(const QString &memberName) const;
    bool pipeWireBlockLooksLikeScreenCast(const QString &blockText) const;

    double parseBrightnessOutput(const QString &text, bool *ok) const;
    void parseVolumeOutput(const QString &text, double *value, bool *muted, bool *ok) const;
    QString parseTlpProfile(const QString &text) const;

    void applyPendingBrightness();
    void applyPendingVolume();
    void applyPendingMicVolume();
    void applyPendingAppStreamVolume(int streamIndex);

    void startCava();
    void stopCava();
    void handleCavaOutput();
    void handleCavaLine(const QString &line);

    bool m_shuttingDown = false;

    QProcess *m_busMonitor = nullptr;
    QProcess *m_pipeWireMonitor = nullptr;
    QProcess *m_recordingSnapshot = nullptr;
    QProcess *m_tlpSetter = nullptr;
    QProcess *m_cavaProcess = nullptr;

    QTimer m_busMonitorRestartTimer;
    QTimer m_pipeWireRestartTimer;
    QTimer m_recordingSnapshotDebounceTimer;
    QTimer m_privacyPollTimer;
    QTimer m_cavaRestartTimer;

    QByteArray m_busMonitorBuffer;
    QByteArray m_pipeWireBuffer;
    QByteArray m_cavaBuffer;

    bool m_screenRecordingActive = false;
    bool m_portalPipeWireActive = false;
    bool m_micActive = false;
    bool m_cameraActive = false;
    QVariantList m_activePrivacyApps;
    QSet<QString> m_activeScreenCastSessions;
    QString m_pendingScreenCastMember;
    QString m_pendingSessionCandidate;



    QVariantList m_cavaLevels;
    QSet<QString> m_cavaClients;
    bool m_cavaMissingWarned = false;
    int m_tlpCommandGeneration = 0;
    bool m_configAppLaunchRequested = false;

    bool m_brightnessRequestActive = false;
    bool m_brightnessSettingActive = false;
    double m_pendingBrightness = -1.0;
    double m_lastAppliedBrightness = -1.0;
    QTimer m_brightnessThrottleTimer;

    bool m_volumeRequestActive = false;
    bool m_volumeSettingActive = false;
    double m_pendingVolume = -1.0;
    double m_lastAppliedVolume = -1.0;
    QTimer m_volumeThrottleTimer;

    bool m_micVolumeRequestActive = false;
    bool m_micVolumeSettingActive = false;
    double m_pendingMicVolume = -1.0;
    double m_lastAppliedMicVolume = -1.0;
    QTimer m_micVolumeThrottleTimer;

    QVariantList m_audioOutputs;
    QVariantList m_audioInputs;
    QVariantList m_appStreams;
    QString m_defaultAudioSink;
    QString m_defaultAudioSource;
    bool m_audioOutputsRequestActive = false;
    bool m_audioInputsRequestActive = false;
    bool m_appStreamsRequestActive = false;
    bool m_audioMonitoringActive = false;
    QHash<int, int> m_pendingAppStreamVolumePercents;
    QSet<int> m_activeAppStreamVolumeCommands;

    bool m_batteryThresholdSupported = false;
    QString m_batteryThresholdType;
    QString m_batteryThresholdSysfsPath;
    bool m_batteryConservationMode = false;
    int m_batteryThresholdValue = 100;
    QVariantList m_batteryThresholdPresets;
    bool m_batteryThresholdWritable = false;
    bool m_batteryThresholdBusy = false;
    QString m_batteryThresholdError;
    int m_batteryCycleCount = 0;
    int m_batteryHealthPercent = 100;
    QString m_batteryChargeState;
    QStringList m_powerProfiles;

    void setPowerProfiles(const QStringList &profiles);
};
