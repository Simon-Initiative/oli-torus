export class Evaluator {
    static printOne(something, ctx) {
        // special case for rendering result image
        if (something instanceof SimpleImageImpl) {
            const canvas = ctx.getResult(ctx.solutionRun);
            if (canvas) {
                something.drawTo(canvas);
            }
            return;
        }
        let toPrint = something;
        // If there's a .getString() function, use it (Row SimplePixel Histogram)
        // This spares us from depending on instanceof/classname.
        if (something.getString) {
            toPrint = something.getString();
        }
        // hack: make array look like string
        if (something instanceof Array) {
            toPrint = '[' + something.join(', ') + ']';
        }
        ctx.appendOutput(toPrint);
    }
    static myprint(ctx, ...args) {
        for (let i = 0; i < args.length; i += 1) {
            // add space between arguments
            if (i > 0) {
                this.printOne(' ', ctx);
            }
            this.printOne(args[i], ctx);
        }
        const lastArg = args[args.length - 1];
        const hasBreak = lastArg instanceof SimpleImageImpl;
        if (!hasBreak) {
            this.printOne('\n', ctx);
        }
    }
    // -- special for-loop syntax --//
    // Given code, return sugared up code, or may throw error.
    // expands: for (part: composite) {
    static sugarCode(code) {
        const reWeak = /for *\([ \w+().-]*:[ \w+().-]*\) *\{/g;
        // important: the g is required to avoid infinite loop
        // weak: for ( stuff* : stuff*) {
        // weak not allowing newline etc., or the * goes too far
        const reStrong = /for\s*\(\s*(?:var\s+)?(\w+)\s*:\s*(\w+(\(.*?\))?)\s*\)\s*\{/;
        // strong: for([var ]x : y|foo(.*?) ) {
        // Find all occurences of weak, check that each is also strong.
        // e.g. "for (x: 1 +1) {" should throw this error
        let result;
        while ((result = reWeak.exec(code)) !== null) {
            // have result[0] result.index, reWeak.lastIndex
            const matched = result[0];
            // alert(matched);
            if (matched.search(reStrong) === -1) {
                throw new Error("Attempt to use 'for(part: composite)' form, but it looks wrong: " + result[0]);
            }
        }
        // Loop, finding the next
        let newCode = code;
        let gensym = 0;
        // eslint-disable-next-line
        while (1) {
            const oldCode = newCode;
            const pvar = 'pxyz' + gensym;
            const ivar = 'ixyz' + gensym;
            gensym += 1;
            const replacement = 'var ' +
                pvar +
                ' = Evaluator.getArray($2); ' +
                'for (var ' +
                ivar +
                '=0; ' +
                ivar +
                '<' +
                pvar +
                '.length; ' +
                ivar +
                '++) {' +
                'var $1 = ' +
                pvar +
                '[' +
                ivar +
                '];';
            newCode = newCode.replace(reStrong, replacement);
            if (newCode === oldCode) {
                break;
            }
        }
        return newCode;
        // return code.replace(reStrong, replacement);
        // someday: could look for reWeak, compare to where reStrong applied,
        // see if there is a case where they are trying but failing to use the for(part) form.
        // Or an easy to implement form would be to look for "for (a b c)" or whatever
        // where the lexemes look wrong, and flag it before the sugaring even happens.
        // var reWeak = /for\s*\((.*?)\)\s*\{/;
        // while ((result = reWeak.exec(code)) !== null) {
        // have result[0] result.index, reWeak.lastIndex
    }
    // Wrapper called on the composite by the for(part: composite) sugar, and it does
    // some basic error checking.
    static getArray(obj) {
        if (obj && typeof obj === 'object') {
            if (obj instanceof Array) {
                return obj;
            }
            if ('toArray' in obj) {
                return obj.toArray();
            }
        }
        else {
            throw new Error("'for (part: composite)' used, but composite is wrong.");
        }
    }
    // Called from user-facing functions, checks number of arguments.
    static funCheck(funName, expectedLen, actualLen) {
        if (expectedLen !== actualLen) {
            const s1 = actualLen === 1 ? '' : 's'; // pluralize correctly
            const s2 = expectedLen === 1 ? '' : 's';
            const message = funName +
                '() called with ' +
                actualLen +
                ' value' +
                s1 +
                ', but expected ' +
                expectedLen +
                ' value' +
                s2 +
                '.';
            // someday: think about "values" vs. "arguments" here
            throw new Error(message);
        }
    }
    static execute(src, ctx) {
        // set up environment for calls by user code
        const print = (...args) => {
            Evaluator.myprint(ctx, ...args);
        };
        class SimpleImage extends SimpleImageImpl {
            constructor(name) {
                super(name, ctx);
            }
        }
        class SimpleTable extends SimpleTableImpl {
            constructor(name) {
                super(name, ctx);
            }
        }
        // install these into global scope for access by user code
        window.SimpleImage = SimpleImage;
        window.SimpleTable = SimpleTable;
        window.print = print;
        window.Evaluator = Evaluator;
        try {
            const code = Evaluator.sugarCode(src);
            // Use Function to execute in global scope. Note user vars persist.
            Function(code)();
        }
        catch (e) {
            e.userError = true;
            return e;
        }
        return null;
    }
}
// Computes and returns the image diff, or 999 for error.
// todo: structure error cases better.
Evaluator.getResultDiff = function (ctx) {
    const studentCanvas = ctx.getResult(false);
    if (!studentCanvas)
        throw new Error('Failed to get student result image');
    // width = 0 => student run failed or they didn't run at all. Can't getImageData
    // this is possible, not a system error.
    if (studentCanvas.width === 0) {
        return 999;
    }
    const solnCanvas = ctx.getResult(true);
    if (!solnCanvas || solnCanvas.width === 0) {
        throw new Error('Failed to get solution image');
    }
    let studentData = new Uint8ClampedArray();
    let context = studentCanvas.getContext('2d');
    if (context) {
        studentData = context.getImageData(0, 0, studentCanvas.width, studentCanvas.height).data;
    }
    let solnData = new Uint8ClampedArray();
    context = solnCanvas.getContext('2d');
    if (context) {
        solnData = context.getImageData(0, 0, solnCanvas.width, solnCanvas.height).data;
    }
    let diff = 999; // default if imageDiff throws size mismatch error
    try {
        diff = Evaluator.imageDiff(studentData, solnData);
    }
    finally {
        // eslint-disable-next-line
        return diff;
    }
};
// Given the student and ans data arrays, compute per-pixel diff number.
Evaluator.imageDiff = function (studentData, ansData) {
    if (studentData.length === 0) {
        throw 'Could not get student image data';
    }
    if (ansData.length === 0) {
        throw 'Could not get solution image data';
    }
    if (studentData.length !== ansData.length) {
        throw "image array lengths don't match " + studentData.length + ' ' + ansData.length;
    }
    let diff = 0;
    for (let i = 0; i < studentData.length; i += 4) {
        diff += Math.abs(studentData[i] - ansData[i]); // R
        diff += Math.abs(studentData[i + 1] - ansData[i + 1]); // G
        diff += Math.abs(studentData[i + 2] - ansData[i + 2]); // B
    }
    diff = diff / (studentData.length / 4.0); // error-per-pixel
    return diff;
};
// -- SimpleImage support -- //
// References one pixel in a SimpleImage, supports rgb get/set.
export class SimplePixel {
    constructor(simpleImage, x, y) {
        this.getRed = function () {
            Evaluator.funCheck('getRed', 0, arguments.length);
            return this.simpleImage.getRed(this.x, this.y);
        };
        this.setRed = function (val) {
            Evaluator.funCheck('setRed', 1, arguments.length);
            this.simpleImage.setRed(this.x, this.y, val);
        };
        this.getGreen = function () {
            Evaluator.funCheck('getGreen', 0, arguments.length);
            return this.simpleImage.getGreen(this.x, this.y);
        };
        this.setGreen = function (val) {
            Evaluator.funCheck('setGreen', 1, arguments.length);
            this.simpleImage.setGreen(this.x, this.y, val);
        };
        this.getBlue = function () {
            Evaluator.funCheck('getBlue', 0, arguments.length);
            return this.simpleImage.getBlue(this.x, this.y);
        };
        this.setBlue = function (val) {
            Evaluator.funCheck('setBlue', 1, arguments.length);
            this.simpleImage.setBlue(this.x, this.y, val);
        };
        this.getX = function () {
            Evaluator.funCheck('getX', 0, arguments.length);
            return this.x;
        };
        this.getY = function () {
            Evaluator.funCheck('getY', 0, arguments.length);
            return this.y;
        };
        // copy values from source pixel
        this.setPixel = function (pixel) {
            this.setRed(pixel.getRed());
            this.setGreen(pixel.getGreen());
            this.setBlue(pixel.getBlue());
        };
        // Render pixel as string -- print() uses this
        this.getString = function () {
            return 'r:' + this.getRed() + ' g:' + this.getGreen() + ' b:' + this.getBlue();
        };
        this.simpleImage = simpleImage;
        this.x = x;
        this.y = y;
    }
}
// Relies on invisible canvas, inited either with a "foo.jpg" url,
// or an htmlImage from loadImage().
export class SimpleImageImpl {
    constructor(imageName, ctx) {
        this.getWidth = function () {
            return this.width;
        };
        this.getHeight = function () {
            return this.height;
        };
        // Computes index into 1-d array, and checks correctness of x,y values
        this.getIndex = function (x, y) {
            if (x === null || y === null) {
                throw new Error('need x and y values passed to this function');
            }
            else if (x < 0 || x >= this.width || y < 0 || y >= this.height) {
                throw new Error('x/y out of bounds x:' + x + ' y:' + y);
            }
            else
                return (x + y * this.width) * 4;
        };
        // --setters--
        // Clamp values to be in the range 0..255. Used by setRed() et al.
        this.clamp = function (value) {
            // value = Math.floor(value);  // .js is always float, so this line
            // is probably unncessary, unless we get into some deep JIT level.
            if (value < 0)
                return 0;
            if (value > 255) {
                return 255;
            }
            return value;
        };
        // Sets the red value for the given x,y
        this.setRed = function (x, y, value) {
            Evaluator.funCheck('setRed', 3, arguments.length);
            const index = this.getIndex(x, y);
            this.imageData.data[index] = this.clamp(value);
            // This is how you would write back each pixel individually.
            // It gives terrible performance (on Firefox anyway).
            // this.context.putImageData(this.imageData, 0, 0, x, y, 1, 1);
            // dx dy dirtyX dirtyY dirtyWidth dirtyHeight
        };
        // Sets the green value for the given x,y
        this.setGreen = function (x, y, value) {
            Evaluator.funCheck('setGreen', 3, arguments.length);
            const index = this.getIndex(x, y);
            this.imageData.data[index + 1] = this.clamp(value);
        };
        // Sets the blue value for the given x,y
        this.setBlue = function (x, y, value) {
            Evaluator.funCheck('setBlue', 3, arguments.length);
            const index = this.getIndex(x, y);
            this.imageData.data[index + 2] = this.clamp(value);
        };
        // Sets the alpha value for the given x,y
        this.setAlpha = function (x, y, value) {
            Evaluator.funCheck('setAlpha', 3, arguments.length);
            const index = this.getIndex(x, y);
            this.imageData.data[index + 3] = this.clamp(value);
        };
        this.setZoom = function (n) {
            this.zoom = n;
        };
        this.getRed = function (x, y) {
            Evaluator.funCheck('getRed', 2, arguments.length);
            const index = this.getIndex(x, y);
            return this.imageData.data[index];
        };
        this.getGreen = function (x, y) {
            Evaluator.funCheck('getGreen', 2, arguments.length);
            const index = this.getIndex(x, y);
            return this.imageData.data[index + 1];
        };
        this.getBlue = function (x, y) {
            Evaluator.funCheck('getBlue', 2, arguments.length);
            const index = this.getIndex(x, y);
            return this.imageData.data[index + 2];
        };
        this.getAlpha = function (x, y) {
            Evaluator.funCheck('getAlpha', 2, arguments.length);
            const index = this.getIndex(x, y);
            return this.imageData.data[index + 3];
        };
        // Gets the pixel object for this x,y. Changes to the
        // pixel write back to the image.
        this.getPixel = function (x, y) {
            Evaluator.funCheck('getPixel', 2, arguments.length);
            return new SimplePixel(this, x, y);
        };
        // Export an image as an array of pixel refs for the for-loop.
        this.toArray = function () {
            const array = [];
            // 1. simple-way (this is as good or faster in various browser tests)
            // var array = new Array(this.getWidth() * this.getHeight()); // 2. alloc way
            // var i = 0;  // 2.
            // nip 2012-7  .. change to cache-friendly y/x ordering
            // Non-firefox browsers may benefit.
            for (let y = 0; y < this.getHeight(); y += 1) {
                for (let x = 0; x < this.getWidth(); x += 1) {
                    // array[i += 1] = new SimplePixel(this, x, y);  // 2.
                    array.push(new SimplePixel(this, x, y)); // 1.
                }
            }
            return array;
        };
        // Change the size of the image to the given, scaling the pixels.
        this.setSize = function (newWidth, newHeight) {
            // flush any changes from buffer to a temp canvas to be used as src
            const srcCanvas = this.ctx.getCanvas(0);
            srcCanvas.width = this.width;
            srcCanvas.height = this.height;
            const srcContext = srcCanvas.getContext('2d');
            srcContext.putImageData(this.imageData, 0, 0);
            // get second temp canvas of new size
            const dstCanvas = this.ctx.getCanvas(1);
            dstCanvas.width = newWidth;
            dstCanvas.height = newHeight;
            // scale by canvas-to-canvas drawing to get image smoothing
            const dstContext = dstCanvas.getContext('2d');
            dstContext.drawImage(srcCanvas, 0, 0, dstCanvas.width, dstCanvas.height);
            // reload this image's data from dst canvas
            this.width = dstCanvas.width;
            this.height = dstCanvas.height;
            this.imageData = dstContext.getImageData(0, 0, dstCanvas.width, dstCanvas.height);
        };
        // Set this image to be the same size to the passed in image.
        // This image may end up a little bigger than the passed image
        // to keep its proportions.
        // Useful to set a back image to match the size of the front
        // image for bluescreen.
        this.setSameSize = function (otherImage) {
            if (!this.width)
                return;
            const wscale = otherImage.width / this.width;
            const hscale = otherImage.height / this.height;
            const scale = Math.max(wscale, hscale);
            if (scale !== 1) {
                this.setSize(Math.floor(this.width * scale), Math.floor(this.height * scale));
            }
        };
        // Draws to the given canvas, setting its size.
        // Used to implement printing of an image.
        this.drawTo = function (toCanvas) {
            if (!this.zoom) {
                toCanvas.width = this.width;
                toCanvas.height = this.height;
            }
            else {
                toCanvas.width = this.width * this.zoom;
                toCanvas.height = this.height * this.zoom;
            }
            // AW: put bits from image's data cache without going via canvas
            const toContext = toCanvas.getContext('2d');
            if (toContext === null)
                throw new Error('Error getting drawing context');
            // drawImage() takes either an htmlImg or a canvas
            if (!this.zoom) {
                toContext.putImageData(this.imageData, 0, 0);
            }
            else {
                // in effect we want this:
                // toContext.drawImage(this.canvas, 0, 0, toCanvas.width, toCanvas.height);
                // Manually scale/copy the pixels, to avoid the default smoothing effect.
                // changed: createImageData apparently better than getImageData here.
                const toData = toContext.createImageData(toCanvas.width, toCanvas.height);
                for (let x = 0; x < toCanvas.width; x += 1) {
                    for (let y = 0; y < toCanvas.height; y += 1) {
                        const iNew = (x + y * toCanvas.width) * 4;
                        const iOld = (Math.floor(x / this.zoom) + Math.floor(y / this.zoom) * this.width) * 4;
                        for (let j = 0; j < 4; j += 1) {
                            toData.data[iNew + j] = this.imageData.data[iOld + j];
                        }
                    }
                }
                toContext.putImageData(toData, 0, 0);
            }
        };
        let htmlImage = null;
        if (typeof imageName === 'string') {
            htmlImage = ctx.getResource(imageName);
        }
        else {
            throw new Error('new SimpleImage(...) requires an image name.');
        }
        if (!htmlImage) {
            throw new Error('Image not found: ' + imageName);
        }
        if (!htmlImage.complete) {
            throw new Error('Image still loading -- wait a bit and retry');
        }
        this.width = htmlImage.width;
        this.height = htmlImage.height;
        this.ctx = ctx;
        // render to temp canvas to get image data
        const canvas = ctx.getCanvas(0);
        if (!canvas)
            throw new Error('Failed to get canvas for ' + name);
        const context = canvas.getContext('2d');
        if (!context)
            throw new Error('getContext failed for ' + name);
        context.canvas.width = this.width;
        context.canvas.height = this.height;
        context.drawImage(htmlImage, 0, 0);
        // Do this last so it gets the actual image data.
        this.imageData = context.getImageData(0, 0, this.width, this.height);
    }
}
// Simple Table Support //
export class Row {
    constructor(table, rowArray) {
        // Returns the nth value from this row.
        this.getColumn = function (n) {
            // todo: could do bounds checking here to be more friendly
            return this.array[n];
        };
        // Returns the value for the named field.
        this.getField = function (fieldName) {
            const index = this.table.getFieldIndex(fieldName);
            if (index === -1) {
                throw new Error('getField() unknown field name: ' + fieldName);
            }
            return this.array[index];
        };
        // Returns the raw array; used for printing.
        this.getArray = function () {
            return this.array;
        };
        this.getString = function () {
            return this.array.join(', ');
        };
        this.table = table;
        this.array = rowArray;
    }
}
// Creates a new table with the given file
export class SimpleTableImpl {
    constructor(filename, ctx) {
        this.getColumnCount = function () {
            return this.fields.length;
        };
        // Returns an array of the field names.
        this.getFields = function () {
            return this.fields;
        };
        // Limits the table to just n rows.
        this.limitRows = function (n) {
            this.rows.splice(n, this.rows.length - n);
        };
        // Returns the index for a field name (case sensitive).
        // Used internally by row.getField()
        this.getFieldIndex = function (fieldName) {
            return this.fields.findIndex((f) => f === fieldName);
        };
        // Returns the number of rows.
        this.getRowCount = function () {
            return this.rows.length;
        };
        // Returns the nth row.
        this.getRow = function (n) {
            if (n < 0 || n >= this.rows.length) {
                throw 'Count of rows is ' + this.rows.length + ', but attempting to get row:' + n;
            }
            return this.rows[n];
        };
        // toArray() adapter so for (part: composite) works.
        // In this case, we just return the internal array of row objects.
        this.toArray = function () {
            return this.rows;
        };
        const text = ctx.getResource(filename);
        const lines = text.split(/\n|\r\n/); // test: this does work with DOS line endings
        // todo: could have some logic about if the first row is the field names or not
        this.fields = SimpleTableImpl.splitCSV(lines[0], 0);
        lines.splice(0, 1); // remove 0th element
        const rows = [];
        for (const line of lines) {
            const parts = SimpleTableImpl.splitCSV(line, this.fields.length);
            if (parts.length !== 0) {
                // essentially we skip blank lines
                rows.push(new Row(this, parts));
            }
        }
        this.rows = rows;
    }
    // Given a text line, explode the CSV and return an array elements.
    // Columns is the expected number of columns to fill out to, or 0 to ignore.
    // Returns [] on empty string, as you might see with a blank line.
    // The elements are whitespace trimmed.
    // Can make this more sophisticated about CSV format later.
    static splitCSV(line, columns) {
        const trimmed = line.replace(/^\s+|\s+$/g, ''); // .trim() effectively, and below
        if (trimmed === '')
            return [];
        const fields = trimmed.split(/,/, -1).map((field) => field.replace(/^\s+|\s+$/g, ''));
        // hack: file can omit blank data from RHS .. add it back on
        while (columns && fields.length < columns) {
            fields.push('');
        }
        return fields;
    }
}
//# sourceMappingURL=Evaluator.js.map