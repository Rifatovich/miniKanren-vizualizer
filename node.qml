import QtQuick 2.12
import QtQuick.Controls 2.12

Rectangle {
    property string title: ""
    property var rightSide: null

    color: "lightgray"
    width: 120
    height: 60

    Label {
        text: title
    }
}
