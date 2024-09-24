import { useEffect, useState } from 'react';
import { initSocket } from '../../phoenix/socket';

export function useGlobalState(userId: number, active: boolean) {
  const [init, setInit] = useState(false);
  const [channel, setChannel] = useState(null as any);
  const [data, setData] = useState({});

  // Note, tear down and setup of the delta and state listeners
  // is necessary on every execution of this hook so that they have
  // a closure view of the latest 'data'
  if (channel !== null) {
    channel.off('delta');
    channel.off('deletion');
    channel.off('state');

    if (active) {
      channel.on('delta', (delta: any) => {
        const updated = Object.assign({}, data, delta);
        setData(updated);
      });
      channel.on('deletion', (deleted: any) => {
        const keys = deleted.reduce((m: any, k: any) => {
          m[k] = true;
          return m;
        }, {});
        const updated = Object.keys(data).reduce((m: any, k: any) => {
          if (!keys[k]) {
            m[k] = (data as any)[k];
          }
          return m;
        }, {});
        setData(updated);
      });
      channel.on('state', (state: any) => {
        setData(state);
      });
    }
  }

  useEffect(() => {
    if (!init) {
      const c = initSocket().channel('user_global_state:' + userId, {});

      setInit(true);
      setChannel(c);

      c.join();
      // .receive('ok', (resp: any) => { console.log('Joined successfully', resp) })
      // .receive('error', (resp: any) => { console.log('Unable to join', resp) });
    }

    return () => {
      if (channel !== null && init) {
        channel.leave();
      }
    };
  }, [init]);

  return data;
}

declare global {
  interface Window {
    ReactToLiveView?: LiveViewHook;
  }
}

interface LiveViewHook {
  el: HTMLElement;
  pushEvent: (event: string, payload: any) => void;
  pushEventTo: (selectorOrTarget: string | HTMLElement, event: string, payload: any) => void;
}
