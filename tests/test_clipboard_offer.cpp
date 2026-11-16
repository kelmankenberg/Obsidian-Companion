#include <QClipboard>
#include <QGuiApplication>
#include <QMimeData>
#include <QQmlComponent>
#include <QQmlEngine>
#include <memory>

class ClipboardOffer : public QMimeData {
public:
    explicit ClipboardOffer(int &reads) : reads(reads) {}
    QStringList formats() const override { return {QStringLiteral("text/plain")}; }

protected:
    QVariant retrieveData(const QString &, QMetaType) const override {
        ++reads;
        return QStringLiteral("Offered text");
    }

private:
    int &reads;
};

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    if (argc != 2)
        return 2;
    QQmlEngine engine;
    int reads = 0;
    QQmlComponent native(&engine);
    native.setData("import QtQuick; TextInput {}", QUrl());
    {
        std::unique_ptr<QObject> input(native.create());
        if (!input)
            return 3;
        app.clipboard()->setMimeData(new ClipboardOffer(reads));
        if (!reads)
            return 4;
    }
    QQmlComponent safe(&engine, QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    std::unique_ptr<QObject> input(safe.create());
    if (!input) {
        qCritical() << safe.errors();
        return 5;
    }
    reads = 0;
    app.clipboard()->setMimeData(new ClipboardOffer(reads));
    app.processEvents();
    if (reads)
        return 6;
    // Drop the offer while its read counter is still alive.
    app.clipboard()->clear();
    return 0;
}
