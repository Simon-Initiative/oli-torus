export const AdaptiveDialogueSync = {
  mounted() {
    this.handleAdaptiveScreenChanged = (event: Event) => {
      const customEvent = event as CustomEvent<{ activityAttemptGuid?: string }>;
      const activityAttemptGuid = customEvent.detail?.activityAttemptGuid;

      if (!activityAttemptGuid) {
        return;
      }

      this.pushEvent('adaptive_screen_changed', {
        activity_attempt_guid: activityAttemptGuid,
      });
    };

    this.requestAdaptiveScreenSync = () => {
      window.dispatchEvent(new CustomEvent('oli:adaptive-screen-sync-request'));
    };

    window.addEventListener('oli:adaptive-screen-changed', this.handleAdaptiveScreenChanged);
    window.addEventListener('oli:adaptive-screen-ready', this.requestAdaptiveScreenSync);
    this.requestAdaptiveScreenSync();
  },

  destroyed() {
    window.removeEventListener('oli:adaptive-screen-changed', this.handleAdaptiveScreenChanged);
    window.removeEventListener('oli:adaptive-screen-ready', this.requestAdaptiveScreenSync);
  },
};
