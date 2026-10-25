import { lookup } from "dns/promises";
import { IpcMainInvokeEvent } from "electron";

const PRIVATE_RE = /^(0\.|10\.|127\.|169\.254\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|::1$|::$|f[cd]|fe80)/i;
const MAX_BYTES = 25 * 1024 * 1024;
const MAX_REDIRECTS = 5;

const MIME: Record<string, string> = {
    mp3: "audio/mpeg", mp2: "audio/mpeg", mpga: "audio/mpeg",
    wav: "audio/wav", wave: "audio/wav",
    ogg: "audio/ogg", oga: "audio/ogg", opus: "audio/ogg", spx: "audio/ogg",
    m4a: "audio/mp4", m4b: "audio/mp4", aac: "audio/aac", flac: "audio/flac",
    wma: "audio/x-ms-wma", aif: "audio/aiff", aiff: "audio/aiff", aifc: "audio/aiff",
    amr: "audio/amr", weba: "audio/webm", mka: "audio/x-matroska",
    mid: "audio/midi", midi: "audio/midi", caf: "audio/x-caf",
    ac3: "audio/ac3", ape: "audio/x-ape", wv: "audio/x-wavpack",
};

const EXT_RE = new RegExp(`\\.(${Object.keys(MIME).join("|")})$`, "i");

export async function fetchAudio(_: IpcMainInvokeEvent, url: string) {
    let u = new URL(url);
    if (!EXT_RE.test(u.pathname)) throw new Error("URL not allowed");

    let res: Response;
    for (let i = 0; ; i++) {
        if (u.protocol !== "https:" && u.protocol !== "http:") throw new Error("URL not allowed");

        const addrs = await lookup(u.hostname, { all: true });
        if (addrs.some(a => PRIVATE_RE.test(a.address.replace(/^::ffff:/i, "")))) throw new Error("Private address blocked");

        res = await fetch(u, { redirect: "manual" });

        const next = res.headers.get("location");
        if (res.status < 300 || res.status >= 400 || !next) break;
        if (i === MAX_REDIRECTS) throw new Error("Too many redirects");
        u = new URL(next, u);
    }
    if (!res.ok) throw new Error("HTTP " + res.status);
    if (Number(res.headers.get("content-length")) > MAX_BYTES) throw new Error("File too large");

    let total = 0;
    const capped = res.body!.pipeThrough(new TransformStream<Uint8Array, Uint8Array>({
        transform(chunk, ctl) {
            if ((total += chunk.byteLength) > MAX_BYTES) ctl.error(new Error("File too large"));
            else ctl.enqueue(chunk);
        },
    }));
    const data = await new Response(capped).arrayBuffer();

    let type = (res.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
    if (type.startsWith("text/")) throw new Error("Not an audio file");
    if (!type.startsWith("audio/")) {
        const ext = u.pathname.match(EXT_RE)?.[1].toLowerCase() ?? "mp3";
        type = MIME[ext] ?? "audio/mpeg";
    }
    return { data, type };
}
