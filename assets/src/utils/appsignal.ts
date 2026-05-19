import Appsignal from '@appsignal/javascript';
import * as AppsignalConsoleBreadcrumbs from '@appsignal/plugin-breadcrumbs-console';
import * as AppsignalNetworkBreadcrumbs from '@appsignal/plugin-breadcrumbs-network';
import * as AppsignalWindowEvents from '@appsignal/plugin-window-events';

type AppsignalWithRuntimeMetadata = Appsignal & {
  __torusRuntimeMetadata?: Record<string, string>;
};

export const initAppSignal = (
  apiKey: string | null,
  appName: string,
  metadata: Record<string, string>,
): Appsignal | null => {
  if (!apiKey) {
    return null;
  }

  const client = new Appsignal({
    key: apiKey,
    namespace: appName,
  }) as AppsignalWithRuntimeMetadata;
  client.use(AppsignalConsoleBreadcrumbs.plugin());
  client.use(AppsignalNetworkBreadcrumbs.plugin());
  client.use(AppsignalWindowEvents.plugin()); // <- This handles onerror / onunhandledrejection, we'll want to watch the volume of events this generates.

  client.__torusRuntimeMetadata = { ...metadata };
  client.addDecorator((span) => {
    span.setTags(client.__torusRuntimeMetadata || {});
    return span;
  });

  client.addBreadcrumb({
    category: 'launch',
    action: appName + ' Launched',
    metadata,
  });

  return client;
};

export const updateAppSignalMetadata = (
  client: Appsignal | null,
  appName: string,
  metadata: Record<string, string>,
) => {
  if (!client) {
    return;
  }

  const runtimeClient = client as AppsignalWithRuntimeMetadata;
  runtimeClient.__torusRuntimeMetadata = { ...metadata };
  runtimeClient.addBreadcrumb({
    category: 'navigation',
    action: `${appName} Context Updated`,
    metadata,
  });
};
