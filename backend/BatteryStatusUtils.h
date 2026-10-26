#pragma once

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QString>
#include <QStringList>
#include <QVariantList>

#include <unistd.h>

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

// Whether the current user may write a sysfs attribute (permissions, ACLs and read-only
// mounts all count), e.g. a battery's charge_control_end_threshold.
inline bool isWritableByUser(const QString &path)
{
    return !path.isEmpty() && ::access(QFile::encodeName(path).constData(), W_OK) == 0;
}

// Charge-limit presets for a battery's charge_control_end_threshold. Apple Silicon's macsmc
// battery only gets 80 and 100 (the values its firmware limit is known to handle); other
// batteries keep the usual presets.
inline QVariantList chargeLimitPresets(const QString &batteryPath)
{
    if (QFileInfo(batteryPath).fileName().startsWith(QStringLiteral("macsmc")))
        return QVariantList{80, 100};
    return QVariantList{80, 85, 90, 100};
}

// Profile names from `powerprofilesctl list`, in listed order; `active` receives the one
// marked with "*". Detail lines ("    PlatformDriver: ...") are skipped.
inline QStringList parsePowerProfilesList(const QString &text, QString *active = nullptr)
{
    static const QRegularExpression profileLine(QStringLiteral("^(\\*?)[ \\t]*([a-z][a-z-]*):[ \\t]*$"),
                                                QRegularExpression::MultilineOption);
    QStringList profiles;
    for (auto it = profileLine.globalMatch(text); it.hasNext();) {
        const QRegularExpressionMatch match = it.next();
        profiles.append(match.captured(2));
        if (active && !match.captured(1).isEmpty())
            *active = match.captured(2);
    }
    return profiles;
}

} // namespace BatteryStatusUtils
