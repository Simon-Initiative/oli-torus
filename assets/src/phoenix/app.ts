import * as React from 'react';
import * as ReactDOM from 'react-dom';
import 'react-phoenix';
import {
  Alert,
  Button,
  Carousel,
  Collapse,
  Dropdown,
  Modal,
  Offcanvas,
  Popover,
  ScrollSpy,
  Tab,
  Toast,
  Tooltip,
} from 'bootstrap';
import { Hooks } from 'hooks';
import NProgress from 'nprogress';
import { Socket } from 'phoenix';
import 'phoenix_html';
import { LiveSocket } from 'phoenix_live_view';
import { selectCookieConsent } from 'components/cookies/CookieConsent';
import { selectCookiePreferences } from 'components/cookies/CookiePreferences';
import { retrieveCookies } from 'components/cookies/utils';
import { CreateAccountPopup } from 'components/messages/CreateAccountPopup';
import { commandButtonClicked } from '../components/editing/elements/command_button/commandButtonClicked';
import { initActivityBridge, initPreviewActivityBridge } from './activity_bridge';
import { finalize } from './finalize';
import { showModal } from './modal';
import { enableSubmitWhenTitleMatches } from './package_delete';
import { onReady } from './ready';

(window as any).Alert = Alert;
(window as any).Button = Button;
(window as any).Dropdown = Dropdown;
(window as any).Carousel = Carousel;
(window as any).Collapse = Collapse;
(window as any).Offcanvas = Offcanvas;
(window as any).Modal = Modal;
(window as any).Popover = Popover;
(window as any).ScrollSpy = ScrollSpy;
(window as any).Tab = Tab;
(window as any).Toast = Toast;
(window as any).Tooltip = Tooltip;

const csrfToken = (document as any)
  .querySelector('meta[name="csrf-token"]')
  .getAttribute('content');
const liveSocket = new LiveSocket('/live', Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
  timeout: 60000,
  metadata: {
    keydown: (e: any, _el: any) => {
      return {
        key: e.key,
        shiftKey: e.shiftKey,
      };
    },
  },
});

// Show progress bar on live navigation and form submits
// this only shows the topbar if it's taking longer than 200 msec to receive the phx:page-loading-stop event
let topBarScheduled: NodeJS.Timeout | undefined;
NProgress.configure({ showSpinner: false });

window.addEventListener('phx:page-loading-start', () => {
  if (!topBarScheduled) {
    topBarScheduled = setTimeout(() => NProgress.start(), 200);
  }
});
window.addEventListener('phx:page-loading-stop', () => {
  topBarScheduled && clearTimeout(topBarScheduled);
  topBarScheduled = undefined;
  NProgress.done();
});

// Expose React/Redux APIs to server-side rendered templates
function mount(Component: any, element: HTMLElement, context: any = {}) {
  ReactDOM.render(React.createElement(Component, context), element);
}

function openModal(id: string) {
  document.getElementById(id)?.classList.remove('hidden');
}

function closeModal(id: string) {
  document.getElementById(id)?.classList.add('hidden');
}

const confirmAction = (title: string, message: string, okCallback: () => void, cancelCallback: () => void, okLabel = 'Ok') => {

  const modalTitle = document.getElementById('modalTitle')
  const modalBody = document.getElementById('modalMessage')
  const modalOkButton = document.getElementById('modalOk')
  const modalCancelButton = document.getElementById('modalCancel')

  if (modalTitle && modalBody && modalOkButton && modalCancelButton) {

    modalTitle.innerHTML = title;
    modalBody.innerHTML = message;
    modalOkButton.innerHTML = okLabel;
    modalOkButton.onclick = () => {
      closeModal('modalConfirm');
      okCallback();
    };
    modalCancelButton.onclick = () => {
      closeModal('modalConfirm');
      cancelCallback();
    };

    openModal('modalConfirm');
  }

}

// Global functions and objects:
window.OLI = {
  initActivityBridge,
  initPreviewActivityBridge,
  showModal,
  confirmAction,
  enableSubmitWhenTitleMatches,
  selectCookieConsent,
  selectCookiePreferences,
  retrieveCookies,
  onReady,
  finalize,
  CreateAccountPopup: (node: any, props: any) => mount(CreateAccountPopup, node, props),
};

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket;

document.addEventListener('DOMContentLoaded', () => {
  // initialize popover elements
  [].slice
    .call(document.querySelectorAll('[data-bs-toggle="popover"]'))
    .map((el: HTMLElement) => new Popover(el));

  // initialize tooltip elements
  [].slice
    .call(document.querySelectorAll('[data-bs-toggle="tooltip"]'))
    .map((el: HTMLElement) => new Tooltip(el));

  // initialize command button elements
  $('[data-action="command-button"]').on('click', commandButtonClicked);

  // handle direct tab routing via url hash
  if (location.hash !== '') {
    // make tabs navigable by their link's href
    [].slice
      .call(document.querySelectorAll('a[data-bs-toggle="tab"][href="' + location.hash + '"]'))
      .map((el: HTMLElement) => new Tab(el).show());
  }

  // change the url hash when a new tab is selected
  [].slice.call(document.querySelectorAll('a[data-bs-toggle="tab"]')).map((el: HTMLElement) =>
    el.addEventListener('show.bs.tab', (e: any) => {
      return (location.hash = e.target?.getAttribute('href').substr(1));
    }),
  );

  const hljs = (window as any).hljs;

  hljs.configure({
    cssSelector: 'pre code.torus-code',
  });

  hljs.highlightAll();
});

let currentlyPlaying: HTMLAudioElement | null = null;

window.toggleAudio = (element: HTMLAudioElement) => {
  if (!element) return;

  if (currentlyPlaying && currentlyPlaying !== element) {
    currentlyPlaying.pause();
  }

  if (element.paused) {
    currentlyPlaying = element;
    element.currentTime = 0;
    element.play();
  } else {
    element.pause();
  }
};

window.addEventListener('phx:js-exec', ({ detail }: any) => {
  document.querySelectorAll(detail.to).forEach((el) => {
    liveSocket.execJS(el, el.getAttribute(detail.attr));
  });
});

window.addEventListener('mouseover', (e: any) => {
  // if the event's target has the xphx-mouseover attribute,
  // execute the commands on that element
  if (e.target.matches('[xphx-mouseover]')) {
    liveSocket.execJS(e.target, e.target.getAttribute('xphx-mouseover'));
  }
});

window.addEventListener('mouseout', (e: any) => {
  // if the event's target has the xphx-mouseout attribute,
  // execute the commands on that element
  if (e.target.matches('[xphx-mouseout]')) {
    liveSocket.execJS(e.target, e.target.getAttribute('xphx-mouseout'));
  }
});


declare global {
  interface Window {
    liveSocket: typeof liveSocket;
    toggleAudio: (element: HTMLAudioElement) => void;
    OLI: {
      initActivityBridge: typeof initActivityBridge;
      initPreviewActivityBridge: typeof initPreviewActivityBridge;
      showModal: typeof showModal;
      confirmAction: typeof confirmAction;
      enableSubmitWhenTitleMatches: typeof enableSubmitWhenTitleMatches;
      selectCookieConsent: typeof selectCookieConsent;
      selectCookiePreferences: typeof selectCookiePreferences;
      retrieveCookies: typeof retrieveCookies;
      onReady: typeof onReady;
      finalize: typeof finalize;
      CreateAccountPopup: (node: any, props: any) => void;
    };
  }
}

export { liveSocket };
