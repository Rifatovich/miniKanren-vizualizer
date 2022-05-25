import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12

import "miniKanren.js" as MiniKanren
import "tree.js" as T

Window {
    id: root
    title: "miniKanren-vizualizer"
    width: 1280
    height: 820
    visible: true

    property var tree: null

    function addNode(title) {
         tree.addNode(title);
    }

    function end() {
        tree.end();
    }

    Button {
        id: testButton
        text: "appendo"
        onClicked: {
            if (tree)
                tree.destroyNodes();
            tree = new T.Tree(canvas);
            console.log(MiniKanren.runAppendo());
        }
    }

    Button {
        id: prevButton
        text: "prev step"
        anchors.top: testButton.bottom
        onClicked: {
            tree.prevStep();
        }
    }

    Button {
        id: nextButton
        text: "next step"
        anchors.top: prevButton.bottom
        onClicked: {
            tree.nextStep();
        }
    }

    ScrollView {
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOn
        ScrollBar.vertical.policy: ScrollBar.AlwaysOn
        anchors.left: testButton.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true
        contentHeight: canvas.height

        Rectangle {
            id: canvas
            width: parent.width
            height: 4000
            color: "#ffdc7a"
        }
    }
}
