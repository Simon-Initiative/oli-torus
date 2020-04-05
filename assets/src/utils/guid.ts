
// Use a pool of already created guids to optimize performance
// in areas of the code that quickly request thousands of guids:
const pool : Uint32Array[] = [];
const POOL_SIZE = 1000;

// Used to track our hit rate for tuning purposes
let hits = 0;
let misses = 0;

// Fill the pool up to its configured max size
function fillPool() {
  pool.push(createSome(POOL_SIZE - pool.length));
}

// Every second, refill the pool.
const schedule = () => setTimeout(() => { fillPool(); schedule(); }, 5000);

// Start refilling the pool.
schedule();

// Request a guid
export default function guid() : number {

  // If we have a guid available, take it
  if (pool.length > 0) {
    hits = hits + 1;
    // pop() is the fastest way to do get an item.
    // It is O(1) relative to the size of the array
    return pool.pop() as any;
  }

  // The pool was empty so we need to create one
  // for this request
  misses = misses + 1;
  return createSome(1)[0];
}

/**
 * Returns an RFC4122 version 4 compliant GUID.
 * See http://stackoverflow.com/questions/105034/create-guid-uuid-in-javascript
 * for source and related discussion. d
 */
function createSome(count: number) {
  const array = new Uint32Array(count);
  window.crypto.getRandomValues(array);
  return array;
}


(window as any).guid = guid;
