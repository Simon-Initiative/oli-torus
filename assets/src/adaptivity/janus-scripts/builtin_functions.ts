export const janus_std = `
    let abs = fn(value) { return number(Math.evaluate("abs(" + string(value) + ")")); };
    let cos = fn(value) { return number(Math.evaluate("cos(" + string(value) + ")")); };
    let acos = fn(value) { return number(Math.evaluate("acos(" + string(value) + ")")); };
    let sin = fn(value) { return number(Math.evaluate("sin(" + string(value) + ")")); };
    let asin = fn(value) { return number(Math.evaluate("asin(" + string(value) + ")")); };
    let atan = fn(value) { return number(Math.evaluate("atan(" + string(value) + ")")); };
    let tan = fn(value) { return number(Math.evaluate("tan(" + string(value) + ")")); };
    let atan2 = fn(value) { return number(Math.evaluate("atan2(" + string(value) + ")")); };
    let ceil = fn(value) { return number(Math.evaluate("ceil(" + string(value) + ")")); };
    let floor = fn(value) { return number(Math.evaluate("floor(" + string(value) + ")")); };
    let exp = fn(value) { return number(Math.evaluate("exp(" + string(value) + ")")); };
    let log = fn(value) { return number(Math.evaluate("log(" + string(value) + ")")); };
    let pow = fn(x, y) { return number(Math.evaluate("pow(" + string(x) + ", " + string(y) + ")")); };
    let sqrt = fn(value) { return number(Math.evaluate("sqrt(" + string(value) + ")")); };
    let round = fn(value) { return number(Math.evaluate("round(" + string(value) + ")")); };
    let roundSF = fn(value, precision) { return number(Math.evaluate("round(" + string(value) + ", " + string(precision) + ")")); };
    let det = fn(matrix) { return number(Math.evaluate("det(" + string(matrix) + ").toString()")); };
    let inv = fn(matrix) {
        if (typeof(matrix) == "ARRAY") {
            return array(Math.evaluate("inv(" + string(matrix) + ")"));
        }
        if (typeof(matrix) == "NUMBER") {
            return number(Math.evaluate("inv(" + string(matrix) + ")"));
        }
    };
    let ele = fn(matrix, position) {
        if (typeof(matrix) != "ARRAY") {
            return undefined;
        }
        if (typeof(matrix[0]) == "ARRAY") {
            if (typeof(position) == "NUMBER") {
                return matrix[0][position - 1];
            } else {
                if (len(position) == 1) {
                    return matrix[0][position[0] - 1];
                }
                if (len(position) == 2) {
                    return matrix[position[0] - 1][position[1] - 1];
                }
                if (len(position) > 2) {
                    return matrix[position[0] - 1][position[1] - 1][position[2] - 1];
                }
            }
        } else {
            "this means matrix is a vector";
            if (typeof(position) == "NUMBER") {
                return matrix[position - 1];
            } else {
                return matrix[position[0] - 1];
            }
        }
    };
    if ({session.userId} != undefined) {
        let session.seed = {sesson.userId} * 1234567;
    } else {
        let session.seed = string(session.userName) + string(1234567);
    }
    let rand = rng(session.seed);
    let rndm = fn(min, max, step) {
        if (step == undefined) {
            let step = 1;
        }
        return Math.round((rand() * (max - min) / step)) * step + min;
    };
    let fixedrndm = fn(min, max, step) {
        return rndm(min, max, step);
    };
    let fixedrandom = fn(min, max, step) {
        return rndm(min, max, step);
    };
    let lessonattemptrandom = fn(min, max, step) {
        return rndm(min, max, step);
    };
    let lessonattemptrndm = fn(min, max, step) {
        return lessonattemptrandom(min, max, step);
    };
    let eigenvalues = fn(matrix) {
        return array(Math.evaluate("eigs(" + string(matrix) + ").values"));
    };
    let diag = fn(vector) {
        return array(Math.evaluate("diag(" + string(vector) + ")"));
    };
    let getDiag = fn(matrix) {
        return array(Math.evaluate("diag(" + string(matrix) + ")"));
    };
    let trans = fn(matrix) {
        return array(Math.evaluate("transpose(" + string(matrix) + ")"));
    };
`;
