// --- YouTube IFrame API loader (only loads once) ---
function loadYouTubeAPI() {
  if ((window as any).YT && (window as any).YT.Player) return Promise.resolve((window as any).YT);
  if ((window as any).__ytApiLoading) return (window as any).__ytApiLoading;

  (window as any).__ytApiLoading = new Promise((resolve, reject) => {
    const tag = document.createElement("script");
    tag.src = "https://www.youtube.com/iframe_api";
    tag.async = true;
    tag.onerror = () => reject(new Error("Failed to load YouTube IFrame API"));
    document.head.appendChild(tag);

    // The API will call this when it's ready
    (window as any).onYouTubeIframeAPIReady = () => resolve((window as any).YT);
  });

  return (window as any).__ytApiLoading;
}

// --- LiveView Hook ---
export const YouTubePlayer = {
  mounted() {
    (this as any).player = null;
    (this as any).timeTicker = null;
    (this as any).intervalMs = 500; // adjust if you want fewer/more events
    (this as any).videoId = (this as any).el.dataset.videoId;

    // Build/replace the inner target so YT can mount cleanly
    (this as any)._ensureTarget = () => {
      let target = (this as any).el.querySelector(".yt-target");
      if (!target) {
        (this as any).el.innerHTML = "";
        target = document.createElement("div");
        target.className = "yt-target w-full h-96";
        (this as any).el.appendChild(target);
      }
      return target;
    };

    loadYouTubeAPI()
      .then(() => (this as any)._mountPlayer())
      .catch((err: any) => console.error("[YouTubePlayer] API load error:", err));

    // Handle pause/resume events from LiveView
    (this as any).handleEvent("pause_video", () => {
      console.log("[YouTubePlayer] Received pause_video event");
      (this as any)._pauseVideo();
    });

    (this as any).handleEvent("resume_video", () => {
      console.log("[YouTubePlayer] Received resume_video event");
      (this as any)._resumeVideo();
    });

    (this as any).handleEvent("seek_video", (data: any) => {
      console.log("[YouTubePlayer] Received seek_video event", data);
      (this as any)._seekVideo(data.time);
    });
  },

  destroyed() { (this as any)._teardown(); },
  disconnected() { (this as any)._stopTicker(); },
  reconnected() { /* nothing needed; ticker will resume on play */ },

  _mountPlayer() {
    const target = (this as any)._ensureTarget();
    const origin = window.location.origin;

    (this as any).player = new (window as any).YT.Player(target, {
      // Use youtube-nocookie host for better privacy; switch to default if you prefer
      host: "https://www.youtube-nocookie.com",
      width: "100%",
      height: "100%",
      videoId: (this as any).videoId,
      playerVars: {
        rel: 0,
        modestbranding: 1,
        playsinline: 1,
        origin: origin,
        enablejsapi: 1
      },
      events: {
        onReady: () => { /* player is ready; no autoplay */ },
        onStateChange: (e: any) => (this as any)._onStateChange(e),
        onError: (e: any) => console.error("[YouTubePlayer] Player error:", e?.data ?? e)
      }
    });
  },

  _onStateChange(e: any) {
    // Only tick while playing
    if (e.data === (window as any).YT.PlayerState.PLAYING) {
      (this as any)._startTicker();
    } else {
      (this as any)._stopTicker();
    }
  },

  _startTicker() {
    if ((this as any).timeTicker) return;
    (this as any).timeTicker = setInterval(() => {
      try {
        if (!(this as any).player || typeof (this as any).player.getPlayerState !== "function") return;
        if ((this as any).player.getPlayerState() !== (window as any).YT.PlayerState.PLAYING) return;

        const t = (this as any).player.getCurrentTime?.();
        if (typeof t === "number" && !Number.isNaN(t)) {
          // Push time (float seconds) to LV
          (this as any).pushEvent("video_time_update", { time: t });
        }
      } catch (_) {
        // be silent; transient errors can occur during hot reloads/patches
      }
    }, (this as any).intervalMs);
  },

  _stopTicker() {
    if ((this as any).timeTicker) {
      clearInterval((this as any).timeTicker);
      (this as any).timeTicker = null;
    }
  },

  _pauseVideo() {
    try {
      if ((this as any).player && typeof (this as any).player.pauseVideo === "function") {
        const state = (this as any).player.getPlayerState?.();
        console.log("[YouTubePlayer] Current player state before pause:", state);
        (this as any).player.pauseVideo();
        console.log("[YouTubePlayer] Video paused via LiveView event");
      } else {
        console.warn("[YouTubePlayer] Player not ready for pause - player:", !!(this as any).player, "pauseVideo function:", typeof (this as any).player?.pauseVideo);
      }
    } catch (error) {
      console.error("[YouTubePlayer] Error pausing video:", error);
    }
  },

  _resumeVideo() {
    try {
      if ((this as any).player && typeof (this as any).player.playVideo === "function") {
        (this as any).player.playVideo();
        console.log("[YouTubePlayer] Video resumed via LiveView event");
      }
    } catch (error) {
      console.error("[YouTubePlayer] Error resuming video:", error);
    }
  },

  _seekVideo(timeInSeconds: number) {
    try {
      if ((this as any).player && typeof (this as any).player.seekTo === "function") {
        (this as any).player.seekTo(timeInSeconds, true);
        console.log(`[YouTubePlayer] Video seeked to ${timeInSeconds} seconds`);
      } else {
        console.warn("[YouTubePlayer] Player not ready for seek - player:", !!(this as any).player);
      }
    } catch (error) {
      console.error("[YouTubePlayer] Error seeking video:", error);
    }
  },

  _teardown() {
    (this as any)._stopTicker();
    if ((this as any).player && typeof (this as any).player.destroy === "function") {
      try { 
        (this as any).player.destroy(); 
      } catch (error) {
        console.error("[YouTubePlayer] Error during teardown:", error);
      }
    }
    (this as any).player = null;
  }
};

// Placeholder HTML5Player - can be implemented later if needed
export const HTML5Player = {
  mounted() {
    console.log("[HTML5Player] Mounted - placeholder implementation");
  },
  
  destroyed() {
    console.log("[HTML5Player] Destroyed - placeholder implementation");
  }
};

// DialogueFader - handles smooth fade transitions for dialogue UI
export const DialogueFader = {
  mounted() {
    console.log("[DialogueFader] Mounted");
    
    // Listen for fade events from LiveView
    (this as any).handleEvent("ui:fade-out", () => {
      console.log("[DialogueFader] Fading out");
      (this as any).el.classList.add("is-fading");
      
      // Also dim the video container
      const videoContainer = document.getElementById("video-container");
      if (videoContainer) {
        videoContainer.classList.add("is-dimmed");
      }
    });

    (this as any).handleEvent("ui:fade-in", () => {
      console.log("[DialogueFader] Fading in");
      (this as any).el.classList.remove("is-fading");
      
      // Remove video dimming
      const videoContainer = document.getElementById("video-container");
      if (videoContainer) {
        videoContainer.classList.remove("is-dimmed");
      }
    });
  },

  destroyed() {
    console.log("[DialogueFader] Destroyed");
  }
};