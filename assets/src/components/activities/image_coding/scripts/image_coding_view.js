/* Javascript for cs101XBlock. */
function ImageCodingXBlockInitView(runtime, element) {
    var submitUrl = runtime.handlerUrl(element, 'student_submit');
    var hintUrl = runtime.handlerUrl(element, 'handle_hint');
    var resetUrl = runtime.handlerUrl(element, 'handle_reset');
    var publishUrl = runtime.handlerUrl(element, 'publish_event');
    window.globalpublishurl = publishUrl;

    var $element = $(element);

    var submit_button = $element.find('.submit_button');
    var hint_button = $element.find('hint_button');
    var reset_button = $element.find('.reset_button');

    var unanswered = $element.find('.unanswered');
    var correct = $element.find('.correct');
    var incorrect = $element.find('.incorrect');

    var correct_feedback = $element.find('.correct_feedback');

    var hint_div = $element.find('.hint');

    var hint_counter = 0;
    var student_code = "";
    var studentarea = $element.find('.student_code')[0];

    var hint;
    var hints;
    var hint_counter = 0;

    function publish_event(data) {
      $.ajax({
          type: "POST",
          url: publishUrl,
          data: JSON.stringify(data)
      });
    }


    // AJAX callback to set hint
    function set_hint(result) {
        hint_div.css('display','inline');
        hint_div.html(result.hint);
        hint_div.attr('hint_index', result.hint_index);
    }

    // AJAX callback to do "reset" of starter code
    function set_reset(result) {
        show_correctness('unanswered');
        $('.student_code',element).val(result.starter_code);
    }

    // Change the red/green grading state css: correct, incorrect, unanswered
    function show_correctness(state) {
      correct.css('display', 'none');
      incorrect.css('display', 'none');
      unanswered.css('display', 'none');

      if (state == 'correct') correct.css('display', 'block');
      else if (state == 'incorrect') incorrect.css('display', 'block');
      else unanswered.css('display', 'block');
    }

    // Does nothing
    function post_submit(result) {
    }


    $('.submit_button', element).click(function(eventObject) {
        // First run the grading
        var report = null;
        try {  // TODO evaluateGrade should not throw normally now
            var id = $(this).parent().parent().parent().find('.student_code')[0].id;
            report = evaluateGradeOLI(id);
        }
        catch (e) {
            if (window.console) console.log('ERROR is submit grading:' + e);
            report = {'error': 'internal-error:' + e, 'grade':''};
        }

        // We AJAX save both their data and the correctness
        $.ajax({
            type: 'POST',
            url: submitUrl,
            data: JSON.stringify({'student_code': $('.student_code',element).val(), 'report': report }),
            success: post_submit
        });

        if (report['error'] == 'notready') {
            alert('Please Run first to produce output, then try Submit');
        }

        correct_bool = (report['grade'] != undefined && report['grade']);  // bool for UI purposes
        if (correct_bool) {
            show_correctness('correct');
        } else {
            show_correctness('incorrect');
        }
    });


    // Detect key presses, so we can blank out the grading when they start editing
    $('.student_code', element).keypress(function(event) {
        show_correctness('');
        return handleCR(studentarea, event);
    });
    $('.student_code', element).keydown(function(event) {  // need this one just for del key
        if (event.keyCode == 8) show_correctness('');
    });

    $('.run_button', element).click(function(eventObject) {
        // "this" is the input element, so we jquery from there to find the correct textarea
        var id = $(this).parent().parent().find('.student_code')[0].id;
        evaluateClearOLI(id);
    });

    // Implement hint-click: message the server to get each hint
    $('.hint_button', element).click(function(eventObject) {
        var next_index, hint_index = hint_div.attr('hint_index');
        if (hint_index == undefined) {
            next_index = 0;
        }
        else {
            next_index = parseInt(hint_index) + 1;
        }
        $.ajax({
        type: 'POST',
        url: hintUrl,
        data: JSON.stringify({'hint_index': next_index}),
        success: set_hint
        });
    });

    $('.reset_button', element).click(function(eventObject) {
        $.ajax({
        type: 'POST',
        url: resetUrl,
        data: JSON.stringify({'hint_index': 0}),
        success: set_reset
        });
    });


    // Startup logic
    show_correctness(submit_button.attr('stored_correctness'));

}



// CS101 - OLI layer

// Versions for OLI, these all go together, replacing the top level functions in cs101-edx.js
// but using the lower level stuff.


// Top level -- call this to blank out and eval a problem.
// Called by the Run button
function evaluateClearOLI(id) {
  //store(id);

  window.globalRunId = id;  // hack: set state used by printing
  window.globalLastCanvas = null;  // regular canvas
  window.globalLastCanvas2 = null;  // soln canvas
  window.globalSolnName = null;  // this is maybe not used
  window.globalSolnRun = false;  // marker of regular/soln run
  window.globalPrintText = "";
  window.globalImageLoadError = null;  // OLI

  clearOutput();

  var ta = document.getElementById(id);
  var text = ta.value;
  var images = extractImages(text);

  window.globalImageNeeded = images.length;
  window.globalImageCount = 0;
  window.globalImageFn = function() { evaluateShowOLI(id); };

  setTimeout(function() { preloadImages(images); }, 100);
}

// Called after image load to run student code
// After student run, we silently call grading to log where they are
function evaluateShowOLI(inID) {
  // This is stock
  var logMsg = '';
  var ta = document.getElementById(inID);

  if (window.globalImageLoadError) {  // OLI sort of error, pre-evaluation
      logMsg = '<font color=red>' + window.globalImageLoadError + '</font>';
      print(logMsg);
  }
  else try {
    var e = evaluate(inID);
    if (e != null) {
      logMsg = e.message;
      var msg = "<font color=red>Error:</font>" + e.message;  // 2012-2 don't make the whole thing red
      if (e.userLine) msg += " line:" + e.userLine;
      print(msg);
      if (e.userLine) {
        logMsg += " line:" + e.userLine;

        selectLine(ta, e.userLine);
      }
    }
  }
  catch (e) {
    alert("Low level evaluation error:" + e);
  }

  if (logMsg) {
    runReport({'error':logMsg, 'grade':''}, ta.value);
  }
  else {
    // OLI add - run this from event loop
    setTimeout(function() { postRunOLI(inID, ta.value); }, 10);
  }
}


// Log report data to the server for "run" case
function runReport(report, code) {
  var log = {'mode':'run', 'report':report, 'student_code':code};
  $.ajax({
    type: "POST",
    url: window.globalpublishurl,  // TODO hack smuggling this url out .. could move into the block above
    data: JSON.stringify(log)
  });
}


// Run the grade layer and log results
function postRunOLI(id, code) {
  var report = evaluateGradeOLI(id);
  runReport(report, code);
}


// OLI variant, no localtest arg
// Lowest level run/grader, uses previous student run state
// return dict with both {'error': xx, 'grade': xx } and one of xx will be blank
function evaluateGradeOLI(id) {
  // Check for re attribute - regex grading
  var ta = document.getElementById(id);
  var re = ta.getAttribute('re');
  if (re) {
    if (!window.globalPrintText) {
      return({'error': 'notready', 'grade':''});
    }

    re = unescape(re.replace(new RegExp('\\\\', 'g'), '%'))
    var regex = new RegExp(re, "g");
    var grade = window.globalPrintText.search(regex) > -1;
    return ({'error':'', 'grade':grade});
  }

  // pre-flight for the image-grading case
  if (!window.globalLastCanvas) {
    return ({'error': 'notready', 'grade':''});
  }

  window.globalRunId = id;  // hack: set state used by printing
  window.globalPrintCount = 5000;

  // soln specific
  window.globalLastCanvas2 = null;  // soln canvas (clear this, but not student canvas)
  window.globalSolnRun = true;  // mark that this is the soln run


  var text = getSolnText(id);

  // Issue: what if the soln code and the student code use different images?
  // Simple: we check that all the solution images are in cache, fail if not
  var images = extractImages(text);
  var imageErr = null;
  for (var i=0; i<images.length; i++) {
    if (!getImageBySrc(images[i])) {
      return({'error': 'soln-image-not-loaded', 'grade': ''});
    }
  }
  try {
    eval(text);
  }
  catch(e) {
    if (window.console) console.log('soln-eval-error:' + e);
    return ({'error': 'soln-eval-error', 'grade':''});
  }

  var diff = graderingOLI();

  if (diff == 'error') {
    return {'error': 'image-diff-error', 'grade':''};
  }

  var tol = ta.getAttribute('tol');
  if (!tol) tol = 1.0;
  var grade = (diff <= tol);
  return {'error':'', 'grade':grade};
}


// Computes and returns the image diff number, or 'error' for error.
function graderingOLI() {
  var studentCanvas = window.globalLastCanvas;
  if (!studentCanvas) {
    return('error');
  }

  var solnCanvas = window.globalLastCanvas2;
  if (!solnCanvas) {
    return('error');
  }

  var studentData = studentCanvas.getContext("2d")
      .getImageData(0, 0, studentCanvas.width, studentCanvas.height).data;

  var solnData = solnCanvas.getContext("2d")
      .getImageData(0, 0, solnCanvas.width, solnCanvas.height).data;

  return(imageDiff(studentData, solnData));
}
