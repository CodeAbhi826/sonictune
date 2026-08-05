// router/Router.qml — centralized navigation singleton.
// Pages push themselves onto the shared StackView instead of reaching
// into page-specific state. Registered via router/qmldir so it is
// importable from anywhere as a true singleton.

pragma Singleton
import QtQuick

QtObject {
    id: router

    property var stackView: null

    function pushPage(pageUrl, properties) {
        if (stackView) {
            stackView.push(pageUrl, properties || {})
        }
    }

    function popPage() {
        if (stackView && stackView.depth > 1) {
            stackView.pop()
        }
    }

    function popToRoot() {
        if (stackView) {
            stackView.pop(null, stackView.Immediate)
        }
    }
}
