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

    window.addEventListener('oli:adaptive-screen-changed', this.handleAdaptiveScreenChanged);
  },

  destroyed() {
    window.removeEventListener('oli:adaptive-screen-changed', this.handleAdaptiveScreenChanged);
  },
};
