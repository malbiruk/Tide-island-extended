#include "BatteryStatusUtils.h"

#include <unistd.h>

#include <QtTest>

class BatteryStatusUtilsTests : public QObject
{
    Q_OBJECT

private slots:
    void reportsDischargingWhenAdapterIsOffline()
    {
        QCOMPARE(BatteryStatusUtils::fallbackStatusFromAcOnline(QStringLiteral("0")),
                 QStringLiteral("Discharging"));
    }

    void doesNotAssumeChargingWhenAdapterIsOnline()
    {
        QCOMPARE(BatteryStatusUtils::fallbackStatusFromAcOnline(QStringLiteral("1")),
                 QStringLiteral("Unknown"));
    }

    void preservesUnknownForInvalidInput()
    {
        QCOMPARE(BatteryStatusUtils::fallbackStatusFromAcOnline(QString()),
                 QStringLiteral("Unknown"));
        QCOMPARE(BatteryStatusUtils::fallbackStatusFromAcOnline(QStringLiteral("not-a-number")),
                 QStringLiteral("Unknown"));
    }

    void trimsSysfsWhitespace()
    {
        QCOMPARE(BatteryStatusUtils::fallbackStatusFromAcOnline(QStringLiteral(" 0\n")),
                 QStringLiteral("Discharging"));
    }

    void picksTheSystemBatteryByTypeAndSkipsPeripherals()
    {
        QTemporaryDir sysfs;
        QVERIFY(sysfs.isValid());
        QVERIFY(writeSupply(sysfs.path(), "hidpp_battery_0", {{"type", "Battery"}, {"scope", "Device"}}));
        QVERIFY(writeSupply(sysfs.path(), "macsmc-ac", {{"type", "Mains"}}));
        QVERIFY(writeSupply(sysfs.path(), "macsmc-battery", {{"type", "Battery"}, {"scope", "System"}}));

        QCOMPARE(BatteryStatusUtils::systemBatteryPath(sysfs.path()),
                 QDir(sysfs.path()).absoluteFilePath(QStringLiteral("macsmc-battery")));
    }

    void fallsBackToBatteryNamesWithoutPickingPeripherals()
    {
        QTemporaryDir sysfs;
        QVERIFY(sysfs.isValid());
        QVERIFY(writeSupply(sysfs.path(), "battery_mouse", {{"scope", "Device"}}));
        QVERIFY(writeSupply(sysfs.path(), "BAT0", {}));
        QCOMPARE(BatteryStatusUtils::systemBatteryPath(sysfs.path()),
                 QDir(sysfs.path()).absoluteFilePath(QStringLiteral("BAT0")));

        QTemporaryDir peripheralOnly;
        QVERIFY(peripheralOnly.isValid());
        QVERIFY(writeSupply(peripheralOnly.path(), "battery_mouse", {{"scope", "Device"}}));
        QCOMPARE(BatteryStatusUtils::systemBatteryPath(peripheralOnly.path()), QString());
    }

    void reportsWhetherTheThresholdIsWritable()
    {
        if (::geteuid() == 0)
            QSKIP("root can write read-only files");

        QTemporaryDir sysfs;
        QVERIFY(sysfs.isValid());
        QVERIFY(writeSupply(sysfs.path(), "macsmc-battery", {{"type", "Battery"}, {"charge_control_end_threshold", "80"}}));
        const QString threshold = sysfs.path() + QStringLiteral("/macsmc-battery/charge_control_end_threshold");

        QVERIFY(BatteryStatusUtils::isWritableByUser(threshold));
        QVERIFY(QFile::setPermissions(threshold, QFileDevice::ReadOwner | QFileDevice::ReadGroup | QFileDevice::ReadOther));
        QVERIFY(!BatteryStatusUtils::isWritableByUser(threshold));
        QVERIFY(!BatteryStatusUtils::isWritableByUser(QString()));
    }

    void offersOnlySupportedLimitsOnAppleSilicon()
    {
        QCOMPARE(BatteryStatusUtils::chargeLimitPresets(QStringLiteral("/sys/class/power_supply/macsmc-battery")),
                 (QVariantList{80, 100}));
        QCOMPARE(BatteryStatusUtils::chargeLimitPresets(QStringLiteral("/sys/class/power_supply/BAT0")),
                 (QVariantList{80, 85, 90, 100}));
    }

private:
    static bool writeSupply(const QString &root, const char *name, const QList<QPair<QByteArray, QByteArray>> &attributes)
    {
        const QString dir = root + QLatin1Char('/') + QLatin1String(name);
        if (!QDir().mkpath(dir))
            return false;
        for (const auto &attribute : attributes) {
            QFile file(dir + QLatin1Char('/') + QString::fromLatin1(attribute.first));
            if (!file.open(QIODevice::WriteOnly) || file.write(attribute.second + '\n') < 0)
                return false;
        }
        return true;
    }
};

QTEST_GUILESS_MAIN(BatteryStatusUtilsTests)
#include "battery_status_utils_tests.moc"
