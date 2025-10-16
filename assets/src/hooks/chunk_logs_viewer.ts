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
  limit: number;
  total: number;
  direction: 'next' | 'previous' | 'refresh' | 'latest';
  has_more: boolean;
  logs: ChunkLog[];
};

type PendingDirection = 'next' | 'previous';

function parseNumber(value: string | undefined, fallback: number) {
  if (!value) return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
}

const formatNumber = new Intl.NumberFormat(undefined, { maximumFractionDigits: 0 });

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

export const ChunkLogsViewer = {
  mounted() {
    this.batchId = parseNumber(this.el.dataset.batchId, 0);
    this.limit = parseNumber(this.el.dataset.limit, 10);
    this.maxWindow = parseNumber(this.el.dataset.window, 200);
    this.defaultLive = this.el.dataset.defaultLive === '1';

    this.state = {
      initialized: false,
      initialLoadComplete: false,
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
    };

    this.scrollEl = this.el.querySelector<HTMLElement>('.chunk-logs-scroll');
    this.bodyEl = this.el.querySelector<HTMLElement>('.chunk-logs-body');
    this.bottomSentinel = this.el.querySelector<HTMLElement>('.chunk-logs-bottom-sentinel');
    this.topSentinel = this.el.querySelector<HTMLElement>('.chunk-logs-top-sentinel');
    this.statusEl = this.el.querySelector<HTMLElement>('.chunk-logs-status');
    this.liveToggleEl = this.el.querySelector<HTMLInputElement>('.chunk-logs-live-toggle');

    this.handleServerUpdate = this.handleServerUpdate.bind(this);
    this.handleToggle = this.handleToggle.bind(this);
    this.handleBottomIntersect = this.handleBottomIntersect.bind(this);
    this.handleTopIntersect = this.handleTopIntersect.bind(this);
    this.handleScroll = this.handleScroll.bind(this);

    this.handleEvent('chunk_logs_update', this.handleServerUpdate);

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

    this.disableLiveTimer();

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
        this.enableLiveTimer();
        this.loadLatest();
      }
    } else {
      this.disableLiveTimer();
      this.state.autoDisabledByScroll = false;
    }
  },

  initialize() {
    if (this.state.initialized || !this.scrollEl || !this.bodyEl) return;
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

    this.loadLatest();

    if (this.state.liveEnabled) {
      this.enableLiveTimer();
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
    if (this.batchId <= 0 || !this.state.initialized) return;
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

    this.pushEvent('chunk_logs_load', {
      batch_id: this.batchId,
      offset,
      limit: this.limit,
      direction,
    });
  },

  loadLatest() {
    if (!this.state.initialized || this.batchId <= 0) return;
    if (this.state.loadingLatest) return;

    this.state.loadingLatest = true;
    this.showStatus('Loading…');

    this.pushEvent('chunk_logs_load', {
      batch_id: this.batchId,
      offset: 0,
      limit: this.limit,
      direction: 'latest',
    });
  },

  handleServerUpdate(payload: ChunkLogsPayload) {
    if (!payload || payload.batch_id !== this.batchId) return;

    this.state.loadingLatest = false;
    this.hideStatus();

    if (typeof payload.total === 'number') {
      this.state.total = payload.total;
    }

    if (!payload.logs || payload.logs.length === 0) {
      if (payload.direction === 'latest' || payload.direction === 'refresh') {
        this.resetWindow(payload.offset ?? 0);
      } else if (payload.direction === 'previous' && typeof payload.offset === 'number') {
        this.state.offset = payload.offset;
      }

      this.state.hasMoreForward = Boolean(payload.has_more);
      this.state.hasMoreBackward = this.state.offset > 0;
      this.state.loadingNext = false;
      this.state.loadingPrev = false;

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
    this.state.hasMoreForward = Boolean(payload.has_more);
    this.state.hasMoreBackward = this.state.offset > 0;
    this.state.loadingNext = false;
    this.state.loadingPrev = false;
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
    this.state.initialLoadComplete = true;
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

    this.state.count = this.bodyEl.querySelectorAll('.chunk-log-entry').length;
    this.trimFromTopIfNeeded();
  },

  applyPreviousPage(payload: ChunkLogsPayload) {
    if (!this.bodyEl || !this.scrollEl) return;

    const newOffset =
      typeof payload.offset === 'number' ? payload.offset : Math.max(this.state.offset - this.limit, 0);

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
    header.textContent = `Chunk ${log.ordinal}`;
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
    return this.bodyEl.querySelector<HTMLElement>(`.chunk-log-entry[data-ordinal="${ordinal}"]`);
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

  handleScroll() {
    if (!this.scrollEl || this.state.suppressScroll) return;

    const { scrollTop, clientHeight, scrollHeight } = this.scrollEl;
    const nearBottom = scrollHeight - (scrollTop + clientHeight) <= BOTTOM_THRESHOLD_PX;

    if (!nearBottom) {
      if (this.state.liveEnabled) {
        this.state.autoDisabledByScroll = true;
        this.setLiveUpdate(false, { persist: false });
      }
    } else if (
      !this.state.liveEnabled &&
      this.state.autoDisabledByScroll &&
      this.state.autoLiveAllowed
    ) {
      this.state.autoDisabledByScroll = false;
      this.setLiveUpdate(true, { persist: false });
      this.scrollToBottom();
    }
  },

  initializeLiveToggle() {
    if (!this.batchId) return;

    const existing = persistedState[this.batchId] ?? {};
    const initialLive =
      typeof existing.live === 'boolean' ? existing.live : this.defaultLive;

    this.state.autoLiveAllowed = initialLive;

    const applyInitial = () => {
      this.setLiveUpdate(initialLive, { persist: false, skipLoad: true, force: true });
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

  setLiveUpdate(
    enabled: boolean,
    opts: { persist?: boolean; skipLoad?: boolean; force?: boolean } = {},
  ) {
    const { persist = true, skipLoad = false, force = false } = opts;

    if (!force && this.state.liveEnabled === enabled) {
      return;
    }

    this.state.liveEnabled = enabled;

    if (enabled) {
      if (this.state.initialized && !skipLoad) {
        this.loadLatest();
      }
      this.enableLiveTimer();
    } else {
      this.disableLiveTimer();
    }

    if (persist && this.batchId) {
      const current = persistedState[this.batchId] ?? {};
      persistedState[this.batchId] = { ...current, live: enabled };
    }

    if (this.liveToggleEl && this.liveToggleEl.checked !== enabled) {
      this.liveToggleEl.checked = enabled;
    }
  },

  enableLiveTimer() {
    if (this.liveTimer || !this.state.liveEnabled) return;
    if (!this.detailsEl?.open) return;
    this.liveTimer = window.setInterval(() => {
      if (this.detailsEl?.open) {
        this.loadLatest();
      }
    }, 3000);
  },

  disableLiveTimer() {
    if (this.liveTimer) {
      window.clearInterval(this.liveTimer);
      this.liveTimer = undefined;
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
