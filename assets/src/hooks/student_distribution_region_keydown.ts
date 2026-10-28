import type { Hook } from 'phoenix_live_view/assets/js/types/view_hook';

type StudentDistributionRegionKeydownState = {
  __studentDistributionRegionKeydown?: (event: KeyboardEvent) => void;
};

const ACTIVATION_KEYS = ['Enter', ' '];

// The region's plain phx-keydown binding (no phx-key filter) would forward every keydown --
// Tab, arrows, modifiers -- to the server, relying on handle_event to ignore anything but
// Enter/Space. phx-key only matches a single key per binding, so it can't express "Enter or
// Space" on its own; this hook filters client-side instead; and pushes the same event
// handle_event already expects, so no server-side change is needed.
export const StudentDistributionRegionKeydown: Hook<StudentDistributionRegionKeydownState> = {
  mounted() {
    this.__studentDistributionRegionKeydown = (event: KeyboardEvent) => {
      if (!ACTIVATION_KEYS.includes(event.key)) return;

      event.preventDefault();
      this.pushEventTo(this.el, 'select_student_group', {
        group: this.el.getAttribute('phx-value-group'),
      });
    };

    this.el.addEventListener('keydown', this.__studentDistributionRegionKeydown);
  },

  destroyed() {
    if (this.__studentDistributionRegionKeydown) {
      this.el.removeEventListener('keydown', this.__studentDistributionRegionKeydown);
    }
  },
};
