// citb-table.js supports table-data.
// Code In The Browser .js -- see http://codeinthebrowser.org
// Created by Nick Parlante
// This code is released under the Apache 2.0 license
// http://www.apache.org/licenses/LICENSE-2.0

// Given same-origin file, return its text contents.
function readFile(filename) {
  var client = new XMLHttpRequest();
  var async = false;  // made async work, but sync seems better for this purpose.
  if (window.globalPathPrefix) {
    filename = window.globalPathPrefix + filename;
  }
  client.open("GET", filename, async); // false=sync
  
  // This is firefox only. It is necessary for the file: case, seemingly
  // due to a firefox bug in that case where it barfs on non-xml data
  // by trying to parse it.
  if (client.overrideMimeType) {
    client.overrideMimeType('text/plain');  // ;charset=UTF-8
  }
  
  client.send(null);
  return client.responseText;
}

/*
function RowString(val) {
  this.val = val;
    this.length = (this.__value__ = __value__ || "").length;
}

with(RowString.prototype = new String) {
  toString = valueOf = function() {return this.val};
  startsWith = function(s) {
}
*/

// Adding startsWith and endsWith to the String class -- these are badly needed
// by the baby data.

if (!String.prototype.startsWith){
  String.prototype.startsWith = function (str) {
    return (this.lastIndexOf(str, 0) == 0);  // using lastIndex avoids searching the whole string.
  }
}

if (!String.prototype.endsWith){
  String.prototype.endsWith = function (str) {
    var index = this.length - str.length;
    if (index < 0) return false;
    return (this.indexOf(str, index) != -1);
  }
}


// Given a text line, explode the CSV and return an array elements.
// Columns is the expected number of columns to fill out to, or 0 to ignore.
// Returns null on empty string, as you might see with a blank line.
// The elements are whitespace trimmed.
// Can make this more sophisticated about CSV format later.
function splitCSV(line, columns) {
  line = line.replace(/^\s+|\s+$/g,'');  // .trim() effectively, and below
  if (line == '') return null;
  
  var parts = line.split(/,/, -1);
  for (var i in parts) {
    parts[i] = parts[i].replace(/^\s+|\s+$/g,'');
  }
  
  // hack: file can omit blank data from RHS .. add it back on
  while (columns && parts.length < columns) {
    parts.push("");
  }
  return parts;
}



Row = function(table, rowArray) {
  this.table = table;
  this.array = rowArray;
}

Row.prototype.table;
Row.prototype.array;

// Returns the nth value from this row.
Row.prototype.getColumn = function(n) {
  // todo: could do bounds checking here to be more friendly
  return this.array[n];
};

// Returns the value for the named field.
Row.prototype.getField = function(fieldName) {
  var index = this.table.getFieldIndex(fieldName);
  if (index == -1) {
    // 2012-2 throw error in this case
    var err = new Error;
    err.message = "getField() unknown field name: <b>" + fieldName + "</b>";
    err.inhibitLine = true;
    throw(err);
    //return "Bad field name:" + fieldName;
  }
  return this.array[index];
};

// Returns the raw array; used for printing.
Row.prototype.getArray = function() {
  return this.array;
};


// Returns a pretty string form.
Row.prototype.getString = function() {
  //var result = "";
  // this version included field: labels within the data
  //var fields = this.table.getFields();
  //for (var i in fields) {
  //  result = result + fields[i] + ":" + this.array[i] + " ";
  //}
  //return result;
  return this.array.join(", ");
};




// Creates a new table with the given file (or aux text).
SimpleTable = function(filename) {
  var text;
  // Get the text, either from URL or from "aux" area
  if (isAuxUrl(filename)) {
    // trim off .csv
    if (filename.lastIndexOf(".csv") != -1) {
      filename = filename.substring(0, filename.lastIndexOf(".csv"));
    }
    var ta = document.getElementById(filename);
    // todo: better error message for bad filename (easy user typo)
    text = ta.value; // todo: trim needed here?
  }
  else {
    text = readFile(filename);
  }

  var lines = text.split(/\n|\r\n/);  // test: this does work with DOS line endings
  
  // todo: could have some logic about if the first row is the field names or not
  this.fields = splitCSV(lines[0]);
  lines.splice(0, 1);  // remove 0th element

  var rows = new Array();
  for (i in lines) {
    var parts = splitCSV(lines[i], this.fields.length);
    if (parts != null) {  // essentially we skip blank lines
      rows.push(new Row(this, parts));
    }
  }
  this.rows = rows;
}

SimpleTable.prototype.fields;
SimpleTable.prototype.rows;

// Returns the number of columns.
SimpleTable.prototype.getColumnCount = function() {
  return this.fields.length;
};

// Returns an array of the field names.
SimpleTable.prototype.getFields = function() {
  return this.fields;
};


// Limits the table to just n rows.
SimpleTable.prototype.limitRows = function(n) {
  this.rows.splice(n, this.rows.length-n);
};

// Returns the index for a field name (case sensitive).
// Used internally by row.getField()
SimpleTable.prototype.getFieldIndex = function(fieldName) {
  for (var i in this.fields) {
    if (this.fields[i] == fieldName) return i;
  }
  return -1;  // todo: could throw or something here
};

// Returns the number of rows.
SimpleTable.prototype.getRowCount = function() {
  return this.rows.length;
};

// Returns the nth row.
SimpleTable.prototype.getRow = function(n) {
  if (n < 0 || n >= this.rows.length) {
    throw "Count of rows is " + this.rows.length + ", but attempting to get row:" + n;
  }
  return this.rows[n];
};

// Summer
// toArray() adapter so for (part: composite) works.
// In this case, we just return the internal array of row objects.
SimpleTable.prototype.toArray = function() {
  return this.rows;
};

// Change the string contents of array to lowercase.
// Returns the array also.
function lowerCaseArray(a) {
  for (var i = 0; i < a.length; i++) {
    a[i] = a[i].toLowerCase();
  }
}

// Change all the text (field names and data) all to lower case.
SimpleTable.prototype.convertToLowerCase = function() {
  lowerCaseArray(this.fields);
  for (var i = 0; i < this.rows.length; i++) {
    lowerCaseArray(this.rows[i].array);
  }
};



