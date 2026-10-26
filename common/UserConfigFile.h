#pragma once

#include <QFileDevice>
#include <QJsonObject>

namespace UserConfigFile {

// userconfig.json may hold the TLP sudo password; it is then written readable by its owner only.
inline void restrictIfSecret(QFileDevice &file, const QJsonObject &object)
{
    if (!object.value(QLatin1String("tlpSudoPassword")).toString().isEmpty())
        file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

} // namespace UserConfigFile
