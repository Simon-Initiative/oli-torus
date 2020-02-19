
// Use a pool of already created guids to optimize performance
// in areas of the code that quickly request thousands of guids:
const pool : string[] = [];
const POOL_SIZE = 1000;

// Used to track our hit rate for tuning purposes
let hits = 0;
let misses = 0;

// Fill the pool up to its configured max size
function fillPool() {
  for (let i = 0; i < POOL_SIZE - pool.length; i += 1) {
    pool.push(createOne());
  }
}

// Every second, refill the pool.
const schedule = () => setTimeout(() => { fillPool(); schedule(); }, 5000);

// Start refilling the pool.
schedule();

// Request a guid
export default function guid() : string {

  // If we have a guid available, take it
  if (pool.length > 0) {
    hits = hits + 1;
    // pop() is the fastest way to do get an item.
    // It is O(1) relative to the size of the array
    return pool.pop() as string;
  }

  // The pool was empty so we need to create one
  // for this request
  misses = misses + 1;
  return createOne();
}

/**
 * Returns an RFC4122 version 4 compliant GUID.
 * See http://stackoverflow.com/questions/105034/create-guid-uuid-in-javascript
 * for source and related discussion. d
 */
function createOne() {
  let d = new Date().getTime();
  if (typeof performance !== 'undefined' && typeof performance.now === 'function') {
    d += performance.now(); // use high-precision timer if available
  }
  return 'dxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[dxy]/g, (c) => {
    const r = (d + Math.random() * 16) % 16 | 0;
    d = Math.floor(d / 16);

    if (c === 'x') {
      return r.toString(16);
    }
    if (c === 'y') {
      return (r & 0x3 | 0x8).toString(16);
    }

    return (((d + Math.random() * 6) % 6 | 0) + 10).toString(16);
  });
}


(window as any).guid = guid;
