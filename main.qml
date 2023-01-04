import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12

import "helpers.js" as Helpers
import "unicanren/_build/default/bin/main.bc.js" as MiniKanren
import "tree.js" as T

Window {
    id: root
    title: "miniKanren-vizualizer"
    width: 1280
    height: 720
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
        text: "result"
        onClicked: {
            if (tree)
                tree.viewNodes();
            else {
            tree = new T.Tree(canvas);
            console.log(Helpers.runAppendo());
            }
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

    Button {
        id: clearButton
        text: "clear"
        anchors.top: nextButton.bottom
        onClicked: {
            tree.destroyNodes();
        }
    }

    ScrollView {
//        ScrollBar.horizontal: ScrollBar {
//                  policy: ScrollBar.AlwaysOn
//                  size: 1.0
//                  pressed: true
//              }
        Flickable {
             contentWidth: 5000
             ScrollBar.horizontal: ScrollBar { }
         }

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
            //anchors {horizontalCenter: parent.horizontalCenter}
            height: 4000
            color: "silver"
        }
    }

}
