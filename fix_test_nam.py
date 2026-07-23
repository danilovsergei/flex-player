import sys
import re

def fix_test_nam(path):
    with open(path, 'r') as f:
        content = f.read()

    new_includes = r"""#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QQmlNetworkAccessManagerFactory>

class MyNetworkAccessManagerFactory : public QQmlNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent) override
    {
        QNetworkAccessManager *nam = new QNetworkAccessManager(parent);
        QObject::connect(nam, &QNetworkAccessManager::sslErrors,
                         nam, [](QNetworkReply *reply, const QList<QSslError> &errors) {
            reply->ignoreSslErrors();
        });
        return nam;
    }
};

class MySetup : public QObject
{
    Q_OBJECT
public:
    MySetup() {}
public slots:
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        engine->setNetworkAccessManagerFactory(new MyNetworkAccessManagerFactory);
    }
};

#include "main_test.moc"

int main(int argc, char **argv) {"""

    # But wait, QUICK_TEST_MAIN_WITH_SETUP doesn't use standard main.
    # The current code uses quick_test_main. We can intercept the QQmlEngine by subclassing or just passing a setup object.
    # Ah, `QUICK_TEST_MAIN_WITH_SETUP(FlexPlayerTest, MySetup)` creates `int main` automatically.
    # If we already have a custom `int main`, we can just call `qmlRegisterType` and then we need to set the NetworkAccessManager.
    # Actually `quick_test_main` accepts a macro, or we can use `quick_test_main_with_setup`?
    pass

fix_test_nam('/home/geonix/Build/flex_player/tests/main_test.cpp')

