#include <QFile>
#include <QJSEngine>
#include <QJSValue>
#include <QtTest>

class NotificationTextTests : public QObject
{
    Q_OBJECT

private:
    QJSEngine m_engine;

    QString call(const QString &name, const QJSValueList &arguments)
    {
        const QJSValue result = m_engine.globalObject().property(name).call(arguments);
        if (result.isError())
            qWarning() << result.toString();
        return result.toString();
    }
    QString fromMarkup(const QString &markup) { return call(QStringLiteral("fromMarkup"), {markup, true}); }
    QString styled(const QString &text) { return call(QStringLiteral("toStyledText"), {text}); }

private slots:
    void initTestCase()
    {
        QFile source(QStringLiteral(NOTIFICATION_TEXT_SOURCE));
        QVERIFY2(source.open(QIODevice::ReadOnly | QIODevice::Text), qPrintable(source.errorString()));
        QString script = QString::fromUtf8(source.readAll());
        script.remove(QStringLiteral(".pragma library"));
        const QJSValue result = m_engine.evaluate(script, source.fileName());
        QVERIFY2(!result.isError(), qPrintable(result.toString()));
    }

    void entitiesAndQuotesAreDecodedThenEscapedForDisplay()
    {
        const QString plain = fromMarkup(QStringLiteral("Tom &amp; Jerry say &quot;hi&quot; &amp;lt;"));
        QCOMPARE(plain, QStringLiteral("Tom & Jerry say \"hi\" &lt;"));
        QCOMPARE(styled(plain), QStringLiteral("Tom &amp; Jerry say &quot;hi&quot; &amp;lt;"));
    }

    void onlyFormattingTagsAreRemoved()
    {
        QCOMPARE(fromMarkup(QStringLiteral("<b>bold</b> a < b > c, <name> and <i>x</i>")),
                 QStringLiteral("bold a < b > c, <name> and x"));
    }

    void bareUrlsLinkTheRealUrlWithoutTrailingPunctuation()
    {
        QCOMPARE(styled(QStringLiteral("see https://x.com/?a=1&b=2.")),
                 QStringLiteral("see <a href=\"https://x.com/?a=1&b=2\">https://x.com/?a=1&amp;b=2</a>."));
        QCOMPARE(styled(QStringLiteral("(https://x.com/a), 'https://y.org/b'!")),
                 QStringLiteral("(<a href=\"https://x.com/a\">https://x.com/a</a>), "
                                "'<a href=\"https://y.org/b\">https://y.org/b</a>'!"));
        QCOMPARE(styled(QStringLiteral("https://en.wikipedia.org/wiki/Foo_(bar)")),
                 QStringLiteral("<a href=\"https://en.wikipedia.org/wiki/Foo_(bar)\">"
                                "https://en.wikipedia.org/wiki/Foo_(bar)</a>"));
    }

    void anchorsFromMarkupKeepTheirHttpTarget()
    {
        const QString plain = fromMarkup(
            QStringLiteral("Open <a href=\"https://x.com/?a=1&amp;b=(2)\">the <b>page</b></a> now"));
        QCOMPARE(plain, QStringLiteral("Open [the page](https://x.com/?a=1&b=%282%29) now"));
        QCOMPARE(styled(plain), QStringLiteral("Open <a href=\"https://x.com/?a=1&b=%282%29\">the page</a> now"));
        QCOMPARE(call(QStringLiteral("oneLine"), {plain}), QStringLiteral("Open the page now"));
    }

    void nonWebTargetsAreNotLinked()
    {
        QCOMPARE(fromMarkup(QStringLiteral("<a href=\"javascript:alert(1)\">click</a> "
                                           "<a href='file:///etc/passwd'>file</a>")),
                 QStringLiteral("click file"));
        const QString result = styled(QStringLiteral("[x](javascript:alert(1)) file:///etc/passwd javascript:void(0)"));
        QVERIFY(!result.contains(QStringLiteral("<a")));
    }

    void lineBreaksAreKept()
    {
        const QString plain = fromMarkup(QStringLiteral("line 1<br>line 2\n  line 3<br/><br/><br/>end"));
        QCOMPARE(plain, QStringLiteral("line 1\nline 2\nline 3\n\nend"));
        QCOMPARE(styled(plain), QStringLiteral("line 1<br>line 2<br>line 3<br><br>end"));
        QCOMPARE(call(QStringLiteral("oneLine"), {plain}), QStringLiteral("line 1 line 2 line 3 end"));
        QCOMPARE(call(QStringLiteral("fromMarkup"), {QStringLiteral("a\nb"), false}), QStringLiteral("a b"));
    }
};

QTEST_GUILESS_MAIN(NotificationTextTests)
#include "notification_text_tests.moc"
