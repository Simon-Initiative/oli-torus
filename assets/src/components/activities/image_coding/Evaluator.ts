import { ImageCodingDelivery } from "./ImageCodingDelivery";

export type EvalContext = {
  getImage: (name:string) => HTMLImageElement | null;
  getCanvas: (name: string) => HTMLCanvasElement | null;
  // getTempCanvas: () => HTMLCanvasElement | null;
  getResult: (solution: boolean) => HTMLCanvasElement | null;
  appendOutput: (s: string) => void;
  solutionRun: boolean;
};

declare global {
  interface Window {
    SimpleImage: Function;
    print: () => void;
    Evaluator : Function;
  }
}

export class Evaluator {

  static printOne(something: any, ctx: EvalContext) {

    // special case for rendering result image
    if (something instanceof SimpleImageImpl) {
      var canvas = ctx.getResult(ctx.solutionRun);
      something.drawTo(canvas);
      return;
    }

    // If there's a .getString() function, use it (Row SimplePixel Histogram)
    // This spares us from depending on instanceof/classname.
    if (something.getString) {
      something = something.getString();
    }

    // hack: make array look like string
    if (something instanceof Array) {
      something = "[" + something.join(", ") + "]";
    }

    var spacer = something == '\n' ? '' : ' ';

    ctx.appendOutput(something + spacer);
  }

  static myprint(ctx : EvalContext, ...args: any): void {
    for (var i = 0; i < args.length; i++) {
      this.printOne(args[i], ctx);
    }

    var lastArg = args[args.length -1];
    var hasBreak = lastArg instanceof SimpleImageImpl || lastArg === '\n';
    if (! hasBreak) {
      this.printOne("\n", ctx);
    }
  }

  // -- special for-loop syntax --//

  // Given code, return sugared up code, or may throw error.
  // expands: for (part: composite) {
  static sugarCode(code : string) {
    var reWeak = /for *\([ \w+().-]*:[ \w+().-]*\) *\{/g;
    // important: the g is required to avoid infinite loop
    // weak: for ( stuff* : stuff*) {
    // weak not allowing newline etc., or the * goes too far
    var reStrong = /for\s*\(\s*(?:var\s+)?(\w+)\s*:\s*(\w+(\(.*?\))?)\s*\)\s*\{/;
    // strong: for([var ]x : y|foo(.*?) ) {

    // Find all occurences of weak, check that each is also strong.
    // e.g. "for (x: 1 +1) {" should throw this error
    var result;
    while ((result = reWeak.exec(code)) != null) {
      // have result[0] result.index, reWeak.lastIndex
      var matched = result[0];
      //alert(matched);
      if (matched.search(reStrong) == -1) {
        Evaluator.throwError("Attempt to use 'for(part: composite)' form, but it looks wrong: " + result[0]);
        // todo: since it happens before the eval, this error ends up in an alert(), but maybe
        // appearing in the regular red-text would be better.
      }
    }

    // Loop, finding the next
    var gensym = 0;
    while (1) {
      var temp = code;
      var pvar = "pxyz" + gensym;
      var ivar = "ixyz" + gensym;
      gensym++;
      var replacement = "var " + pvar + " = Evaluator.getArray($2); " +
        "for (var " + ivar + "=0; " + ivar + "<" + pvar + ".length; " + ivar + "++) {" +
        "var $1 = " + pvar + "[" + ivar + "];";
      code = code.replace(reStrong, replacement);
      if (code == temp) break;
    }
    return(code);
    //return code.replace(reStrong, replacement);

    // someday: could look for reWeak, compare to where reStrong applied,
    // see if there is a case where they are trying but failing to use the for(part) form.
    // Or an easy to implement form would be to look for "for (a b c)" or whatever
    // where the lexemes look wrong, and flag it before the sugaring even happens.
    //var reWeak = /for\s*\((.*?)\)\s*\{/;
    //while ((result = reWeak.exec(code)) != null) {
    // have result[0] result.index, reWeak.lastIndex
  }

  // Wrapper called on the composite by the for(part: composite) sugar, and it does
  // some basic error checking.
  static getArray(obj : any) {
    if (obj && typeof(obj) == 'object') {
      if (obj instanceof Array) {
        return obj;
      } else if ('toArray' in obj) {
        return obj.toArray();
      }
    } else {
      this.throwError("'for (part: composite)' used, but composite is wrong.");
    }
  }

  // Call this to abort with a message e.g. "Wrong number of arguments to foo()".
  // todo: in some cases, this does not show up in the UI, missing the try/catch
  // in the evaluate chain for some reason.
  static throwError(message : string) {
      var err = new Error;
      err.message = message;
      //err.inhibitLine = true;  // this gets the .message through, but the line number will be wrong
      throw err;
  }

  // Called from user-facing functions, checks number of arguments.
  static funCheck(funName : string, expectedLen : number, actualLen : number) {
    if (expectedLen != actualLen) {
      var s1 = (actualLen == 1)?"":"s";  // pluralize correctly
      var s2 = (expectedLen == 1)?"":"s";
      var message = funName + "() called with " + actualLen + " value" + s1 + ", but expected " +
        expectedLen + " value" + s2 + ".";
      // someday: think about "values" vs. "arguments" here
      // todo: any benefit to throwing an Error here vs. a string?
      this.throwError(message);
    }
  }


  static execute (src : string,  ctx: EvalContext) : any {

    // set up environment for calls by user code
    let print = (...args: any) => { Evaluator.myprint(ctx, ...args); };

    class SimpleImage extends SimpleImageImpl {
      constructor(name : string) {
        super(name, ctx);
      }
    }

    // install these into global scope for access by user code
    window.SimpleImage = SimpleImage;
    window.print = print;
    window.Evaluator = Evaluator;

    var result : any;
    try {
      const code = this.sugarCode(src);

      // Use Function to execute in global scope. Note user vars persist.
      // result = eval(code);
      result = Function(code)();
      return "Evaluator.execute result: " + result;
    }
    catch(e) {
      //alert(e);
      e.userError = true;
      // var line = extractLine(e, evalLine)
      //if (line != -1) e.userLine = line;
      return e;
    }

    return null;
  }

  // Given the student and ans data arrays, compute per-pixel diff number.
  static imageDiff = function(studentData : Uint8ClampedArray, ansData : Uint8ClampedArray) {
    if (studentData.length != ansData.length)
      throw("image array lengths don't match " + studentData.length + " " + ansData.length);

    var diff = 0;
    for (var i = 0; i < studentData.length; i+=4) {
        diff += Math.abs(studentData[i] - ansData[i]);  // R
        diff += Math.abs(studentData[i + 1] - ansData[i + 1]);  // G
        diff += Math.abs(studentData[i + 2] - ansData[i + 2]);  // B

    }
    diff = diff / (studentData.length/4.0);  // error-per-pixel

    return diff;
  }
}



// -- SimpleImage support -- //

// References one pixel in a SimpleImage, supports rgb get/set.
export class SimplePixel {
  simple_image: SimpleImageImpl;
  x: number;
  y: number;

  constructor (simple_image : SimpleImageImpl, x : number, y: number) {
    this.simple_image = simple_image;
    this.x = x;
    this.y = y;
  };

  getRed = function() {
    Evaluator.funCheck("getRed", 0, arguments.length);
    return this.simple_image.getRed(this.x, this.y);
  };
  setRed = function(val) {
    Evaluator.funCheck("setRed", 1, arguments.length);
    this.simple_image.setRed(this.x, this.y, val);
  };
  getGreen = function() {
    Evaluator.funCheck("getGreen", 0, arguments.length);
    return this.simple_image.getGreen(this.x, this.y);
  };
  setGreen = function(val) {
    Evaluator.funCheck("setGreen", 1, arguments.length);
    this.simple_image.setGreen(this.x, this.y, val);
  };
  getBlue = function() {
    Evaluator.funCheck("getBlue", 0, arguments.length);
    return this.simple_image.getBlue(this.x, this.y);
  };
  setBlue = function(val) {
    Evaluator.funCheck("setBlue", 1, arguments.length);
    this.simple_image.setBlue(this.x, this.y, val);
  };

  getX = function() {
    Evaluator.funCheck("getX", 0, arguments.length);
    return this.x;
  };
  getY = function() {
    Evaluator.funCheck("getY", 0, arguments.length);
    return this.y;
  };

  // Render pixel as string -- print() uses this
  getString = function() {
    return "r:" + this.getRed() + " g:" + this.getGreen() + " b:" + this.getBlue();
  };
}

  // Relies on invisible canvas, inited either with a "foo.jpg" url,
  // or an htmlImage from loadImage().
  export class SimpleImageImpl {
    width: number;
    height: number;
    zoom: number;
    canvas: HTMLCanvasElement | null;
    context: CanvasRenderingContext2D;
    imageData: ImageData;

    constructor (image : any, ctx: EvalContext) {
     var htmlImage = null;
     if (typeof image == "string") {
       htmlImage = ctx.getImage(image);
     } else if (image instanceof HTMLImageElement) {
       htmlImage = image;
     } else {
       Evaluator.throwError("new SimpleImage(...) requires a htmlImage.");
     }

     if (!htmlImage.complete) {
       alert("Image loading -- may need to run again");
     }

     this.width = htmlImage.width;
     this.height = htmlImage.height;

     //console.log(this);

     this.canvas = ctx.getCanvas(name);

     // Do this last so it gets the actual image data.
     this.context = this.canvas.getContext("2d");
     this.imageData = this.context.getImageData(0, 0, this.width, this.height);
   }

    getWidth = function() {
       return this.width;
     }

    getHeight = function() {
       return this.height;
     }

     // Computes index into 1-d array, and checks correctness of x,y values
    getIndex = function(x, y) {
       if (x == null || y == null) {
         Evaluator.throwError("need x and y values passed to this function");
       }
       else if (x < 0 || x >= this.width || y < 0 || y >= this.height) {
        Evaluator.throwError("x/y out of bounds x:" + x + " y:" + y);
       }
       else return (x + y * this.width) * 4;
     }


     // --setters--

     // Clamp values to be in the range 0..255. Used by setRed() et al.
    clamp = function(value : number) {
      // value = Math.floor(value);  // .js is always float, so this line
      // is probably unncessary, unless we get into some deep JIT level.
      if (value < 0) return 0;
      if (value > 255) return 255;
      return value;
    }

     // Sets the red value for the given x,y
     setRed = function(x, y, value) {
       Evaluator.funCheck("setRed", 3, arguments.length);
       var index = this.getIndex(x, y);
       this.imageData.data[index] = this.clamp(value);

       // This is how you would write back each pixel individually.
       // It gives terrible performance (on Firefox anyway).
       // this.context.putImageData(this.imageData, 0, 0, x, y, 1, 1);
       // dx dy dirtyX dirtyY dirtyWidth dirtyHeight
     };

     // Sets the green value for the given x,y
     setGreen = function(x, y, value) {
       Evaluator.funCheck("setGreen", 3, arguments.length);
       var index = this.getIndex(x, y);
       this.imageData.data[index + 1] = this.clamp(value);
     };

     // Sets the blue value for the given x,y
     setBlue = function(x, y, value) {
       Evaluator.funCheck("setBlue", 3, arguments.length);
       var index = this.getIndex(x, y);
       this.imageData.data[index + 2] = this.clamp(value);
     };

     // Sets the alpha value for the given x,y
     setAlpha = function(x, y, value) {
       Evaluator.funCheck("setAlpha", 3, arguments.length);
       var index = this.getIndex(x, y);
       this.imageData.data[index + 3] = this.clamp(value);
     };

     setZoom = function(n : number) {
       this.zoom = n;
     }

     // --getters--
     // Gets the red value for the given x,y
     getRed = function(x, y) {
       Evaluator.funCheck("getRed", 2, arguments.length);
       var index = this.getIndex(x, y);
       return this.imageData.data[index];
     };

     getGreen = function(x, y) {
       Evaluator.funCheck("getGreen", 2, arguments.length);
       var index = this.getIndex(x, y);
       return this.imageData.data[index + 1];
     };
     // Gets the blue value for the given x,y
      getBlue = function(x, y) {
       Evaluator.funCheck("getBlue", 2, arguments.length);
       var index = this.getIndex(x, y);
       return this.imageData.data[index + 2];
     };
     // Gets the blue value for the given x,y
     getAlpha = function(x, y) {
       Evaluator.funCheck("getAlpha", 2, arguments.length);
       var index = this.getIndex(x, y);
       return this.imageData.data[index + 3];
     };

     // Gets the pixel object for this x,y. Changes to the
    // pixel write back to the image.
    getPixel = function(x, y) {
      Evaluator.funCheck("getPixel", 2, arguments.length);
      return new SimplePixel(this, x, y);
    };

    // Export an image as an array of pixel refs for the for-loop.
    toArray = function() {
      var array = new Array();  // 1. simple-way (this is as good or faster in various browser tests)
      //var array = new Array(this.getWidth() * this.getHeight()); // 2. alloc way
      //var i = 0;  // 2.
      // nip 2012-7  .. change to cache-friendly y/x ordering
      // Non-firefox browsers may benefit.
      for (var y = 0; y < this.getHeight(); y++) {
        for (var x = 0; x < this.getWidth(); x++) {
          //array[i++] = new SimplePixel(this, x, y);  // 2.
          array.push(new SimplePixel(this, x, y));  // 1.
        }
      }
      return array;
    }

 // Pushes any accumulated local changes out to the screen
  flush = function() {
    this.context.putImageData(this.imageData, 0, 0);  // can omit x/y/width/height and get default behavior
  };

  // Draws to the given canvas, setting its size.
  // Used to implement printing of an image.
  drawTo = function(toCanvas : HTMLCanvasElement) {
    if (!this.zoom) {
      toCanvas.width = this.width;
      toCanvas.height = this.height;
    }
    else {
      toCanvas.width = this.width * this.zoom;
      toCanvas.height = this.height * this.zoom;
      // AW: needed anywhere?
      // toCanvas.zoom = this.zoom;  // record that this was zoomed
    }

    // AW: put bits from image's data cache without flushing to canvas
    // this.flush();
    var toContext = toCanvas.getContext("2d");
    // drawImage() takes either an htmlImg or a canvas
    if (!this.zoom) {
      // toContext.drawImage(this.canvas, 0, 0);
      toContext.putImageData(this.imageData, 0, 0);
    }
    else {
      // in effect we want this:
      //toContext.drawImage(this.canvas, 0, 0, toCanvas.width, toCanvas.height);

      // Manually scale/copy the pixels, to avoid the default blurring effect.
      // changed: createImageData apparently better than getImageData here.
      var toData = toContext.createImageData(toCanvas.width, toCanvas.height);
      for (var x = 0; x < toCanvas.width; x++) {
        for (var y = 0; y < toCanvas.height; y++) {
          var iNew =  (x + y * toCanvas.width) * 4;
          var iOld = (Math.floor(x / this.zoom) + Math.floor(y / this.zoom) * this.width) * 4;
          for (var j = 0; j < 4; j++) {
            toData.data[iNew + j] = this.imageData.data[iOld + j];
          }
        }
      }
      toContext.putImageData(toData, 0, 0);
      // todo: above line throws an exception in Chrome if
      // args toCanvas.width, toCanvas.height are included: bug report?
    }
  }

}