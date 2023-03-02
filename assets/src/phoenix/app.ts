import { selectCookieConsent } from 'components/cookies/CookieConsent';
import { selectCookiePreferences } from 'components/cookies/CookiePreferences';
import { retrieveCookies } from 'components/cookies/utils';
import { CreateAccountPopup } from 'components/messages/CreateAccountPopup';
import { Hooks } from 'hooks';
import NProgress from 'nprogress';
import { Socket } from 'phoenix';
import 'phoenix_html';
import { LiveSocket } from 'phoenix_live_view';
import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { initActivityBridge, initPreviewActivityBridge } from './activity_bridge';
import { showModal } from './modal';
import { enableSubmitWhenTitleMatches } from './package_delete';
import { onReady } from './ready';
import 'react-phoenix';
import { finalize } from './finalize';
import { commandButtonClicked } from '../components/editing/elements/command_button/commandButtonClicked';

import {
  Button,
  Dropdown,
  Collapse,
  Offcanvas,
  Alert,
  Carousel,
  Modal,
  Popover,
  ScrollSpy,
  Tab,
  Tooltip,
  Toast,
} from 'bootstrap';

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

// Global functions and objects:
window.OLI = {
  initActivityBridge,
  initPreviewActivityBridge,
  showModal,
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

$(() => {
  $('[data-action="command-button"]').on('click', commandButtonClicked);

  (window as any).hljs.highlightAll();
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

declare global {
  interface Window {
    liveSocket: typeof liveSocket;
    toggleAudio: (element: HTMLAudioElement) => void;
    OLI: {
      initActivityBridge: typeof initActivityBridge;
      initPreviewActivityBridge: typeof initPreviewActivityBridge;
      showModal: typeof showModal;
      enableSubmitWhenTitleMatches: typeof enableSubmitWhenTitleMatches;
      selectCookieConsent: typeof selectCookieConsent;
      selectCookiePreferences: typeof selectCookiePreferences;
      retrieveCookies: typeof retrieveCookies;
      onReady: typeof onReady;
      finalize: typeof finalize;
      CreateAccountPopup: (node: any, props: any) => void;
    };
    keepAlive: () => void;
  }
}
