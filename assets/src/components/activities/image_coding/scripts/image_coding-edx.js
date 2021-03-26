// Nick Parlante -- in progress cs101.js for CS101 2014
// http://www.stanford.edu/class/cs101
// I should create a proper github for this someday.
// Created by Nick Parlante
// This code is released under the Apache 2.0 license
// http://www.apache.org/licenses/LICENSE-2.0


// Functions to indent new lines .. this code donated by codingbat.com
function insertNewline(ta) {
  if (ta.selectionStart != undefined) {  // firefox etc.
    var before = ta.value.substring(0, ta.selectionStart);
    var indent = figureIndent(before);
    var selSave = ta.selectionEnd;
    var after = ta.value.substring(ta.selectionEnd, ta.value.length)

    // update the text field
    var tmp = ta.scrollTop;  // inhibit annoying auto-scroll
    ta.value = before + "\n" + indent + after;
    var pos = selSave + 1 + indent.length;
    ta.selectionStart = pos;
    ta.selectionEnd = pos;
    ta.scrollTop = tmp;

    // we did it, so return false
    return false;
  } else if (document.selection && document.selection.createRange) { // IE
     var r = document.selection.createRange()
     var dr = r.duplicate()
     dr.moveToElementText(ta)
     dr.setEndPoint("EndToEnd", r)
     var c = dr.text.length - r.text.length
     var b = ta.value.substring(0, c);
     var i = figureIndent(b);
     if (i == "") return true;  // let natural event happen
     r.text = "\n" + i;
     return false;
  }

  return true;
}

// given text running up to cursor, return spaces to put at
// start of next line.
function figureIndent(str) {
  var eol = str.lastIndexOf("\n");
  // eol==-1 works ok
  var line = str.substring(eol + 1);  // take from eol to end
  var indent="";
  for (i=0; i<line.length && line.charAt(i)==' '; i++) {
    indent = indent + " ";
  }
  return indent;
}

function handleCR(ta, event) {
  if (event.keyCode==13) return insertNewline(ta)
  else {
    return true;
  }
}



// From eval-exception, figure out the line number or -1.
function extractLine(e, evalLine) {
  if (e.inhibitLine) return -1;  // can be set to specifically inhibit line numbers

  // Safari has a .line attribute which is what we want.
  // 2014: this has stopped working, added < 50 heuristic
  if (e.line && e.line < 50) {
    return e.line;
  }
  // Firefox has a .lineNumber (non-standard, and iffy)
  // Screening out that Firefox seems to go to negative numbers sometimes
  if (e.lineNumber) {
    // Semantics of e.lineNumber changed around Firefox 30
    if (e.lineNumber > evalLine) return e.lineNumber - evalLine + 1;  // old semantics (remove someday)
    return e.lineNumber; // new semantics
  }

  return -1;
}

// Given id of textarea, eval its code.
// For code errors, returns an error object with
// .userError true and .name .line .message set.
// Otherwise returns null.
function evaluate(inID) {
  var ta = document.getElementById(inID);
  //console.log(ta.meh);
  // 2012
  var preErr = preflightCheck(ta.value);
  if (preErr) {
    //alert(preErr);
    var e = new Error;
    e.message = preErr;
    return e;
    // todo: work on flagging the right line here
  }
  // todo: could have some way for them to turn preflight off

  var text = sugarCode(ta.value);
  var evalLine = 0;
  var error = new Error;
  if (error.lineNumber) evalLine = error.lineNumber + 3;
  try {
    eval(text);
  }
  catch(e) {
    //alert(e);
    e.userError = true;
    var line = extractLine(e, evalLine)
    if (line != -1) e.userLine = line;
    return e;
  }
  return null;
}

// 2014 soln work
// Cases:
// -think about what to do if there's an image that is not preloaded ... some sort of err msg
// -is it ok to share img objects inside output? It sure seems to work.
//  chase down what is changed vs. not
// -Need a tunable parameter for the grading threshold, could also spec a rectangle
// -Support the "demo" case where there is no solution (basically wiring up preload/error cases)

// we preload images in both code and soln. If one fails to load, we put
// up an alert. However, this means that nothing runs since the image-load counter
// never reaches the needed number. Q: could blunder ahead. On the other hand,
// the super common case is that the soln loads the same image as the code.
// Maybe unify the "preload" and "load" error cases. We can't just be quiet about
// the preload error, since it causes the code to not run at all.



// Get the soln text
// todo: some sort of obfuscation of what's going on.
// 2014: returns null if no soln
function getSolnText(id) {
  // for fun, see if there's a ta -soln
  var ta = document.getElementById(id + '-soln');
  var text = '';
  if (ta!=null && ta.value) {
    text = ta.value;
  } else {
    // fallback with 'meh' attribute
    ta = document.getElementById(id);
    text = ta.getAttribute('meh');
    if (text!=null) text = sugarCode(unescape(text.replace(new RegExp('\\\\', 'g'), '%')));
  }

  if (text) return sugarCode(text);
  else return null;

// here's how you decode the other way
//   } else {
//     // todo: error handling
//
//   }
}



// Select the given line in the ta (for error reporting)
function selectLine(ta, line) {
  if (!ta.setSelectionRange) return;

  var count = 0;
  var start = 0;
  var text = ta.value;
  for (var i = 0; i<text.length; i++) {
    if (text[i] == "\n" || (start!=0 && i==text.length-1)) {
      count++;  // [i] is the end of line count
      if (count == line - 1) start = i + 1;
      else if (count == line ) {
        ta.focus();
        ta.setSelectionRange(start, i);
        return;
      }
    }
  }
}


// Wrap evaluate() with logic to show error messages.
// Prints/line-selects on error output.
export function evaluateShow(inID) {
  try {
    var e = evaluate(inID);
    if (e != null) {
      var msg = "<font color=red>Error:</font>" + e.message;  // 2012-2 don't make the whole thing red
      if (e.userLine) msg += " line:" + e.userLine;
      print(msg);
      if (e.userLine) {
        var ta = document.getElementById(inID);
        selectLine(ta, e.userLine);
      }
    }
  }
  catch (e) {
    alert("Low level evaluation error:" + e);
  }
}

// 2014
// Wrapper for evaluate which clears the output
// and allows that GUI update to happen before
// running.
// function oldevaluateClear(id) {
//   store(id);
//
//   window.globalRunId = id;  // hack: set state used by printing
//   window.globalPrintCount = 5000;
//   window.globalLastCanvas = null;  // 2014
//   window.globalSolnName = null;
//
//   clearOutput();
//
//   var ta = document.getElementById(id);
//   var text = ta.value;
//   preloadImages(text);
//
//   // hack: use setTimeout to run this a bit in the future, so the UI
//   // update of the above clearOutput() goes through.
//   setTimeout(function() { evaluateShow(id); }, 100);
// }


// 2014
// New evaluateClear (todo: fold in with below)
// Note: This is used in production for spring-2014.
function evaluateClear(id) {

  // Ross: Run button was just clicked, add logging code here
  store(id);

  window.globalRunId = id;  // hack: set state used by printing
  window.globalLastCanvas = null;  // regular canvas
  window.globalLastCanvas2 = null;  // soln canvas
  window.globalSolnName = null;  // this is maybe not used
  window.globalSolnRun = false;  // marker of regular/soln run
  window.globalPrintText = "";

  clearOutput();

  var ta = document.getElementById(id);
  var text = ta.value;
  var images = extractImages(text);

  window.globalImageNeeded = images.length;
  window.globalImageCount = 0;
  window.globalImageFn = function() { evaluateShow(id); };

  setTimeout(function() { preloadImages(images); }, 100);
}

// New evaluateClear() supporting new soln preload/grading
function evaluateClearSoln(id) {
  store(id);

  window.globalRunId = id;  // hack: set state used by printing
  window.globalPrintCount = 5000;

  // online 2013 additions
  window.globalLastCanvas = null;  // regular canvas
  window.globalLastCanvas2 = null;  // soln canvas
  window.globalSolnName = null;  // this is maybe not used
  window.globalSolnRun = false;  // marker of regular/soln run

  clearOutput();

  var ta = document.getElementById(id);
  var text = ta.value;
  var images = extractImages(text);

  // ALSO pre-load soln images (which really should just be the same)
  var solntext = getSolnText(id);
  var solnimages = [];
  if (solntext) solnimages = extractImages(solntext);  // 2014: soln conditional
  for (var i=0; i<solnimages.length; i++) {
    if (images.indexOf(solnimages[i]) == -1) images.push(solnimages[i]);
  }

  window.globalImageNeeded = images.length;
  window.globalImageCount = 0;
  window.globalImageFn = function() { evaluateShow(id); }; // evaluateSoln(id);

  setTimeout(function() { preloadImages(images); }, 100);
}

// edx-todo
// -add loading of soln images - conditional by argument?
// -better to just load them on the "evaluateGrade" path?
// -the "evaluateGrade" thing is just brought in for the JSInput pages
//



// Run this to do the grading
// Returns True/False for correctness.
// This could be in an "exercise.js" that is not part of the -ed pages
// localtest= only present for the localhost testing case
// tolerance=, set a different tolerance from the 1.0 default
// TODO: maybe 1.0 is too small a default anyway
// TODO: ensure globalPrintText cleared for every run
// TODO: could obfuscate info a bit, and decode
// TODO: rationalize this vs. jsinput_getgrade
function evaluateGrade(id, localtest) {
  // Check for re attribute - regex grading
  //debugger
  var ta = document.getElementById(id);
  var re = ta.getAttribute('re');
  if (re) {
    // pre-flight for the re grading case
    if (!window.globalPrintText) {
      console.log('REGEX NOTREADY')
      return 'notready';  // OLI return token value for the 'output not there case', used by OLI upstream
      // print may not work, since there's not runid going, so alert()
      //if (localtest) alert("error: no printout to grade");
      //else throw {"name": "Waitfor Exception", "message":"Nothing to grade. Run and print before grading."};
      //return false;
    }


    console.log('RE1:' + re);
    re = unescape(re.replace(new RegExp('\\\\', 'g'), '%'));
    console.log('RE2:' + re);
    var regex = new RegExp(re, "g");
    var grade = window.globalPrintText.search(regex) > -1;
    console.log(window.globalPrintText + ' GRADE:' + grade);
    if (localtest) print("grade:" + grade);
    return(grade);
  }

  // pre-flight for the image-grading case
  if (!window.globalLastCanvas) {
    return 'notready';      // OLI
    //if (localtest) alert("Run to produce an image before grading");
    // This special exception form works with the JSInput layer
    //else throw {"name": "Waitfor Exception", "message":"No image to grade. Run to produce an image before grading."};
  }

  window.globalRunId = id;  // hack: set state used by printing
  window.globalPrintCount = 5000;

  // soln specific
  window.globalLastCanvas2 = null;  // soln canvas (clear this, but not student canvas)
  window.globalSolnRun = true;  // mark that this is the soln run

  var text = getSolnText(id);

  // todo: the whole async/preload style does not work well here, where we want to
  // sync return a value.
  // workaround: we preload soln images on the student run
  // todo: could have a more direct error message for the student-code-not-yet-run case

  // EDX plan level-0
  // -pre-load is done on the regular user run
  // -the "regular" runs don't need to link the grading case
  // -solution is encoded somewhere
  // -had a way of including it in the .aaa
  // -grade pass: depends on previous user-run, just does diff
  //  the grade-pass code could be stored somewhere else

  // edx-TODO:
  // -think about grading failure modes
  // -common case would be image-load-fail
  // -do we pre-load on the user thread (seems harmless)
  //  it's almost always the exam same files .. could make that a requirement
  // -think about
  // Run the solution code, letting it set state about the soln canvas
  // Note: doing this on our thread, not doing any pre-load stuff, exceptions/errs in soln
  // todo: the common case of grading before running ... make a better user output
  // Current we get the "may need to run again" which is not great

  evaluateSoln(id);  // just an eval() for side-effect

  var diff = gradering();

  var tol = ta.getAttribute('tol');
  if (!tol) tol = 1.0;
  var grade = (diff <= tol);
  if (localtest) print("grade:" + grade + " diff:" + diff);
  return(grade);
}

// Now: evaluates the soln code for side-effect.
// Todo: think about error cases, hiding the soln code better, preloading
// makehtml emits evaluateClearSoln which calls
// this evaluateSoln, demonstrating basic encode/hide
// stripped down evaluate() for soln
// todo: unify evaluate with other path
// todo: rationalize this whole call path
function evaluateSoln(inID) {
  var text = getSolnText(inID);
  try {
    eval(text);
  }
  catch(e) {
    alert('problem eval-of-soln:' + e);  // key for debugging my damn system!
    return e;
  }
  return null;
}


function preGrade() {
  throw {"name": "Waitfor Exception", "message":"Message!"};
}


// 2014 jsinput-hack experiment for save/restore

// Look at our output, saving image data as variables on the parent window:
// .hackoutput and .hackimdata
function saveParent(id) {
  var output = document.getElementById(id + "-output");
  window.parent.window.document.hackoutput = output.cloneNode(true);

  var children = output.childNodes;
  for (var i = 0; i < children.length; i++) {
    var child = children[i];
    if (child.hasAttribute("imdata")) {  // easier than checking node type!
      var canvas = child;
      var imdata = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height);

      // Store each canvas imdata by id
      if (!window.parent.window.document.hackimdata) window.parent.window.document.hackimdata = {};
      window.parent.window.document.hackimdata[canvas.getAttribute("id")] = imdata;
    }
  }
}

// Replace the current output div and format a new one
// formatted with the previously saved data in the parent window.
function restoreParent(id) {
  if (!window.parent.window.document.hackoutput) {
    alert("hackoutput not present");
    return;
  }
  var hackoutput = window.parent.window.document.hackoutput;

  var output = document.getElementById(id + "-output");
  var parent = output.parentNode;
  parent.removeChild(output);
  parent.appendChild(hackoutput);

  var children = hackoutput.childNodes;
  for (var i = 0; i < children.length; i++) {
    var child = children[i];
    if (child.hasAttribute("imdata")) {  // easier than checking node type!
      var canvas = child;
      var imdata = window.parent.window.document.hackimdata[canvas.getAttribute("id")];
      canvas.getContext("2d").putImageData(imdata, 0, 0);
    }
  }
  // .parentNode
  // node.removeChild(node)
}






// evaluate(id + '-soln')

// Run after soln code runs.
// Computes and returns the image diff, or 999 for error.
// todo: structure error cases better.
function gradering() {
  //debugger
  var studentCanvas = window.globalLastCanvas;
  if (!studentCanvas) {
    print("error: no student canvas");
    return(999);
  }

  var solnCanvas = window.globalLastCanvas2;
  if (!solnCanvas) {
    print("error: no soln canvas");
    return(999);
  }


  var studentData = studentCanvas.getContext("2d")
      .getImageData(0, 0, studentCanvas.width, studentCanvas.height).data;

  var solnData = solnCanvas.getContext("2d")
      .getImageData(0, 0, solnCanvas.width, solnCanvas.height).data;

  return(imageDiff(studentData, solnData));
}


// Functions to integrate with JSInput

function jsinput_getgrade() {
  var grade = evaluateGrade('jsinputid');
  console.log("eek getgrade:" + grade);
  return JSON.stringify(grade);
}

function jsinput_getstate() {
  var ta = document.getElementById('jsinputid');
  var text = ta.value;
  var state = JSON.stringify(text);
  console.log("eek getstate:" + state);
  return state;
}

function jsinput_setstate(stateStr) {
  var state = JSON.parse(stateStr);
  console.log("eek setstate:" + state);
  var ta = document.getElementById('jsinputid');
  ta.value = state;
}



// depends on having an "output" div for printing

var appendCount = 0;


// Is this url really an "aux..." name.
// Used in a couple places.
function isAuxUrl(url) {
  return (url.length >= 3 && url.substring(0, 3) == "aux");
}

// 2012-7
// hash filename to data:
var globalCustomImages = { };

// Bottleneck to put in the data:xxx per filename
function addCustomImage(filename, data) {
  window.globalCustomImages[filename.toLowerCase()] = data;
}

// Bottleneck to retrieve data, or null
// Not case sensitive
function getCustomImage(filename) {
  filename = filename.toLowerCase();
  if (filename in window.globalCustomImages) return window.globalCustomImages[filename];
  return null;
}

// 2014
// Callback for image onLoad .. only called on success.
function postImage(img) {
  console.log('post image called');
  window.globalImageCount++;
  if (window.globalImageCount == window.globalImageNeeded)
    window.globalImageFn();
}

// Callback for image load error case .. put up some UI
function errorImage(img) {
  alert('problem loading image:' + img.src);
}

// Returns last-element of path, extract filename from path
function lastElement(path) {
  var i = path.lastIndexOf('/');
  if (i > 0) return path.substr(i+1);
  else return path;
}

// Returns img element inside output with the given src if found, or null.
// Given filename should be the last part of the path, e.g. "flowers.jpg"
function getImageBySrc(filename) {
  var output = getOutput();
  var children = output.childNodes;
  for (var i=0; i<children.length; i++) {
    // 2014: support filename optional attribute
    //var filename = children[i].getAttribute("filename");
    //if (filename && filename == src) return children[i];
    var imgsrc = children[i].getAttribute("src");  // can be huge for data: case
    if (imgsrc && imgsrc.length < 1000 && lastElement(imgsrc) == filename) return children[i];
  }
  return null;
}

// Calls load image once for each name, ignoring the result.
// Upon load, causes the globalImageFn to be run.
function preloadImages(names) {
  // 2014 special case: if there are no images to load, go ahead and jump to running the
  // "post" code.
  if (names.length == 0) {
     window.globalImageFn();
     return;
  }
  for (var i=0; i<names.length; i++) {
    loadImage(names[i]);
  }
}

// Adds a hidden img for the given filename like "flowers.jpg" to the output area
// (starting it to be loaded) and returns a pointer to the img. Uses a cache
// per filename. Can prepend window.globalPathPrefix. Will use custom images
// stored in window.customImages by name.
function loadImage(filename) {
  // Check for cache hit
  var img0 = getImageBySrc(filename);
  if (img0) return img0;
  // Note: custom images won't hit the cache since their
  // filename is data:xxx   ... but that's probably fine.

  // append img tag
  var output = getOutput();
  var id = "img" + appendCount;
  appendCount++;

  // 2014: custom loaded images. Change filename to data:xxx
  var orig_filename = filename;
  var custom = getCustomImage(filename);
  if (custom) {
    console.log('filename found in global custom image:' + filename);
    filename = custom;  // this is the big data:xxxx url
  }

  // 2014 online: observe window.globalPathPrefix
  // e.g. window.globalPathPrefix = "/c4x/Engineering/CS101/asset/"
  // put at front if present
  else if (window.globalPathPrefix && filename.length>0 && filename[0] != '/') {
    filename = window.globalPathPrefix + filename;
  }

  console.log('loadImage image:' + id + ' ' + orig_filename);

  var img = new Image();
  img.setAttribute('id', id);
  img.setAttribute('src', filename);
  img.setAttribute('style', 'display:none');
  img.setAttribute('onLoad','postImage(this);');
  img.setAttribute('onError','errorImage(this);');
  output.appendChild(img);

  return img;
}


// Given image name, install it, find it in the DOM and return it.
// Note: I believe it must be on the same server as the code..
// see: http://stackoverflow.com/questions/2390232/why-does-canvas-todataurl-throw-a-security-exception
// possible fix: http://stackoverflow.com/questions/667519/firefox-setting-to-enable-cross-domain-ajax-request
// function loadImage(filename) {
//   // append img tag
//   var output = getOutput();
//   var id = "img" + appendCount;
//   appendCount++;
//
//   // 2014: this imgdb stuff ... used by the custom-loader
//   // Could maybe notice if the image is *already* in this output area and use that one.
//   // Need to remember what exactly is getting changed under setRed() etc. image vs. canvas.
//   // 2012-7
//   if (filename in globalImgDb) {
//     //var img = new Image();
//     //img.setAttribute('id', id);
//     //filename = globalImgDb[filename];
//     //img.setAttribute('style', 'display:none');
//     // Coursera had this stuff
//     //if (window.globalAriaTags) {
//     //  img.setAttribute('aria-live', 'polite');
//     //  img.setAttribute('aria-atomic', 'true');
//     //}
//     //output.appendChild(img);
//
//     return;
//   }
//   else if (isAuxUrl(filename)) {
//     // trim off .jpg
//     if (filename.indexOf(".jpg") != -1) {
//       filename = filename.substring(0, filename.indexOf(".jpg"));
//     }
//     var ta = document.getElementById(filename);
//     var content = ta.value; // todo: trim needed here?
//
//     // Make data:... be at the front if not there
//     // data:image/jpeg;base64,
//     if (content && !(content.length >= 5 && content.substring(0, 5) == "data:")) {
//       content = "data:image/jpeg;base64," + content;
//     }
//
//     if (!content || content.length < 20) {
//       throwError("Trying to load aux image '" + filename +"' but no data found");
//       // todo: make this error appear in the UI, as it's easy to get.
//     }
//     filename = content;  // Use data:... as the filename and IMG will load it
//   }
//
//   // 2014 online: experiment: don't create *another* img
//   var img0 = getImageBySrc(filename);
//   if (img0) return img0;
//
//   console.log('loadImage image:' + id + ' ' + filename);
//   var img = new Image();
//   img.setAttribute('id', id);
//   img.setAttribute('src', filename);
//   img.setAttribute('style', 'display:none');
//   output.appendChild(img);
//
//   return img;
// }



// Print any number of things, separated by spaces and ending with a carriage return.
function print() {
  // printlimit feature
  if (window.globalPrintCount <= 0) {
    if (window.globalPrintCount == 0) {
      printOne("***print output limited***");
      printOne("<br>");
      window.globalPrintCount--;
    }
    return;
  }
  window.globalPrintCount--;


 for (var i=0; i<arguments.length; i++) {
   printOne(arguments[i], i==arguments.length-1);
 }
 printOne("<br>");
}

// Print any number of things, without the ending carriage return.
function printStart() {
 for (var i=0; i<arguments.length; i++) {
   printOne(arguments[i]);
 }
}

// Returns the current global output element to use -- uses
// globalRunId, so uses the correct output area for the current run.
// Could add "throw" logic to detect errors here.
function getOutput() {
  return document.getElementById(window.globalRunId + "-output");
}

// Low level print-one-thing. The something can be a string, number, htmlImage or SimpleImage.
// Optional 2nd argument isLast, true if this is the last thing, so no spacer to follow.
function printOne(something) {
  var output = getOutput();

  // If there's a .getString() function, use it (Row SimplePixel Histogram)
  // This spares us from depending on instanceof/classname.
  if (something.getString) {
    something = something.getString();
  }

  // hack: make array look like string
  if (something instanceof Array) {
    something = "[" + something.join(", ") + "]";
  }

  if (typeof something == "string" || typeof something == "number") {  // note: instanceof and String is a no-go
    var p = document.createElement("text");
    var spacer = " ";
    if (something == "<br>") spacer = "";
    p.innerHTML = something + spacer;  // by using innerHTML here, markup in the string works.
    output.appendChild(p);
    // 2014 accumulate text output
    if (something == "<br>") {
        something = "\n";
        spacer = "";
    }
    if (arguments.length == 2 && arguments[1]) spacer = ""; // edge case: no spacer for last item
    window.globalPrintText += something + spacer;
  }
  else if (something instanceof HTMLImageElement) {
    var copy = something.cloneNode(true);
    copy.setAttribute("style", "");
    copy.setAttribute("id", "");

    // used to create <p> here to put on new line.
    //var p = document.createElement("p");
    //p.appendChild(copy);
    output.appendChild(copy);
  }
  else if (something instanceof SimpleImage) {
    // Note, error above if SimpleImage not defined (Chrome)
    // append canvas
    var id = "canvas" + appendCount;
    appendCount++;


    var canvas = document.createElement("canvas");
    canvas.setAttribute('id', id);
    something.drawTo(canvas);

    // 2014:
    if (window.globalSolnRun) {
      window.globalLastCanvas2 = canvas;
      // Tricky: the soln canvas is not added ... seems to work!
    }
    else {
      window.globalLastCanvas = canvas;
      output.appendChild(canvas);
      // 2014 jsinput-hack
      // Mark the canvas as the right sort to save.
      canvas.setAttribute("imdata", true);
    }
  }
  else {
    alert("bad print with:" + something);
  }
}

// Clears the current output.
function clearOutput() {
  var output = getOutput();
  output.innerHTML = "";
}

// Clears output for the given input id.
// like "hw1-1" .. -output is added internally.
// todo: I don't think this is used
function clearOutputId(id) {
  var output = document.getElementById(id + "-output");
  if (!output) {
    var err = new Error;
    err.message = "clearOutput() with bad id " + id;
    err.inhibitLine = true;  // this gets the .message through, but the line number will be wrong
    throw(err);
  }
  output.innerHTML = "";
}




// Note there is an Image built in, so don't use that name.

// Makes an invisible canvas, inited either with a "foo.jpg" url,
// or an htmlImage from loadImage().
// maybe: could make this work with another SimpleImage too.
SimpleImage = function(image) {
  var htmlImage = null;
  if (typeof image == "string") {
    htmlImage = loadImage(image);
  } else if (image instanceof HTMLImageElement) {
    htmlImage = image;
  } else {
    var err = new Error;
    err.message = "new SimpleImage(...) requires a htmlImage.";
    err.inhibitLine = true;  // this gets the .message through, but the line number will be wrong
    throw(err);
  }

  // append canvas
  var output = getOutput();
  var id = "canvas" + appendCount;
  appendCount++;

  var canvas = document.createElement("canvas");
  canvas.setAttribute('id', id);
  canvas.setAttribute('style', 'display:none');

  output.appendChild(canvas);
  //var p = document.createElement("text");
  //p.appendChild(canvas);
  //output.appendChild(p);

  if (!htmlImage.complete) {
    alert("Image loading -- may need to run again");
  }

  this.width = htmlImage.width;
  this.height = htmlImage.height;

  //console.log(this);

  this.canvas = canvas;
  this.canvas.width = this.width;
  this.canvas.height = this.height;

  this.context = canvas.getContext("2d");

  this.drawFrom(htmlImage);

  // Do this last so it gets the actual image data.
  this.imageData = this.context.getImageData(0, 0, this.width, this.height);
}


SimpleImage.prototype.canvas;
SimpleImage.prototype.context;
SimpleImage.prototype.width;
SimpleImage.prototype.height;
SimpleImage.prototype.imageData;
SimpleImage.prototype.zoom;
SimpleImage.prototype.mimicZoom;

// Sets a zoom factopr such as 4, to print the image at 4x. Useful
// in order to see individual pixels of an image.
SimpleImage.prototype.setZoom = function(n) {
  this.zoom = n;
};

// Internal use only - mimic the most recent zoom level, if any.
SimpleImage.prototype.mimicZoom = function() {
  if (window.globalLastCanvas && window.globalLastCanvas.hasOwnProperty("zoom")) {
    this.zoom = window.globalLastCanvas.zoom;
  }
};


// Change the size of the image to the given, scaling the pixels.
// (formerly "resize").
SimpleImage.prototype.setSize = function(newWidth, newHeight) {
  // append canvas
  var output = getOutput();
  var id = "canvas" + appendCount;
  appendCount++;

  var canvasNew = document.createElement("canvas");
  canvasNew.width = newWidth;
  canvasNew.height = newHeight;
  canvasNew.setAttribute('id', id);
  canvasNew.setAttribute('style', 'display:none');

  var p = document.createElement("text");
  p.appendChild(canvasNew);
  output.appendChild(p);

  // draw OUR canvas to new canvas
  this.flush();
  var contextNew = canvasNew.getContext("2d");
  contextNew.drawImage(this.canvas, 0, 0, newWidth, newHeight);

  // then Swap in canvas
  this.width = canvasNew.width;
  this.height = canvasNew.height;

  this.canvas = canvasNew;
  this.context = canvasNew.getContext("2d");

  // Do this last so it gets the actual image data.
  this.imageData = this.context.getImageData(0, 0, this.width, this.height);
}

// Set this image to be the same size to the passed in image.
// This image may end up a little bigger than the passed image
// to keep its proportions.
// Useful to set a back image to match the size of the front
// image for bluescreen.
SimpleImage.prototype.setSameSize = function(otherImage) {
  if (!this.width) return;

  var wscale = otherImage.width / this.width;
  var hscale = otherImage.height / this.height;

  var scale = Math.max(wscale, hscale);

  if (scale != 1) {
    this.setSize(this.width * scale, this.height * scale);
  }
}


// Takes on the pixels of the given html image
SimpleImage.prototype.drawFrom = function(htmlImage) {
  // drawImage takes either an htmlImage or a canvas
  this.context.drawImage(htmlImage, 0, 0);
};

// Draws to the given canvas, setting its size.
// Used to implement printing of an image.
SimpleImage.prototype.drawTo = function(toCanvas) {
  if (!this.zoom) {
    toCanvas.width = this.width;
    toCanvas.height = this.height;
  }
  else {
    toCanvas.width = this.width * this.zoom;
    toCanvas.height = this.height * this.zoom;
    toCanvas.zoom = this.zoom;  // record that this was zoomed
  }

  this.flush();
  var toContext = toCanvas.getContext("2d");
  // drawImage() takes either an htmlImg or a canvas
  if (!this.zoom) {
    toContext.drawImage(this.canvas, 0, 0);
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

SimpleImage.prototype.getWidth = function() {
  return this.width;
}

SimpleImage.prototype.getHeight = function() {
  return this.height;
}

// Computes index into 1-d array, and checks correctness of x,y values
SimpleImage.prototype.getIndex = function(x, y) {
  if (x == null || y == null) {
    var e = new Error("need x and y values passed to this function");
    e.inhibitLine = true;
    throw e;
  }
  else if (x < 0 || x >= this.width || y < 0 || y >= this.height) {
    var e = new Error("x/y out of bounds x:" + x + " y:" + y);
    e.inhibitLine = true;
    throw e;
  }
  else return (x + y * this.width) * 4;
}


// --setters--
// Sets the red value for the given x,y
SimpleImage.prototype.setRed = function(x, y, value) {
  funCheck("setRed", 3, arguments.length);
  var index = this.getIndex(x, y);
  this.imageData.data[index] = clamp(value);

  // This is how you would write back each pixel individually.
  // It gives terrible performance (on Firefox anyway).
  // this.context.putImageData(this.imageData, 0, 0, x, y, 1, 1);
  // dx dy dirtyX dirtyY dirtyWidth dirtyHeight
};

// Sets the green value for the given x,y
SimpleImage.prototype.setGreen = function(x, y, value) {
  funCheck("setGreen", 3, arguments.length);
  var index = this.getIndex(x, y);
  this.imageData.data[index + 1] = clamp(value);
};

// Sets the blue value for the given x,y
SimpleImage.prototype.setBlue = function(x, y, value) {
  funCheck("setBlue", 3, arguments.length);
  var index = this.getIndex(x, y);
  this.imageData.data[index + 2] = clamp(value);
};

// Sets the alpha value for the given x,y
SimpleImage.prototype.setAlpha = function(x, y, value) {
  funCheck("setAlpha", 3, arguments.length);
  var index = this.getIndex(x, y);
  this.imageData.data[index + 3] = clamp(value);
};


// --getters--
// Gets the red value for the given x,y
SimpleImage.prototype.getRed = function(x, y) {
  funCheck("getRed", 2, arguments.length);
  var index = this.getIndex(x, y);
  return this.imageData.data[index];
};
// Gets the green value for the given x,y
SimpleImage.prototype.getGreen = function(x, y) {
  funCheck("getGreen", 2, arguments.length);
  var index = this.getIndex(x, y);
  return this.imageData.data[index + 1];
};
// Gets the blue value for the given x,y
SimpleImage.prototype.getBlue = function(x, y) {
  funCheck("getBlue", 2, arguments.length);
  var index = this.getIndex(x, y);
  return this.imageData.data[index + 2];
};
// Gets the blue value for the given x,y
SimpleImage.prototype.getAlpha = function(x, y) {
  funCheck("getAlpha", 2, arguments.length);
  var index = this.getIndex(x, y);
  return this.imageData.data[index + 3];
};

// Gets the pixel object for this x,y. Changes to the
// pixel write back to the image.
SimpleImage.prototype.getPixel = function(x, y) {
  funCheck("getPixel", 2, arguments.length);

  return new SimplePixel(this, x, y);
};


// Pushes any accumulated local changes out to the screen
SimpleImage.prototype.flush = function() {
  this.context.putImageData(this.imageData, 0, 0);  // can omit x/y/width/height and get default behavior
};


// Export an image as an array of pixels for the for-loop.
SimpleImage.prototype.toArray = function() {
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
};


// Wrapper called on the composite by the for(part: composite) sugar, and it does
// some basic error checking.
function getArray(obj) {
  if (obj && typeof(obj) == 'object') {
    if (obj instanceof Array) {
      return obj;
    } else if ('toArray' in obj) {
      return obj.toArray();
    }
  } else {
    throwError("'for (part: composite)' used, but composite is wrong.");
  }
}

// Represents one pixel in a SimpleImage, supports rgb get/set.
SimplePixel = function(simple_image, x, y) {
  this.simple_image = simple_image;
  this.x = x;
  this.y = y;
};


SimplePixel.prototype.simple_image;
SimplePixel.prototype.x;
SimplePixel.prototype.y;

SimplePixel.prototype.getRed = function() {
  funCheck("getRed", 0, arguments.length);
  return this.simple_image.getRed(this.x, this.y);
};
SimplePixel.prototype.setRed = function(val) {
  funCheck("setRed", 1, arguments.length);
  this.simple_image.setRed(this.x, this.y, val);
};
SimplePixel.prototype.getGreen = function() {
  funCheck("getGreen", 0, arguments.length);
  return this.simple_image.getGreen(this.x, this.y);
};
SimplePixel.prototype.setGreen = function(val) {
  funCheck("setGreen", 1, arguments.length);
  this.simple_image.setGreen(this.x, this.y, val);
};
SimplePixel.prototype.getBlue = function() {
  funCheck("getBlue", 0, arguments.length);
  return this.simple_image.getBlue(this.x, this.y);
};
SimplePixel.prototype.setBlue = function(val) {
  funCheck("setBlue", 1, arguments.length);
  this.simple_image.setBlue(this.x, this.y, val);
};

SimplePixel.prototype.getX = function() {
  funCheck("getX", 0, arguments.length);
  return this.x;
};
SimplePixel.prototype.getY = function() {
  funCheck("getY", 0, arguments.length);
  return this.y;
};

// Render pixel as string -- print() uses this
SimplePixel.prototype.getString = function() {
  return "r:" + this.getRed() + " g:" + this.getGreen() + " b:" + this.getBlue();
};


// Given code, return sugared up code, or may throw error.
// expands: for (part: composite) {
function sugarCode(code) {
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
      throwError("Attempt to use 'for(part: composite)' form, but it looks wrong: " + result[0]);
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
    var replacement = "var " + pvar + " = getArray($2); " +
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


// Call this to abort with a message e.g. "Wrong number of arguments to foo()".
// todo: in some cases, this does not show up in the UI, missing the try/catch
// in the evaluate chain for some reason.
function throwError(message) {
    var err = new Error;
    err.message = message;
    err.inhibitLine = true;  // this gets the .message through, but the line number will be wrong
    throw err;
}

// Called from user-facing functions, checks number of arguments.
function funCheck(funName, expectedLen, actualLen) {
  if (expectedLen != actualLen) {
    var s1 = (actualLen == 1)?"":"s";  // pluralize correctly
    var s2 = (expectedLen == 1)?"":"s";
    var message = funName + "() called with " + actualLen + " value" + s1 + ", but expected " +
      expectedLen + " value" + s2 + ".";
    // someday: think about "values" vs. "arguments" here
    // todo: any benefit to throwing an Error here vs. a string?
    throwError(message);
  }
}




// Given code text, scan for image urls so they can be pre-loaded.
// This is a hack, but it mostly works.
// This is called *before* we run the student code, avoiding async image-load problems.
// maybe: could skip commented-out code
// maybe: could be smart about loading something just once, but it's pretty harmless as is.
// function preloadImages(code) {
//   var re = /SimpleImage\(\s*("|')(.*?)("|')\s*\)/g;
//   while (ar = re.exec(code)) {
//     // Used to screen out data: urls here, but that messed up the .loaded attr, strangely
//     var url = ar[2];
//     loadImage(url);
//   }
// }

// 2014
// Returns array of urls to load
function extractImages(code) {
  var re = /SimpleImage\(\s*("|')(.*?)("|')\s*\)/g;
  var result = [];
  while (ar = re.exec(code)) {
    // Used to screen out data: urls here, but that messed up the .loaded attr, strangely
    result.push(ar[2]);
  }
  return result;
}


// Clamp values to be in the range 0..255. Used by setRed() et al.
function clamp(value) {
  // value = Math.floor(value);  // .js is always float, so this line
  // is probably unncessary, unless we get into some deep JIT level.
  if (value < 0) return 0;
  if (value > 255) return 255;
  return value;
}



// Storage
// These silently NOP if localstorage is not available.

// Prefix used under the hood for local storage.
var storeprefix = "cs101.";
// if global var storeinhibit is defined, don't do any storage,
// so the html can block out storage in that way.

// 2014: remove the idea of not storing some things.
// ID's with this pattern saved by the Run button.
// var storeexpattern = ".-ex";

// Stores the text for the given textarea id.
// Does not store if the text area contains only whitespace.
// If the data is "del", stores blank data.
function store(id) {
  // Apparently some windows security settings remove local storage,
  // so you really need to check.
  if (!localStorage) return; // todo: note in the UI the lack of storage
  if (window.storeinhibit) return;

  // 2014
  // if (!id.match(storeexpattern)) return;

  var ta = document.getElementById(id);
  var text = ta.value;
  var trimmed = text.replace(/\s/g,"");  // used for testing, not storage
  if (trimmed.length > 0) {  // detect if this is basically empty data
    if (trimmed == "del") text = "";  // special case to delete
    localStorage.setItem(storeprefix + id, text);
  }
}

// Retrieves and returns the text for the given id.
// Changes null to "", so you get back a string at a minimum.
function retrieve(id) {
  if (!localStorage) return "";
  if (window.storeinhibit) return "";

  var val = localStorage.getItem(storeprefix + id);
  if (!val) val = "";  // todo: what if "0" is stored?
  return val;
}


// Retrieves the localstorage text of all saved exercises.
// Pastes the text into the given outputid if non-null, and also
// returns the text to the caller.
// 2014: if id_re is present, filter ids on that. (experimental, not tested)
// With store() saving everything, maybe need something like this.
function retrieveCodeText(outputid, id_re) {
  if (!localStorage) return;
  if (window.storeinhibit) return;

  var keys = new Array();
  for (var i = 0; i < localStorage.length; i++) {
    var key = localStorage.key(i);
    if (key.indexOf(storeprefix) == 0 && (!id_re || id_re.test(key))) {
      keys.push(key);
    }
  }
  keys.sort();

  var text = "";
  for (var i in keys) {
    var key = keys[i];
    var val = localStorage.getItem(key);
    var keyshort = key.substring(storeprefix.length)
    text = text + "----------\n" + keyshort + "\n\n" + val + "\n";
  }

  if (outputid) {
    var output = document.getElementById(outputid);
    output.innerHTML = "<pre>" + text + "</pre>";
  }

  return text;
}



// 2012
// Variant which takes in list of specific ids to use.
// (probably new homeworks should use this one, maybe remove the other one.)
// if do_sel=true, select the new text (this should just become the default and not a param)
// if do_domain present, warn if the retrieve domain does not match ..
//   students can have problems if on stanford.edu vs. www.stanford.edu
function retrieveCodeTextIds(outputid, ids, do_sel, do_domain) {
  if (!localStorage) return;
  if (window.storeinhibit) return;

  // 2014 -- add a check about the domain
  if (do_domain) {
    var url = document.URL.toLowerCase();
    if (url.indexOf(do_domain.toLowerCase())==-1 && url.indexOf('file:')==-1) {
      alert('Warning: work saving should be on "' + do_domain + '", but this page url is different');
    }
  }
  ids.sort();
  var text = "";
  for (var i in ids) {
    var val = retrieve(ids[i]);
    if (text.length > 0) text += "\n";
    text = text + "----------\n" + ids[i] + "\n\n" + val + "\n";
  }

  if (outputid) {
    var output = document.getElementById(outputid);
    output.innerHTML = "<pre>" + text + "</pre>";
    if (do_sel && window.getSelection) {  // 2014: select the new text
      var range = document.createRange();
      range.selectNode(output);
      window.getSelection().removeAllRanges();
      window.getSelection().addRange(range);
    }
    selectText(outputid);
    // this would work if we had a text-area
    //if (dosel) output.select()  // 2014: select the text: snafu reduce!
  }

  return text;
}



// 2012
// Given code, returns error string or empty string
// Adding more checks here for mistakes students make
// run line "nocodecheck = true;" in user code to inhibit
// these preflight checks
// (setting the global window.nocodecheck variable).
function preflightCheck(code) {
  // 2012-2
  if (window.nocodecheck) return "";

  // 2012-2 allow if (...) { to span lines
  var reIf1 = /^\s*if\s*(.*)$/mg; // initial anchor, m makes ^/$ work per line
  // todo: deal with comments correctly
  // todo: would be nice to also report a line number
  //  return an Error instead of a string

  var result;
  while ((result = reIf1.exec(code)) != null) {
    var line = result[1];
    var check = "";
    var found = "";
    if (line.match(/\{\s*($|\/\/)/)) { // one-line..{ common case
      check = line;
      found = line;
    }
    else {
      // See if there is multi-line ... { text we can check
      // Had problems with .* going in to the weeds, so trying to constrain
      // the check here with the initial anchor. If .. { can span 4 lines here.
      var text = code.substring(result.index);
      var reIf2 = /^\s*if\s*((.*(\r?\n?)){1,3}.*\{\s*($|\/\/))/m;
      if ((result2 = reIf2.exec(text)) != null) {
        //alert(result2[1]);
        check = result2[1];
        found = result2[0];
      }
    }

    // Check the text after the "if " text ends with {\s*$
    if (check) {
      // These error messages go in the output area, so tags work
      if (!check.match(/^\s*\(/)) return "<b>if</b> should be immediately followed by <b>(</b>test<b>)</b> but found:<br>" + found;
      if (!check.match(/\)\s*\{\s*($|\/\/)/)) return "<b>if test</b> should end with <b>)</b> but found:<br>" + found;
      if (check.match(/[^<>=!]\=[^=]/)) return "<b>if test</b> should not contain single = (use == &lt;= &gt;=), but found:<br>" + found;
      if (check.match(/[^&]&[^&]/)) return "<b>if test</b> should not contain single & (use double &&), but found:<br>" + found;
      if (check.match(/[^|]\|[^|]/)) return "<b>if test</b> should not contain single | (use double ||), but found:<br>" + found;
    }
    else {
      // Experiment: flag that we cannot find { within 4 lines of the opening if as
      // an error.
      return "<b>if-statement</b> cannot find end of line <br>left curly brace <b>{</b> <br>Form should be " +
             "<br><b>if (test) {</b><br>&nbsp;..code..<br>but found:" + result[0];  // note using result from initial match.
    }
  }

  // 2012-7 adding ($|\/\/)
  var reFor = /^\s*for\s(.*)$/mg; // m makes ^/$ work per line
  // insist on space after for, so we don't grab every random "for" occurrence
  while ((result = reFor.exec(code)) != null) {
    // have result[0] result[1] groups, result.index index
    var line = result[1];
    if (!line.match(/^\s*\(/)) return "<b>for</b> should be immediately followed by <b>(</b> but found:<br>" + result[0];
    if (!line.match(/\{\s*($|\/\/)/)) return "<b>for</b> line should end with curly brace <b>{</b> but found:<br>" + result[0];
    if (!line.match(/\)\s*\{\s*($|\/\/)/)) return "<b>for</b> should be followed by <b>(</b>part: whole<b>)</b> but found:<br>" + result[0];
  }

  // Function names
  // 2013 todo add: getFields|getRow|getRowCount|getColumnCount| .. prefix issue TBD
  var reFn =  /(getRed|getGreen|getBlue|setRed|setGreen|setBlue|getX|getY|getPixel|setZoom|mimicZoom|setSize|setSameSize|getField|startsWith|endsWith)(.)/g
  var reFnI = /(getRed|getGreen|getBlue|setRed|setGreen|setBlue|getX|getY|getPixel|setZoom|mimicZoom|setSize|setSameSize|getField|startsWith|endsWith)(.)/gi
  // omitting "print" as too easily could appear in a string

  // Check for off by capitalization
  while ((result = reFnI.exec(code)) != null) {
    if (!result[0].match(reFn)) {
      return "<b>" + result[1] + "</b> appears to have some wrong capitalization";
    }
  }

  // Have fn names ... look for (
  // Using pixel.getRed as an rvalue .. hard for them to debug
  while ((result = reFn.exec(code)) != null) {
    // have result[0] result[1] groups, result.index index
    var paren = result[2];
    if (paren != "(") {
      return "<b>" + result[1] + "</b> should be immediately followed by <b>(</b>"
    }
  }
  return "";
}


/*
// We don't do this any more
function checkFirefox() {
  if (navigator.userAgent.indexOf("Firefox") == -1) {
    var warn = document.getElementById("warning-output");
    warn.innerHTML = "<font color=red>Warning: this page only works with the latest Firefox. " +
      "This will be fixed ultimately, but for now the limitation is real.</font>";
  }
}
*/

// Hide the first thing, unhide the thing following it.
// Used to make the litttle solution-show buttons in the html.
function unhide(first) {
  first.style.display = "none";
  first.nextElementSibling.style.display = "block";
}



// 2014 - diff experiments
// Given the student and ans data arrays, compute per-pixel diff number.
function imageDiff(studentData, ansData) {
  if (studentData.length != ansData.length) throw("image array lengths don't match " + studentData.length + " " + ansData.length);

  var diff = 0;
  // Debugging text to show per-pixel differences R G B
  //var printed = 0;
  //var s = "";
  for (var i = 0; i < studentData.length; i+=4) {
      diff += Math.abs(studentData[i] - ansData[i]);  // R
      diff += Math.abs(studentData[i + 1] - ansData[i + 1]);  // G
      diff += Math.abs(studentData[i + 2] - ansData[i + 2]);  // B

      //if (printed < 40 && i % 21110 == 0) {
      //  s += studentData[i] + " " + ansData[i] + " " + studentData[i+1] + " " + ansData[i+1] + " " +
      //    studentData[i+2] + " " + ansData[i+2] + ", ";
      //  printed++;
      //}
  }
  diff = diff / (studentData.length/4.0);  // error-per-pixel
  //print("diff", diff);
  //print(s);
  return diff;
}


function refAvg(name) {
  var refImage = new SimpleImage(name);
  var data = refImage.imageData.data;
  var r = 0;
  var g = 0;
  var b = 0;
  for (var i = 0; i < data.length; i+=4) {
      r += data[i];
      g += data[i+1];
      b += data[i+2];
  }
  var len = data.length/4.0;
  return [r/len, g/len, b/len];
}



// called  the block calling student-eval
// function postShow(idsoln) {
//   try {
//
//     var studentCanvas = window.globalLastCanvas;
//     if (!studentCanvas) {
//       print("no student canvas");
//       return;
//     }
//
//     var studentData = studentCanvas.getContext("2d")
//         .getImageData(0, 0, studentCanvas.width, studentCanvas.height).data;
//
//     if (!window.globalSolnName) {
//       print("no globalSolnName");
//       return;
//     }
//     var ansImage = new SimpleImage(window.globalSolnName);
//     var ansData = ansImage.imageData.data;
//
//     print(imageDiff(studentData, ansData));
//
//   }
//   catch (e) {
//     // If an error occured during image comparison, just fail silently
//     // Most likely the image needs to be reloaded. Otherwise, there's
//     // nothing much we can do anyway.
//     print(e);  // todo: not sure what to do there
//     console.log(e);
//   }
// }





// edx-mod
//window.globalPathPrefix = "/c4x/Engineering/CS101/asset/";
//window.globalPathPrefix = "/c4x/NickX/CSTEST101/asset/";
//window.globalPathPrefix = "/c4x/Strader/101/asset/";
//window.globalPathPrefix = "/c4x/edX/DemoX/asset/";

// OLI - 'notready' return cases for grading, see 'OLI' above
// OLI mod - TODO need a better way to manage this
window.globalPathPrefix = "/c4x/OLI/CS101/asset/";

