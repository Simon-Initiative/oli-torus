import * as Trigger from 'data/persistence/trigger';

export const FirePageTrigger = {
  mounted() {

    this.handleEvent('fire_page_trigger', ({ slug, trigger }: { slug: string, trigger: Trigger.TriggerPayload }) => {

      console.log('Firing page trigger', slug, trigger);
      Trigger.invoke(slug, trigger);
    });
  },
};
