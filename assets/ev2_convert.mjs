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

  view() {
    return new Uint8Array(this.memory.buffer);
  }

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
          try {
            self.memory.grow(Math.ceil((size - cur) / 65536));
            return 1;
          } catch {
            return 0;
          }
        },
      },
    });
    this.exports = instance.exports;
  }

  call(name, args) {
    const ret = this.exports[name](...args);
    if (ret < 0) throw new Error(`${name} failed: ${ret}`);
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

async function convertEv2(inputPath, outputPath) {
  const file = fs.readFileSync(inputPath);
  const fileSize = file.length;
  if (fileSize < 112) throw new Error('file too small');

  const tail = file.subarray(fileSize - 112);
  const memory = new WebAssembly.Memory({ initial: 100, maximum: 400 });
  const ev2 = new Ev2Wasm(memory);
  await ev2.load();
  ev2.init(fileSize, tail);

  const chunkSize = 1024 * 1024;
  const out = fs.createWriteStream(outputPath);
  for (let offset = 0; offset < fileSize; offset += chunkSize) {
    const end = Math.min(offset + chunkSize, fileSize);
    out.write(ev2.decryptChunk(file.subarray(offset, end), offset));
  }
  await new Promise((resolve, reject) => {
    out.end((err) => (err ? reject(err) : resolve()));
  });
  ev2.destroy();

  const magic = fs.readFileSync(outputPath).subarray(0, 4);
  if (magic[0] !== 0x46 || magic[1] !== 0x4c || magic[2] !== 0x56 || magic[3] !== 0x01) {
    fs.unlinkSync(outputPath);
    throw new Error('output is not valid FLV after EV2 decrypt');
  }
}

const input = process.argv[2];
const output = process.argv[3];
if (!input || !output) {
  console.error('usage: node ev2_convert.mjs <input.ev2> <output.flv>');
  process.exit(1);
}

convertEv2(input, output).catch((e) => {
  console.error(e);
  process.exit(1);
});
