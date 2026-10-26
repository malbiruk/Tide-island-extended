#pragma once

#include <QDir>
#include <QFile>
#include <QString>

namespace BatteryStatusUtils {

// AC-online state tells us whether external power is connected, not whether the
// battery is actively charging. Only infer discharging when AC is explicitly
// offline; otherwise leave the status unknown until a battery-specific source
// (sysfs or UPower) can report it.
inline QString fallbackStatusFromAcOnline(const QString &onlineValue)
{
    bool ok = false;
    const int isOnline = onlineValue.trimmed().toInt(&ok);
    if (!ok || isOnline != 0)
        return QStringLiteral("Unknown");

    return QStringLiteral("Discharging");
}

// The system battery under /sys/class/power_supply: the first supply whose type is
// "Battery" (e.g. Apple Silicon's "macsmc-battery"), falling back to BAT*/battery* names.
// Supplies with scope "Device" (a Bluetooth mouse, a keyboard) are never chosen.
// Returns the absolute path, or an empty string when there is no system battery.
inline QString systemBatteryPath(const QString &powerSupplyDir = QStringLiteral("/sys/class/power_supply"))
{
    const QDir dir(powerSupplyDir);
    const auto attribute = [&dir](const QString &supply, const QString &name) {
        QFile file(dir.absoluteFilePath(supply + QLatin1Char('/') + name));
        return file.open(QIODevice::ReadOnly | QIODevice::Text)
            ? QString::fromUtf8(file.readAll()).trimmed()
            : QString();
    };
    const auto isPeripheral = [&attribute](const QString &supply) {
        return attribute(supply, QStringLiteral("scope")) == QStringLiteral("Device");
    };

    const QStringList supplies = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString &supply : supplies) {
        if (attribute(supply, QStringLiteral("type")) == QStringLiteral("Battery") && !isPeripheral(supply))
            return dir.absoluteFilePath(supply);
    }

    const QStringList named = dir.entryList({QStringLiteral("BAT*"), QStringLiteral("battery*")},
                                            QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString &supply : named) {
        if (!isPeripheral(supply))
            return dir.absoluteFilePath(supply);
    }
    return QString();
}

} // namespace BatteryStatusUtils
