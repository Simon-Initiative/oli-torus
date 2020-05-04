// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"

//import css from "../css/app.css"

import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"

import { Socket } from "phoenix"
import LiveSocket from "phoenix_live_view"

let lastX = null;
let lastY = null;
let moving = false;
let currentX = null;
let currentY = null;

let Hooks = {};
Hooks.GraphNavigation = {
  updated() {
    if (currentX != null) {
      document.getElementById("panner")
        .setAttribute('transform',"translate(" + currentX + "," + currentY + ") scale(1.0)");
    }
  },
  mounted() {
    this.el.addEventListener("mousemove", e => {

      if (moving) {

        if (lastX != null) {
          const diffX = lastX - e.clientX;
          const diffY = lastY - e.clientY;
          currentX -= diffX;
          currentY -= diffY;

          document.getElementById("panner")
            .setAttribute('transform',"translate(" + currentX + "," + currentY + ") scale(1.0)");

        }
        lastX = e.clientX;
        lastY = e.clientY;
      }
    });
    this.el.addEventListener("mousedown", e => {
      this.el.style = "cursor: grabbing;";
      moving = true;
    });
    this.el.addEventListener("mouseup", e => {
      this.el.style = "cursor: grab;";
      moving = false;
      lastX = null;
      lastY = null;
    });

  }
};


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: { _csrf_token: csrfToken } });
liveSocket.connect();

$(function () {
  $('[data-toggle="popover"]').popover();
  $('[data-toggle="tooltip"]').tooltip();
});

$(document).ready(function(){
    $('.ui.dropdown').dropdown();
    $('.ui.dropdown.item').dropdown();
});