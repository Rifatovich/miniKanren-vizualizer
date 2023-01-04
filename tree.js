class Tree {
    constructor(canvas) {
        this.canvas = canvas;
        this.componentsBySteps = [];
        this.step = -1;
        this.lastNode = null;
    }

    addNode(title) {
        var newComponent = Qt.createComponent("node.qml").createObject(this.canvas);
        this.componentsBySteps.push(newComponent);
        this.step = this.componentsBySteps.length - 1;
        newComponent.title = title;

        if (this.lastNode) {
            newComponent.anchors.top = this.lastNode.component.bottom;
            if (this.lastNode.component.rightSide) {
                newComponent.anchors.left = this.lastNode.component.rightSide;
                //newComponent.anchors.top = this.lastNode.component.bottom;
                this.lastNode.component.rightSide = newComponent.right; //rightSide right
            }else {
                newComponent.anchors.horizontalCenter = this.lastNode.component.horizontalCenter;
                //newComponent.anchors.top = this.lastNode.component.bottom;
                //newComponent.anchors.rightSide = this.lastNode.component.leftSide;
                //newComponent.anchors.top = this.lastNode.component.bottom;
                this.lastNode.component.rightSide = newComponent.right;
            }
            this.lastNode = {
                "parent": this.lastNode,
                "component": newComponent,
            }
        } else {
            this.lastNode = {
                "parent": null,
                "component": newComponent,
            }
        };
    }

    end() {
        this.lastNode = this.lastNode.parent;
    }

    nextStep() {
      //if (tree) {
        if (this.step < this.componentsBySteps.length - 1)
            this.step += 1;
        this.componentsBySteps[this.step].visible = true;
//        } else {
//             tree = new T.Tree(canvas);
//             console.log(Helpers.runAppendo());
//             this.step = -1;
//         }
    }

    prevStep() {
            if (this.step >= 0) {
            this.componentsBySteps[this.step].visible = false;
            if (this.step >= 0)
                this.step -= 1;
        }
    }

   destroyNodes() {
        for (var i = 0; i < this.componentsBySteps.length; i++) {
            this.componentsBySteps[i].visible = false;
        }
        this.step = -1;
    }

    viewNodes() {
        for (var i = 0; i < this.componentsBySteps.length; i++) {
            this.componentsBySteps[i].visible = true;
        }
        this.step = this.componentsBySteps.length - 1;
    }
}
