import { addMessagePreSendListener, removeMessagePreSendListener } from "@api/MessageEvents";
import { definePluginSettings } from "@api/Settings";
import definePlugin, { OptionType, PluginNative } from "@utils/types";

const Native = VencordNative.pluginHelpers.AlwaysAudioFiles as PluginNative<typeof import("./native")>;

const EXT = "mp3|mp2|mpga|wav|wave|ogg|oga|opus|spx|m4a|m4b|aac|flac|wma|aif|aiff|aifc|amr|weba|mka|mid|midi|caf|ac3|ape|wv";
const RE = new RegExp(`https?:\\/\\/[^\\s<>]+?\\.(?:${EXT})(?=[?#\\s<>]|$)[^\\s<>]*`, "gi");

const settings = definePluginSettings({
    sendLink: {
        type: OptionType.BOOLEAN,
        description: "Keep the original link in the message along with the file",
        default: false,
    },
    autoSend: {
        type: OptionType.BOOLEAN,
        description: "Send the message automatically after attaching the file",
        default: true,
    },
});

let busy = false;
let bypass = false;
let stripNext = false;

const strip = (s: string) => s.replace(RE, "").replace(/\s{2,}/g, " ").trim();

function fileName(url: string) {
    const last = new URL(url).pathname.split("/").pop() || "audio";
    try { return decodeURIComponent(last); } catch { return last; }
}

function setText(box: HTMLElement, text: string) {
    box.focus();
    document.execCommand("selectAll");
    document.execCommand(text ? "insertText" : "delete", false, text);
}

async function onKey(e: KeyboardEvent) {
    if (e.key !== "Enter" || e.shiftKey || busy) return;

    const box = (e.target as HTMLElement | null)?.closest?.('[role="textbox"]') as HTMLElement | null;
    if (!box) return;

    if (bypass) { bypass = false; return; }

    const text = box.innerText;
    const links = [...new Set(text.match(RE) ?? [])];
    if (!links.length) return;

    e.preventDefault();
    e.stopImmediatePropagation();
    busy = true;

    try {
        const files = await Promise.all(links.map(async url => {
            const { data, type } = await Native.fetchAudio(url);
            return new File([data], fileName(url), { type });
        }));

        const { sendLink, autoSend } = settings.store;
        stripNext = !sendLink;
        bypass = sendLink && !autoSend;
        if (!sendLink) setText(box, strip(text));

        for (const f of files) {
            const dt = new DataTransfer();
            dt.items.add(f);
            box.dispatchEvent(new ClipboardEvent("paste", { clipboardData: dt, bubbles: true, cancelable: true }));
        }

        if (autoSend) {
            setTimeout(() => box.dispatchEvent(new KeyboardEvent("keydown", {
                key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true, cancelable: true
            })), 600);
        }
    } catch (err) {
        console.error("[AlwaysAudioFiles] failed, press Enter again to send the plain link", err);
        bypass = true;
        stripNext = false;
    }

    setTimeout(() => (busy = false), 1000);
}

function preSend(_: string, msg: { content: string; }) {
    if (stripNext && !settings.store.sendLink) msg.content = strip(msg.content);
    stripNext = false;
}

export default definePlugin({
    name: "AlwaysAudioFiles",
    description: "Converts audio file links into real file uploads",
    authors: [{ name: "ItzMeShadow999", id: 1065604516399026176n }],
    settings,
    start() {
        document.addEventListener("keydown", onKey, true);
        addMessagePreSendListener(preSend);
    },
    stop() {
        document.removeEventListener("keydown", onKey, true);
        removeMessagePreSendListener(preSend);
    },
});
