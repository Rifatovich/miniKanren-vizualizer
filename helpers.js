//this.anyf = (...args) => {
//    addNode(args.toString());
//};

this.callf = (x) => {
//    console.log(x);
    console.log(x[1][1]); //.c
//    if (x.length !== 0){
//        Qt.rect.width = 1000;
//    }

    addNode(x + " ");
};

this.unifyf = (x) => {
    console.log(x);

    addNode("unify " + x);
};

this.freshf = (x) => {
    addNode("fresh " + x);
};

this.anyf = (...args) => {
    addNode(args.toString());
};

this.endf = () => {
    end();
};


function runAppendo() {
    return jscode.runAppendo(null);
}

