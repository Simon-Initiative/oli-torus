// Executes a function after the DOM content has loaded on a page. This
// implementation was lifted from jQuery's impl.
export function onReady(func: () => void) : void {

  function completed() {
    document.removeEventListener("DOMContentLoaded", completed);
    window.removeEventListener("load", completed);
    func();
  }

  // Catch cases where onReady is called
  // after the browser event has already occurred.
  if (document.readyState !== "loading") {

    // Handle it asynchronously to allow scripts the opportunity to delay ready
    window.setTimeout(func, 0);

  } else {

    // Use the handy event callback
    document.addEventListener("DOMContentLoaded", completed);

    // A fallback to window.onload, that will always work
    window.addEventListener("load", completed);
  }
}
