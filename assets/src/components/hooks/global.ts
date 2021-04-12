import { useState, useEffect } from 'react';
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
    channel.off('state');

    if (active) {
      channel.on('delta', (delta: any) => {
        const updated = Object.assign({}, data, delta)
        setData(updated);
      });
      channel.on('state', (state: any) => {
        setData(state);
      });
    }
  }

  useEffect(() => {

    if (!init) {
      const c = initSocket().channel('global:' + userId, {});

      setInit(true);
      setChannel(c);

      c.join()
        .receive('ok', (resp: any) => { console.log('Joined successfully', resp) })
        .receive('error', (resp: any) => { console.log('Unable to join', resp) });
    }

    return () => {
      if (channel !== null && init) {
        channel.leave();
      }
    }
  }, [init]);

  return data;
}