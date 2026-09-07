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
  }
  view() { return new Uint8Array(this.memory.buffer); }
  async load() {
    const self = this;
    const { instance } = await WebAssembly.instantiate(fs.readFileSync(wasmPath), {
      env: {
        memory: this.memory,
        emscripten_memcpy_js(dst, src, len) {
          self.view().copyWithin(dst >>> 0, src >>> 0, (src >>> 0) + (len >>> 0));
        },
        emscripten_resize_heap(size) {
          size >>>= 0;
          const cur = self.memory.buffer.byteLength;
          if (size <= cur) return 1;
          try { self.memory.grow(Math.ceil((size - cur) / 65536)); return 1; } catch { return 0; }
        },
      },
    });
    this.exports = instance.exports;
  }
  call(name, args) {
    const ret = this.exports[name](...args);
    if (ret < 0) throw new Error(`${name} failed ${ret}`);
  }
  malloc(n) { return this.exports.malloc_buffer(n); }
  free(p) { this.exports.free_buffer(p); }
  init(fileSize, tail) {
    const p = this.malloc(tail.length);
    this.view().set(tail, p);
    this.call('init', [...i64Pair(fileSize), p, tail.length]);
    this.free(p);
  }
  decrypt(data, offset) {
    const p = this.malloc(data.length);
    this.view().set(data, p);
    this.call('decrypt', [p, data.length, ...i64Pair(offset)]);
    const out = Buffer.from(this.view().slice(p, p + data.length));
    this.free(p);
    return out;
  }
}

const fileSize = 76260380;
const head = fs.readFileSync(path.join(__dirname, 'sample_head.bin'));
const tail = fs.readFileSync(path.join(__dirname, 'sample_tail.bin'));
const memory = new WebAssembly.Memory({ initial: 100, maximum: 400 });
const ev2 = new Ev2Wasm(memory);
await ev2.load();
ev2.init(fileSize, tail);
const plain = ev2.decrypt(head.subarray(0, 100), 0);
const cipher = head.subarray(0, 100);
console.log('cipher', cipher.subarray(0, 8).toString('hex'));
console.log('plain ', plain.subarray(0, 8).toString('hex'));
const xor = Buffer.alloc(100);
for (let i = 0; i < 100; i++) xor[i] = cipher[i] ^ plain[i];
console.log('xor key first16', xor.subarray(0, 16).toString('hex'));
console.log('xor unique bytes', new Set(xor).size);
