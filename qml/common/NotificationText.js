.pragma library

// Notification text. Bodies arrive as the spec's simple markup (the server advertises
// body-markup); they are reduced to plain text in which http(s) links are kept as
// [label](url), the same form senders use for markdown links. Display code then either renders
// that as StyledText (toStyledText) or drops the link targets (linkLabels / oneLine).

const formattingTags = /<\/?(?:a|b|i|u|s|em|strong|big|small|sub|sup|tt|code|pre|span|font|div|p|br|hr|img|ul|ol|li|h[1-6]|blockquote|q|del|ins|mark)\b(?:\s[^<>]*)?\/?>/gi;
const lineBreakTags = /<(?:br|hr)\b[^<>]*>|<\/(?:p|div|li|h[1-6]|blockquote|pre)\s*>/gi;
const anchorOpenTag = /<a\b([^<>]*)>/gi;
const hrefAttribute = /\bhref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'<>]+))/i;
const anchorToken = /\u0001([^\u0001\u0002\u0003]*)\u0002([^\u0001\u0002\u0003]*)\u0003/g;
const linkPattern = /\[([^\[\]\n]+)\]\((https?:\/\/[^\s()<>"]+)\)|(https?:\/\/[^\s<>"]+)/gi;
const markdownLink = /\[([^\[\]\n]+)\]\((https?:\/\/[^\s()<>"]+)\)/gi;

function text(value) {
    return value === undefined || value === null ? "" : String(value);
}

function codePointText(entity, codePoint) {
    return codePoint > 0 && codePoint <= 0x10FFFF ? String.fromCodePoint(codePoint) : entity;
}

// &amp; last, so "&amp;lt;" stays "&lt;" instead of turning into "<".
function decodeEntities(value) {
    return value
        .replace(/&nbsp;/g, " ")
        .replace(/&quot;/g, "\"")
        .replace(/&#39;|&apos;/g, "'")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&#(\d+);/g, (match, code) => codePointText(match, Number(code)))
        .replace(/&#x([0-9a-fA-F]+);/g, (match, code) => codePointText(match, parseInt(code, 16)))
        .replace(/&amp;/g, "&");
}

function isWebUrl(url) {
    return /^https?:\/\/[^\s\/?#]+/i.test(url);
}

// Characters that would end the URL in [label](url) or in a StyledText href="…" are
// percent-encoded, which addresses the same resource.
function encodeUrl(url) {
    return url.replace(/[\s"<>()]/g, c => "%" + c.charCodeAt(0).toString(16).toUpperCase().padStart(2, "0"));
}

function escapeHtml(value) {
    return value
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

// A bare URL ends before trailing punctuation, quotes and closing brackets it does not open.
// One backward pass over bracket balances counted once.
function trimBareUrl(url) {
    const opening = { ")": "(", "]": "[", "}": "{" };
    const unmatched = { ")": 0, "]": 0, "}": 0 };
    for (let i = 0; i < url.length; i++) {
        const c = url[i];
        if (unmatched[c] !== undefined)
            unmatched[c]++;
        else if (c === "(")
            unmatched[")"]--;
        else if (c === "[")
            unmatched["]"]--;
        else if (c === "{")
            unmatched["}"]--;
    }
    let end = url.length;
    while (end > 0) {
        const last = url[end - 1];
        if (".,;:!?'*_~’”»›".indexOf(last) >= 0) {
            end--;
        } else if (opening[last] !== undefined && unmatched[last] > 0) {
            unmatched[last]--;
            end--;
        } else {
            break;
        }
    }
    return url.slice(0, end);
}

// <a …>label</a> → token(attributes, label). Linear: once no closing tag is left, the rest of
// the text is not searched again for each remaining opening tag.
function replaceAnchors(value, token) {
    const lower = value.toLowerCase();
    let result = "";
    let position = 0;
    anchorOpenTag.lastIndex = 0;
    let open;
    while ((open = anchorOpenTag.exec(value)) !== null) {
        const labelStart = open.index + open[0].length;
        let close = lower.indexOf("</a", labelStart);
        while (close >= 0 && !/[\s>]/.test(lower.charAt(close + 3)))
            close = lower.indexOf("</a", close + 3);
        if (close < 0)
            break;
        const closeEnd = lower.indexOf(">", close);
        if (closeEnd < 0)
            break;
        result += value.slice(position, open.index) + token(open[1], value.slice(labelStart, close));
        position = closeEnd + 1;
        anchorOpenTag.lastIndex = position;
    }
    return result + value.slice(position);
}

function collapseWhitespace(value, multiline) {
    if (!multiline)
        return value.replace(/\s+/g, " ").trim();
    return value
        .replace(/\r\n?/g, "\n")
        .replace(/[^\S\n]+/g, " ")
        .replace(/ ?\n ?/g, "\n")
        .replace(/\n{3,}/g, "\n\n")
        .trim();
}

// Plain text from a notification's markup. Only formatting tags are removed, so "a < b > c"
// or "<name>" survive; line-break tags and newlines become line breaks unless multiline is
// false; http(s) anchors keep their target as [label](url), others keep just their label.
function fromMarkup(markup, multiline) {
    let value = text(markup).replace(/[\u0001-\u0003]/g, "");
    value = replaceAnchors(value, (attributes, label) => {
        const href = attributes.match(hrefAttribute);
        const target = href ? (href[1] !== undefined ? href[1] : href[2] !== undefined ? href[2] : href[3]) : "";
        return "\u0001" + label + "\u0002" + target + "\u0003";
    });
    value = value.replace(lineBreakTags, "\n").replace(formattingTags, "");
    value = decodeEntities(value);
    value = value.replace(anchorToken, (match, label, target) => {
        const url = target.trim();
        const cleanLabel = label.replace(/[\[\]]/g, "").replace(/\s+/g, " ").trim();
        if (!isWebUrl(url))
            return cleanLabel;
        return "[" + (cleanLabel !== "" ? cleanLabel : url) + "](" + encodeUrl(url) + ")";
    });
    return collapseWhitespace(value, multiline !== false);
}

// [label](url) → label.
function linkLabels(value) {
    return text(value).replace(markdownLink, "$1");
}

// One line for compact previews.
function oneLine(value) {
    return collapseWhitespace(linkLabels(value), false);
}

// StyledText for a plain body: every non-link piece is escaped on its own, [label](url) and
// bare http(s) URLs become anchors whose href is the real URL, newlines become <br>.
function toStyledText(value) {
    const source = text(value);
    let result = "";
    let last = 0;
    linkPattern.lastIndex = 0;
    let match;
    while ((match = linkPattern.exec(source)) !== null) {
        let url = match[2];
        let label = match[1];
        let end = linkPattern.lastIndex;
        if (url === undefined) {
            url = trimBareUrl(match[3]);
            label = url;
            end = match.index + url.length;
            linkPattern.lastIndex = Math.max(end, match.index + 1);
            if (!isWebUrl(url))
                continue;
        }
        result += escapeHtml(source.slice(last, match.index));
        result += "<a href=\"" + url + "\">" + escapeHtml(label) + "</a>";
        last = end;
    }
    result += escapeHtml(source.slice(last));
    return result.replace(/\n/g, "<br>");
}
