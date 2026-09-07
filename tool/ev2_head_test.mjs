import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const wasmPath = path.join(__dirname, 'ev2-decrypt.wasm');

function i64Pair(value) {
  const big = BigInt(value);
  return [Number(big & 0xffffffffn), Number(big >> 32n)];
}

class Ev2Wasm {
  constructor(memory) {
    this.memory = memory;
    this.instance = null;
  }

  view() {
    return new Uint8Array(this.memory.buffer);
  }

  async load() {
    const wasm = fs.readFileSync(wasmPath);
    const self = this;
    const { instance } = await WebAssembly.instantiate(wasm, {
      env: {
        memory: this.memory,
        emscripten_memcpy_js(dst, src, len) {
          const view = self.view();
          view.copyWithin(dst >>> 0, src >>> 0, (src >>> 0) + (len >>> 0));
        },
        emscripten_resize_heap(requestedSize) {
          requestedSize >>>= 0;
          const current = self.memory.buffer.byteLength;
          if (requestedSize <= current) return 1;
          const pages = Math.ceil((requestedSize - current) / 65536);
          try {
            self.memory.grow(pages);
            return 1;
          } catch {
            return 0;
          }
        },
      },
    });
    this.instance = instance;
    this.exports = instance.exports;
  }

  call(name, args) {
    const ret = this.exports[name](...args);
    if (ret < 0) throw new Error(`${name} failed: ${ret}`);
    return ret;
  }

  malloc(size) {
    return this.exports.malloc_buffer(size);
  }

  free(ptr) {
    this.exports.free_buffer(ptr);
  }

  init(fileSize, tail112) {
    const ptr = this.malloc(tail112.length);
    this.view().set(tail112, ptr);
    this.call('init', [...i64Pair(fileSize), ptr, tail112.length]);
    this.free(ptr);
  }

  decryptChunk(data, offset) {
    const ptr = this.malloc(data.length);
    this.view().set(data, ptr);
    this.call('decrypt', [ptr, data.length, ...i64Pair(offset)]);
    const out = Buffer.from(this.view().slice(ptr, ptr + data.length));
    this.free(ptr);
    return out;
  }

  destroy() {
    this.exports.destroy();
  }
}

const fileSize = 76260380;
const head = fs.readFileSync(path.join(__dirname, 'sample_head.bin'));
const tail = fs.readFileSync(path.join(__dirname, 'sample_tail.bin'));

const memory = new WebAssembly.Memory({ initial: 100, maximum: 400 });
const ev2 = new Ev2Wasm(memory);
await ev2.load();
ev2.init(fileSize, tail);

const plain = ev2.decryptChunk(head.subarray(0, 256), 0);
console.log('plain head hex:', plain.subarray(0, 16).toString('hex'));
console.log('plain ascii:', plain.subarray(0, 4).toString('ascii'));
console.log('is FLV', plain[0] === 0x46 && plain[1] === 0x4c && plain[2] === 0x56);
ev2.destroy();
