import * as Trigger from '../data/persistence/trigger';

export const ExplainObjectiveButton = {
  mounted() {
    let disabled = false;
    let delay = 5000;
    const MAX_DELAY = 60_000;

    this.el.addEventListener('click', () => {
      if (disabled) return;

      const sectionSlug = this.el.getAttribute('data-section-slug');
      const resourceId = parseInt(this.el.getAttribute('data-resource-id') || '0', 10);
      const objectiveTitle = this.el.getAttribute('data-objective-title') || '';

      if (!sectionSlug || !resourceId) return;

      disabled = true;
      this.el.setAttribute('disabled', '');
      const el = this.el;
      let cooldownTimer: ReturnType<typeof setTimeout> | null = setTimeout(() => {
        disabled = false;
        el.removeAttribute('disabled');
        cooldownTimer = null;
      }, delay);
      delay = Math.min(delay * 2, MAX_DELAY);

      Trigger.invoke(sectionSlug, {
        trigger_type: 'explain_objective',
        resource_id: resourceId,
        data: { objective_title: objectiveTitle },
        prompt:
          'Explain this learning objective to the student in a clear and helpful way. Help them understand what concepts they need to master, why this objective matters, and provide examples where appropriate.',
      }).catch(() => {
        if (cooldownTimer !== null) clearTimeout(cooldownTimer);
        disabled = false;
        el.removeAttribute('disabled');
        delay = 5000;
      });
    });
  },
};
