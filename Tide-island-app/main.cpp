#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "backend.hpp"

int main(int argc, char *argv[]) {
    bool validateQml = false;
    for (int index = 1; index < argc; ++index) {
        const QString argument = QString::fromLocal8Bit(argv[index]);
        validateQml = validateQml || argument == QStringLiteral("--validate-qml");
    }

    QGuiApplication app(argc, argv);
    Backend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.loadFromModule(QStringLiteral("TideIsland"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty()) return -1;
    if (validateQml) return 0;
    return app.exec();
}
