this.anyf = (...args) => {
    addNode(args.toString());
};

this.callf = (x) => {
//    console.log(x);
//    console.log(x[1][1].c);

    addNode(x + " ");
};

this.unifyf = (x) => {
    console.log(x);

    addNode("unify " + x);
};

this.freshf = (x) => {
    addNode("fresh " + x);
};

this.endf = () => {
    end();
};


function runAppendo() {
    return jscode.runAppendo(null);
}

