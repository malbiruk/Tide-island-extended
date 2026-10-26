#pragma once

#include <QFile>
#include <QFileDevice>
#include <QJsonObject>

namespace UserConfigFile {

// userconfig.json may hold the TLP sudo password; it is then written readable by its owner only.
inline void restrictIfSecret(QFileDevice &file, const QJsonObject &object)
{
    if (!object.value(QLatin1String("tlpSudoPassword")).toString().isEmpty())
        file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

// A file holding the password that others can read is made owner-only when it is loaded.
inline void tightenIfSecret(const QString &path, const QJsonObject &object)
{
    if (object.value(QLatin1String("tlpSudoPassword")).toString().isEmpty())
        return;
    const QFileDevice::Permissions shared = QFileDevice::ReadGroup | QFileDevice::WriteGroup | QFileDevice::ExeGroup
        | QFileDevice::ReadOther | QFileDevice::WriteOther | QFileDevice::ExeOther;
    if (QFile::permissions(path) & shared)
        QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

} // namespace UserConfigFile
