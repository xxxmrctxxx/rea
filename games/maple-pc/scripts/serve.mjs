// Minimal static server so the game can be played in any browser:
//   npm run serve  ->  http://localhost:5173
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("..", import.meta.url)).replace(
  /[\\/]$/,
  "",
);
const PORT = Number(process.env.PORT) || 5173;
const TYPES = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".css": "text/css",
  ".png": "image/png",
};

http
  .createServer((req, res) => {
    const url = new URL(req.url, "http://localhost");
    const file = path.join(
      ROOT,
      url.pathname === "/" ? "index.html" : decodeURIComponent(url.pathname),
    );
    if (!file.startsWith(ROOT + path.sep)) {
      res.writeHead(403).end();
      return;
    }
    fs.readFile(file, (err, data) => {
      if (err) {
        res.writeHead(404).end("Not found");
        return;
      }
      res.writeHead(200, {
        "Content-Type": TYPES[path.extname(file)] || "application/octet-stream",
      });
      res.end(data);
    });
  })
  .listen(PORT, "127.0.0.1", () =>
    console.log("Maple PC: http://localhost:" + PORT),
  );
