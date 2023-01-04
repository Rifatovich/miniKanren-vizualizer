import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Rectangle {
    id: rect
    property string title: ""
    property var rightSide: null
    Label {
        text: title
    }
    color: "lightgray"  //"transparent"
    implicitWidth: 250  /*(Label.text.length)*100*/
    height: 50
    //anchors.fill: parent
    //anchors.margins: defMargin
    //anchors {horizontalCenter: parent.horizontalCenter}

//    State {
//        name: "deleteAnchors"
//        AnchorChanges {
//            target: rect
//            anchors.horizontalCenter: undefined
//        }
//    }
}
