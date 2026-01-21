import { Socket } from 'phoenix';

const BOTTOM_THRESHOLD_PX = 16;

type ChunkLog = {
  id: number;
  ordinal: number;
  chunk_index: string;
  query_id?: string | null;
  rows?: number | null;
  rows_written?: number | null;
  rows_read?: number | null;
  bytes?: number | null;
  bytes_written?: number | null;
  bytes_read?: number | null;
  execution_time_ms?: number | null;
  source_url?: string | null;
  dry_run?: boolean;
  inserted_at?: string | null;
};

type ChunkLogsPayload = {
  batch_id: number;
  offset: number;
  total: number | null;
  direction: 'next' | 'previous' | 'refresh' | 'latest';
  has_more: boolean;
  logs: ChunkLog[];
};

type PendingDirection = 'next' | 'previous';

type PersistedState = {
  open?: boolean;
  live?: boolean;
};

const globalStateKey = '__chunkLogsState';
const globalStateContainer = window as unknown as {
  [globalStateKey]?: Record<number, PersistedState>;
};

const persistedState =
  globalStateContainer[globalStateKey] ??
  (globalStateContainer[globalStateKey] = Object.create(null));

let sharedSocket: any = null;
let sharedSocketToken: string | null | undefined;

function getSocket(token?: string | null) {
  if (sharedSocket && sharedSocketToken === token) {
    return sharedSocket;
  }

  if (sharedSocket) {
    sharedSocket.disconnect();
  }

  const socket = new Socket('/v1/api/state', { params: { token } });
  socket.connect();
  sharedSocket = socket;
  sharedSocketToken = token;
  return socket;
}

function parseNumber(value: string | undefined, fallback: number) {
  if (!value) return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
}

const formatNumber = new Intl.NumberFormat(undefined, { maximumFractionDigits: 0 });

export const ChunkLogsViewer = {
  mounted() {
    this.batchId = parseNumber(this.el.dataset.batchId, 0);
    this.limit = parseNumber(this.el.dataset.limit, 10);
    this.maxWindow = parseNumber(this.el.dataset.window, 200);
    this.defaultLive = this.el.dataset.defaultLive === '1';
    this.userToken = this.el.dataset.userToken || (window as any).userToken || null;

    this.state = {
      initialized: false,
      offset: 0,
      count: 0,
      total: parseNumber(this.el.dataset.initialCount, 0),
      loadingNext: false,
      loadingPrev: false,
      loadingLatest: false,
      hasMoreForward: false,
      hasMoreBackward: false,
      liveEnabled: false,
      autoDisabledByScroll: false,
      autoLiveAllowed: true,
      suppressScroll: false,
      channelReady: false,
    };

    this.scrollEl = this.el.querySelector('.chunk-logs-scroll') as HTMLElement | null;
    this.bodyEl = this.el.querySelector('.chunk-logs-body') as HTMLElement | null;
    this.bottomSentinel = this.el.querySelector(
      '.chunk-logs-bottom-sentinel',
    ) as HTMLElement | null;
    this.topSentinel = this.el.querySelector('.chunk-logs-top-sentinel') as HTMLElement | null;
    this.statusEl = this.el.querySelector('.chunk-logs-status') as HTMLElement | null;
    this.liveToggleEl = this.el.querySelector('.chunk-logs-live-toggle') as HTMLInputElement | null;

    this.handleServerUpdate = this.handleServerUpdate.bind(this);
    this.handleNewLogs = this.handleNewLogs.bind(this);
    this.handleToggle = this.handleToggle.bind(this);
    this.handleBottomIntersect = this.handleBottomIntersect.bind(this);
    this.handleTopIntersect = this.handleTopIntersect.bind(this);
    this.handleScroll = this.handleScroll.bind(this);

    if (this.scrollEl) {
      this.scrollEl.addEventListener('scroll', this.handleScroll);
    }

    const details = this.el.closest('details');
    this.detailsEl = details;

    if (details) {
      details.addEventListener('toggle', this.handleToggle);
      if (details.open) {
        this.initialize();
      }
    } else {
      this.initialize();
    }

    this.initializeLiveToggle();
  },

  destroyed() {
    if (this.detailsEl) {
      this.detailsEl.removeEventListener('toggle', this.handleToggle);
    }

    if (this.scrollEl) {
      this.scrollEl.removeEventListener('scroll', this.handleScroll);
    }

    if (this.bottomObserver) {
      this.bottomObserver.disconnect();
    }

    if (this.topObserver) {
      this.topObserver.disconnect();
    }

    if (this.channel) {
      this.channel.off('new_logs', this.handleNewLogs);
      this.channel.leave();
      this.channel = undefined;
    }

    if (this.liveToggleEl && this.handleLiveToggleChange) {
      this.liveToggleEl.removeEventListener('change', this.handleLiveToggleChange);
    }
  },

  handleToggle(event: Event) {
    const target = event.target as HTMLDetailsElement;
    if (target?.open) {
      this.initialize();

      if (this.state.autoDisabledByScroll && this.state.autoLiveAllowed) {
        this.state.autoDisabledByScroll = false;
        this.setLiveUpdate(true, { persist: false });
      }

      if (this.state.liveEnabled) {
        this.loadLatest();
      }
    } else {
      this.state.autoDisabledByScroll = false;
    }
  },

  initialize() {
    if (this.state.initialized || !this.scrollEl || !this.bodyEl || this.batchId <= 0) return;
    if (!this.userToken) {
      this.showStatus('Authentication required to load chunk logs.');
      return;
    }
    this.state.initialized = true;

    this.bottomObserver = new IntersectionObserver(this.handleBottomIntersect, {
      root: this.scrollEl,
      threshold: 0.1,
    });

    this.topObserver = new IntersectionObserver(this.handleTopIntersect, {
      root: this.scrollEl,
      threshold: 0.1,
    });

    if (this.bottomSentinel) this.bottomObserver.observe(this.bottomSentinel);
    if (this.topSentinel) this.topObserver.observe(this.topSentinel);

    this.joinChannel();
  },

  joinChannel() {
    const socket = getSocket(this.userToken);
    this.channel = socket.channel(`clickhouse_chunk_logs:${this.batchId}`, {
      limit: this.limit,
    });

    this.channel
      .join()
      .receive('ok', (payload: ChunkLogsPayload & { has_more: boolean }) => {
        this.state.channelReady = true;
        this.handleServerUpdate({ ...payload, direction: 'latest' });
      })
      .receive('error', () => {
        this.showStatus('Unable to load chunk logs.');
      });

    this.channel.on('new_logs', this.handleNewLogs);

    if (this.state.liveEnabled) {
      this.loadLatest();
    }
  },

  handleBottomIntersect(entries: IntersectionObserverEntry[]) {
    if (!this.state.initialized || !this.state.hasMoreForward) return;
    const visible = entries.some((entry) => entry.isIntersecting);
    if (visible) {
      this.loadMore('next');
    }
  },

  handleTopIntersect(entries: IntersectionObserverEntry[]) {
    if (!this.state.initialized || !this.state.hasMoreBackward) return;
    const visible = entries.some((entry) => entry.isIntersecting);
    if (visible) {
      this.loadMore('previous');
    }
  },

  loadMore(direction: PendingDirection) {
    if (this.batchId <= 0 || !this.state.initialized || !this.channel) return;

    if (direction === 'next') {
      if (this.state.loadingNext || !this.state.hasMoreForward) return;
      this.state.loadingNext = true;
    } else {
      if (this.state.loadingPrev || !this.state.hasMoreBackward) return;
      this.state.loadingPrev = true;
    }

    const offset =
      direction === 'next'
        ? this.state.offset + this.state.count
        : Math.max(this.state.offset - this.limit, 0);

    this.showStatus('Loading…');

    this.channel
      .push('load', {
        batch_id: this.batchId,
        offset,
        limit: this.limit,
        direction,
      })
      .receive('ok', (payload: ChunkLogsPayload) => {
        this.handleServerUpdate(payload);
      })
      .receive('error', () => {
        this.hideStatus();
        this.state.loadingNext = false;
        this.state.loadingPrev = false;
      });
  },

  loadLatest() {
    if (!this.state.initialized || this.batchId <= 0 || !this.channel) return;
    if (this.state.loadingLatest) return;

    this.state.loadingLatest = true;
    this.showStatus('Loading…');

    this.channel
      .push('load', {
        batch_id: this.batchId,
        offset: 0,
        limit: this.limit,
        direction: 'latest',
      })
      .receive('ok', (payload: ChunkLogsPayload) => {
        this.handleServerUpdate({ ...payload, direction: 'latest' });
        this.state.loadingLatest = false;
      })
      .receive('error', () => {
        this.state.loadingLatest = false;
        this.hideStatus();
      });
  },

  handleServerUpdate(payload: ChunkLogsPayload) {
    if (!payload || payload.batch_id !== this.batchId) {
      return;
    }

    this.hideStatus();

    if (typeof payload.total === 'number') {
      this.state.total = payload.total;
    }

    if (!payload.logs || payload.logs.length === 0) {
      this.state.hasMoreForward = payload.has_more;
      this.state.hasMoreBackward = this.state.offset > 0;
      this.state.loadingNext = false;
      this.state.loadingPrev = false;
      this.state.loadingLatest = false;

      if (this.state.count === 0) {
        this.showStatus('No chunk logs available.');
      }

      return;
    }

    if (payload.direction === 'previous') {
      this.applyPreviousPage(payload);
    } else if (payload.direction === 'latest' || payload.direction === 'refresh') {
      this.applyLatestPage(payload);
    } else {
      this.applyNextPage(payload);
    }

    this.state.count = this.bodyEl?.querySelectorAll('.chunk-log-entry').length ?? 0;
    this.state.hasMoreForward = payload.has_more;
    this.state.hasMoreBackward = this.state.offset > 0;
    this.state.loadingNext = false;
    this.state.loadingPrev = false;
    this.state.loadingLatest = false;
  },

  applyLatestPage(payload: ChunkLogsPayload) {
    if (!this.bodyEl) return;

    const effectiveOffset = typeof payload.offset === 'number' ? payload.offset : 0;
    this.resetWindow(effectiveOffset);

    payload.logs.forEach((log) => {
      this.insertLogAtEnd(log);
    });

    this.state.count = this.bodyEl.querySelectorAll('.chunk-log-entry').length;
    this.trimFromTopIfNeeded();
    this.state.offset = effectiveOffset;
    this.state.autoDisabledByScroll = false;
    this.scrollToBottom();
  },

  applyNextPage(payload: ChunkLogsPayload) {
    if (!this.bodyEl || !this.scrollEl) return;

    if (payload.offset < this.state.offset) {
      this.resetWindow(payload.offset);
    }

    payload.logs.forEach((log) => {
      this.insertLogAtEnd(log);
    });

    this.state.offset = payload.offset;
    this.state.count = this.bodyEl.querySelectorAll('.chunk-log-entry').length;
    this.trimFromTopIfNeeded();
  },

  applyPreviousPage(payload: ChunkLogsPayload) {
    if (!this.bodyEl || !this.scrollEl) return;

    const newOffset =
      typeof payload.offset === 'number'
        ? payload.offset
        : Math.max(this.state.offset - this.limit, 0);

    if (newOffset >= this.state.offset) {
      return;
    }

    const previousScrollHeight = this.scrollEl.scrollHeight;
    const previousScrollTop = this.scrollEl.scrollTop;

    for (let index = payload.logs.length - 1; index >= 0; index -= 1) {
      this.insertLogAtStart(payload.logs[index]);
    }

    this.state.offset = newOffset;
    this.state.count = this.bodyEl.querySelectorAll('.chunk-log-entry').length;

    this.trimFromBottomIfNeeded();

    const newScrollHeight = this.scrollEl.scrollHeight;
    const delta = newScrollHeight - previousScrollHeight;
    if (delta > 0) {
      this.suppressScrollWhile(() => {
        this.scrollEl!.scrollTop = previousScrollTop + delta;
      });
    }
  },

  handleNewLogs(payload: { batch_id: number; log: ChunkLog; total: number | null }) {
    if (!payload || payload.batch_id !== this.batchId || !payload.log) return;
    if (!this.bodyEl) return;

    if (typeof payload.total === 'number') {
      this.state.total = payload.total;
    }

    const nearBottom = this.isNearBottom();
    this.insertLogAtEnd(payload.log);
    this.state.count = this.bodyEl.querySelectorAll('.chunk-log-entry').length;
    this.trimFromTopIfNeeded();

    if (this.state.liveEnabled && nearBottom) {
      this.scrollToBottom();
      this.hideStatus();
    } else if (!this.state.liveEnabled) {
      this.showStatus('Live update paused. Scroll to bottom or re-enable Live update.');
    } else if (!nearBottom) {
      this.showStatus('New logs available. Scroll to bottom to view.');
    }
  },

  resetWindow(offset = 0) {
    if (!this.bodyEl) return;
    this.bodyEl.innerHTML = '';
    this.state.offset = offset;
    this.state.count = 0;
  },

  insertLogAtEnd(log: ChunkLog) {
    if (!this.bodyEl) return;
    const existing = this.findEntry(log.ordinal);
    if (existing) return;
    const node = this.buildLogNode(log);
    this.bodyEl.append(node);
  },

  insertLogAtStart(log: ChunkLog) {
    if (!this.bodyEl) return;
    const existing = this.findEntry(log.ordinal);
    if (existing) return;
    const node = this.buildLogNode(log);
    if (this.bodyEl.firstElementChild) {
      this.bodyEl.insertBefore(node, this.bodyEl.firstElementChild);
    } else {
      this.bodyEl.append(node);
    }
  },

  buildLogNode(log: ChunkLog) {
    const wrapper = document.createElement('div');
    wrapper.className = 'chunk-log-entry border border-gray-200 dark:border-gray-700 rounded p-2';
    wrapper.dataset.ordinal = String(log.ordinal);
    wrapper.dataset.chunkIndex = log.chunk_index;

    const header = document.createElement('div');
    header.className = 'text-xs text-gray-500 dark:text-gray-400 mb-1';
    header.textContent = `Chunk ${log.chunk_index ?? log.ordinal}`;
    wrapper.append(header);

    const queryId = document.createElement('div');
    queryId.className = 'text-xs break-words';
    queryId.textContent = `Query ID: ${log.query_id || '—'}`;
    wrapper.append(queryId);

    const rows = document.createElement('div');
    rows.className = 'text-xs';
    rows.textContent = `Rows: ${this.formatNumber(log.rows)}`;
    wrapper.append(rows);

    const bytes = document.createElement('div');
    bytes.className = 'text-xs';
    bytes.textContent = `Bytes: ${this.formatNumber(log.bytes)}`;
    wrapper.append(bytes);

    const exec = document.createElement('div');
    exec.className = 'text-xs';
    exec.textContent = `Execution (ms): ${this.formatNumber(log.execution_time_ms)}`;
    wrapper.append(exec);

    const source = document.createElement('div');
    source.className = 'text-xs break-all';
    const code = document.createElement('code');
    code.textContent = log.source_url || '—';
    source.append('Source: ');
    source.append(code);
    wrapper.append(source);

    return wrapper;
  },

  findEntry(ordinal: number) {
    if (!this.bodyEl) return null;
    return this.bodyEl.querySelector(
      `.chunk-log-entry[data-ordinal="${ordinal}"]`,
    ) as HTMLElement | null;
  },

  trimFromTopIfNeeded() {
    if (!this.bodyEl || !this.scrollEl) return;
    const excess = this.bodyEl.children.length - this.maxWindow;
    if (excess <= 0) return;

    const previousHeight = this.scrollEl.scrollHeight;

    for (let index = 0; index < excess; index += 1) {
      const node = this.bodyEl.firstElementChild;
      if (!node) break;
      node.remove();
    }

    const delta = previousHeight - this.scrollEl.scrollHeight;
    if (delta > 0) {
      this.suppressScrollWhile(() => {
        this.scrollEl!.scrollTop = Math.max(this.scrollEl!.scrollTop - delta, 0);
      });
    }

    this.state.offset += excess;
    this.state.count = this.bodyEl.querySelectorAll('.chunk-log-entry').length;
  },

  trimFromBottomIfNeeded() {
    if (!this.bodyEl) return;
    const excess = this.bodyEl.children.length - this.maxWindow;
    if (excess <= 0) return;
    for (let index = 0; index < excess; index += 1) {
      const node = this.bodyEl.lastElementChild;
      if (!node) break;
      node.remove();
    }
    this.state.count = this.bodyEl.querySelectorAll('.chunk-log-entry').length;
  },

  scrollToBottom() {
    if (!this.scrollEl) return;
    this.suppressScrollWhile(() => {
      this.scrollEl!.scrollTop = this.scrollEl!.scrollHeight;
    });
  },

  suppressScrollWhile(fn: () => void) {
    this.state.suppressScroll = true;
    try {
      fn();
    } finally {
      window.requestAnimationFrame(() => {
        this.state.suppressScroll = false;
      });
    }
  },

  showStatus(message: string) {
    if (!this.statusEl) return;
    this.statusEl.textContent = message;
    this.statusEl.classList.remove('hidden');
  },

  hideStatus() {
    if (!this.statusEl) return;
    this.statusEl.classList.add('hidden');
  },

  formatNumber(value: number | null | undefined) {
    if (value === null || value === undefined) return '—';
    if (Number.isNaN(value)) return '—';
    return formatNumber.format(value);
  },

  isNearBottom() {
    if (!this.scrollEl) return false;
    const { scrollTop, clientHeight, scrollHeight } = this.scrollEl;
    return scrollHeight - (scrollTop + clientHeight) <= BOTTOM_THRESHOLD_PX;
  },

  handleScroll() {
    if (!this.scrollEl || this.state.suppressScroll) return;

    const nearBottom = this.isNearBottom();

    if (!nearBottom) {
      if (this.state.liveEnabled) {
        this.state.autoDisabledByScroll = true;
        this.setLiveUpdate(false, { persist: false });
        this.showStatus('Live update paused while viewing earlier logs.');
      }
    } else if (
      !this.state.liveEnabled &&
      this.state.autoDisabledByScroll &&
      this.state.autoLiveAllowed
    ) {
      this.state.autoDisabledByScroll = false;
      this.setLiveUpdate(true, { persist: false });
      this.hideStatus();
    }
  },

  initializeLiveToggle() {
    if (!this.batchId) return;

    const existing = persistedState[this.batchId] ?? {};
    const initialLive = typeof existing.live === 'boolean' ? existing.live : this.defaultLive;

    this.state.autoLiveAllowed = initialLive;

    const applyInitial = () => {
      this.setLiveUpdate(initialLive, { persist: false, force: true });
      if (this.liveToggleEl) {
        this.liveToggleEl.checked = initialLive;
      }
    };

    if (this.liveToggleEl) {
      this.handleLiveToggleChange = (event: Event) => {
        if (!(event.target instanceof HTMLInputElement)) return;
        this.state.autoLiveAllowed = event.target.checked;
        this.state.autoDisabledByScroll = false;
        this.setLiveUpdate(event.target.checked);
      };

      applyInitial();
      this.liveToggleEl.addEventListener('change', this.handleLiveToggleChange);
    } else {
      applyInitial();
    }
  },

  setLiveUpdate(enabled: boolean, opts: { persist?: boolean; force?: boolean } = {}) {
    const { persist = true, force = false } = opts;

    if (!force && this.state.liveEnabled === enabled) {
      return;
    }

    this.state.liveEnabled = enabled;

    if (enabled && this.state.initialized && this.state.channelReady) {
      this.loadLatest();
    }

    if (persist && this.batchId) {
      const current = persistedState[this.batchId] ?? {};
      persistedState[this.batchId] = { ...current, live: enabled };
    }

    if (this.liveToggleEl && this.liveToggleEl.checked !== enabled) {
      this.liveToggleEl.checked = enabled;
    }
  },
};

export const ChunkLogsDetails = {
  mounted() {
    this.batchId = parseNumber(this.el.dataset.batchId, 0);
    this.defaultLive = this.el.dataset.defaultLive === '1';
    this.handleToggle = () => {
      if (this.batchId > 0) {
        const current = persistedState[this.batchId] ?? {};
        persistedState[this.batchId] = { ...current, open: this.el.open };
      }
    };

    this.el.addEventListener('toggle', this.handleToggle);
    this.restoreOpenState();
  },

  updated() {
    this.restoreOpenState();
  },

  destroyed() {
    this.el.removeEventListener('toggle', this.handleToggle);
  },

  restoreOpenState() {
    if (this.batchId > 0) {
      const state = persistedState[this.batchId];
      if (state && typeof state.open === 'boolean') {
        this.el.open = state.open;
      } else {
        persistedState[this.batchId] = { open: this.el.open, live: this.defaultLive };
      }
    }
  },
};
