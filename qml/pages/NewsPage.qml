import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Shapes 1.12
import QtGraphicalEffects 1.12
import Ubuntu.Components 1.3 as UUITK
import io.thp.pyotherside 1.3
import "../components"

UUITK.Page {
    property bool searchMode: false
    property bool submittedSearch: false
    property bool searching: false
    property int id: newsPage
    property variant lastMenuToggled: 0
    anchors.fill: parent
    header: UUITK.PageHeader {
        id: pageHeader
        title: 'Top Stories'
        z: 3
        contents: Item {
            anchors.fill: parent

            UUITK.TextField {
                visible: searchMode
                id: textField
                placeholderText: "Search"
                anchors.fill: parent
                Keys.onReturnPressed: search()
                anchors.topMargin: units.gu(1)
                anchors.bottomMargin: units.gu(1)
            }
            UUITK.Label {
                visible: !searchMode
                anchors.fill: parent
                verticalAlignment: Qt.AlignVCenter
                text: 'Top Stories'
            }
        }

        leadingActionBar.actions: [
            UUITK.Action {
                visible: !searchMode
                iconName: 'navigation-menu'

                onTriggered: {
                    let delta = (new Date()).getTime() - lastMenuToggled
                    if (delta < 250) {
                        return
                    }

                    menu.visible ? menu.close() : menu.open()
                }
            },

            UUITK.Action {
                visible: searchMode
                iconName: "close"
                onTriggered: {
                    searchMode = false
                    textField.text = ''
                    if (submittedSearch) {
                        loadStories()
                    }
                    submittedSearch = false
                }
            }
        ]

        trailingActionBar.actions: [
            UUITK.Action {
                iconName: "find"
                text: "Search"
                onTriggered: {
                    if (searchMode) {
                        search()
                    } else {
                        textField.forceActiveFocus()
                    }

                    searchMode = true
                }
            }
        ]
    }
    Menu {
        id: menu
        width: units.gu(20)
        y: header.height
        onVisibleChanged: {
            let now = (new Date()).getTime()
            lastMenuToggled = now
        }

        background: Rectangle {
            id: bgRectangle

            layer.enabled: true
            layer.effect: DropShadow {
                width: bgRectangle.width
                height: bgRectangle.height
                x: bgRectangle.x
                y: bgRectangle.y
                visible: bgRectangle.visible

                source: bgRectangle

                horizontalOffset: 0
                verticalOffset: 5
                radius: 10
                samples: 20
                color: "#999"
            }
        }

        MenuPanelItem {
            visible: root.settings.cookie === undefined
            iconName: "account"
            label: i18n.tr("Log in")
            onTriggered: {
                stack.push(loginpage)
            }
        }
        MenuPanelItem {
            enabled: false // root.settings.cookie
            iconName: "compose"
            label: i18n.tr("Submit")
            onTriggered: {

                // TODO
            }
        }
    }

    LVSpinner {
        id: spin
        listView: mylv
    }
    Item {
        anchors.fill: parent
        UUITK.ActivityIndicator {
            anchors.centerIn: parent
            running: true
            visible: searching
        }
    }

    ListView {
        visible: true
        id: mylv
        spacing: 1
        anchors.fill: parent
        cacheBuffer: height / 2
        boundsMovement: Flickable.StopAtBounds
        boundsBehavior: Flickable.DragOverBounds

        header: Text {
            id: refreshLabel
            text: "Drag to refresh"
            height: pageHeader.height
        }
        onVerticalOvershootChanged: {

            if (verticalOvershoot < -units.gu(10)) {
                headerItem.text = "Release to refresh"
            } else if (verticalOvershoot >= -units.gu(10)) {
                headerItem.text = "Drag to refresh"
            }
        }
        onDragEnded: {
            if (verticalOvershoot < spin.triggerY) {
                headerItem.text = "Drag to refresh"
                loadStories()
            }
        }

        model: ListModel {
            id: listModel
        }

        delegate: ThreadStub {
            t_id: story_id
            t_title: title
            t_url: url_domain
            t_comments: comment_count
            Component.onCompleted: {
                if (!initialized) {
                    initialized = true
                    python.call("example.fetch_and_signal", [story_id],
                                function () {})
                }
            }
            onUrlClicked: {
                if (url == 'self') {
                    threadClicked()
                } else {
                    Qt.openUrlExternally(url)
                }
            }
            onThreadClicked: {
                stack.push(threadview)
                threadview.loadThread(story_id, title, url)
                threadview.visible = true
            }
        }
    }

    function loadStories() {
        listModel.clear()
        python.call('example.top_stories', [], function (result) {
            for (var i = 0; i < result.length; i++) {
                listModel.append(result[i])
            }
        })
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../../src/'))
            importModule('example', function () {
                loadStories()
            })
            setHandler('comment-pop',
                       function () {}) // this is handled in ThreadView.qml
            setHandler('thread-pop', function (data) {
                const id = data.story_id
                for (var i = 0; i < listModel.count; i++) {
                    var item = listModel.get(i)
                    if (item.story_id !== id) {
                        continue
                    }

                    item.title = data.title
                    item.url_domain = data.url_domain
                    item.url = data.url
                    item.comment_count = data.comment_count
                    item.kids = data.kids
                    break
                }
            })
        }

        onError: {
            console.log('python error: ' + traceback)
        }
        onReceived: console.log('Main-Event' + data)
    }
    function search() {
        searching = true
        submittedSearch = true
        listModel.clear()
        python.call("example.search", [textField.text], function (result) {
            for (var i = 0; i < result.length; i++) {
                listModel.append(result[i])
            }
            searching = false
        })
    }
}
