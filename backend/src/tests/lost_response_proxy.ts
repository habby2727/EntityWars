import { writeFileSync } from "node:fs";

const target = Bun.env.FORGE_SMOKE_URL || "";
const marker = Bun.env.LOST_RESPONSE_MARKER || "";
const port = Number(Bun.env.LOST_RESPONSE_PORT);
if (!/^http:\/\/127\.0\.0\.1:\d+$/.test(target) || !marker || !port) throw new Error("Isolated proxy configuration required");
let dropped = false;
const server = Bun.listen({
  hostname: "127.0.0.1", port,
  socket: {
    open(socket) { socket.data = Buffer.alloc(0); },
    async data(socket, chunk) {
      const data = Buffer.concat([socket.data as Buffer, Buffer.from(chunk)]);
      socket.data = data;
      const end = data.indexOf("\r\n\r\n");
      if (end < 0) return;
      const lines = data.subarray(0, end).toString().split("\r\n");
      const [method, path] = lines.shift()!.split(" ");
      const headers = new Headers();
      for (const line of lines) {
        const colon = line.indexOf(":");
        if (colon > 0) headers.set(line.slice(0, colon).trim(), line.slice(colon + 1).trim());
      }
      const length = Number(headers.get("content-length") || 0);
      if (data.length < end + 4 + length) return;
      socket.data = Buffer.alloc(0);
      headers.delete("host"); headers.delete("connection"); headers.delete("content-length");
      try {
        const body = data.subarray(end + 4, end + 4 + length);
        if (path === "/player/action" && body.toString().includes("retry-500")) {
          const bytes = Buffer.from('{"error":"temporary test failure"}');
          socket.write(`HTTP/1.1 500 Test\r\nContent-Type: application/json\r\nContent-Length: ${bytes.length}\r\nConnection: close\r\n\r\n`);
          socket.end(bytes);
          return;
        }
        const response = await fetch(target + path, { method, headers, body: length ? body : undefined });
        const result = await response.text();
        if (!dropped && path === "/player/action" && body.toString().includes("lost-forge-action")) {
          const state = JSON.parse(result).updated_player_state;
          if (response.status !== 200 || state?.item_progress?.bismuth_talisman?.level !== 1 || state?.wallet?.essence !== 80) throw new Error("Commit was not verified before dropping response");
          dropped = true;
          writeFileSync(marker, JSON.stringify({ committed: true, level: 1, essence: 80 }));
          socket.end();
          return;
        }
        const bytes = Buffer.from(result);
        socket.write(`HTTP/1.1 ${response.status} Test\r\nContent-Type: application/json\r\nContent-Length: ${bytes.length}\r\nConnection: close\r\n\r\n`);
        socket.end(bytes);
      } catch (error) { console.error(error); socket.end(); }
    },
    error(_socket, error) { console.error(error); },
  },
});
console.log(`PROXY_READY ${server.port}`);
