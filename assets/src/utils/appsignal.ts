import Appsignal from '@appsignal/javascript';
import * as AppsignalConsoleBreadcrumbs from '@appsignal/plugin-breadcrumbs-console';
import * as AppsignalNetworkBreadcrumbs from '@appsignal/plugin-breadcrumbs-network';
import * as AppsignalWindowEvents from '@appsignal/plugin-window-events';

export const initAppSignal = (
  apiKey: string | null,
  appName: string,
  metadata: Record<string, string>,
) => {
  if (!apiKey) {
    return null;
  }

  const client = new Appsignal({
    key: apiKey,
    namespace: appName,
  });
  client.use(AppsignalConsoleBreadcrumbs.plugin());
  client.use(AppsignalNetworkBreadcrumbs.plugin());
  client.use(AppsignalWindowEvents.plugin()); // <- This handles onerror / onunhandledrejection, we'll want to watch the volume of events this generates.

  client.addBreadcrumb({
    category: 'launch',
    action: appName + ' Launched',
    metadata,
  });

  return client;
};
