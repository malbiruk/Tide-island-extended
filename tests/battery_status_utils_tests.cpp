#include "BatteryStatusUtils.h"

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
