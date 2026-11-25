const svg = document.querySelector('#wheel');
const menu = document.querySelector('#menu');
const hint = document.querySelector('#hint');
const namespace = 'http://www.w3.org/2000/svg';
const pageSize = 8;
let state = null;
let page = 0;
let pending = false;

function element(tag, attributes, parent = svg) {
    const node = document.createElementNS(namespace, tag);
    for (const [key, value] of Object.entries(attributes)) {
        node.setAttribute(key, value);
    }
    parent.append(node);
    return node;
}

function point(radius, angle) {
    return [200 + radius * Math.cos(angle), 200 + radius * Math.sin(angle)];
}

function sector(inner, outer, start, end) {
    const large = end - start > Math.PI ? 1 : 0;
    return `M${point(outer, start)} A${outer},${outer} 0 ${large} 1 ${point(outer, end)} L${point(inner, end)} A${inner},${inner} 0 ${large} 0 ${point(inner, start)} Z`;
}

function text(parent, x, y, label, className = '') {
    const node = element('text', { x, y, class: className, 'text-anchor': 'middle' }, parent);
    node.textContent = label;
}

function icon(parent, name, x, y, size) {
    if (typeof name === 'string' && /^(https:\/\/|nui:\/\/)/.test(name)) {
        element('image', { href: name, x: x-size/2, y: y-size/2, width: size, height: size }, parent);
        return;
    }
    const key = String(name || '').split(/\s+/).pop().replace(/^fa-/, '');
    const [width, height, paths] = Object.hasOwn(solidIcons, key) ? solidIcons[key] : solidIcons['circle-dot'];
    const node = element('svg', { x: x-size/2, y: y-size/2, width: size, height: size, viewBox: `0 0 ${width} ${height}`, class: 'glyph' }, parent);
    for (const path of [].concat(paths)) element('path', { d: path, fill: 'currentColor' }, node);
}

async function post(action, body = {}) {
    if (pending || typeof GetParentResourceName !== 'function') return;
    pending = true;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3000);
    try {
        const response = await fetch(`https://${GetParentResourceName()}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
            signal: controller.signal
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
    } catch (error) {
        console.warn(`[radial] ${action}: ${error.message}`);
    } finally {
        clearTimeout(timeout);
        pending = false;
    }
}

function activate(node, callback) {
    node.addEventListener('click', callback);
    node.addEventListener('keydown', event => {
        if (event.key !== 'Enter' && event.key !== ' ') return;
        event.preventDefault();
        callback();
    });
}

function labelLines(label) {
    const lines = [''];
    for (const word of String(label).split(' ')) {
        const next = `${lines.at(-1)} ${word}`.trim();
        if (next.length > 15 && lines.at(-1)) lines.push(word);
        else lines[lines.length - 1] = next;
    }
    return lines.slice(0, 2).map((line, index) => {
        return line.length > 16 || (index === 1 && lines.length > 2) ? `${line.slice(0, 14)}…` : line;
    });
}

function render() {
    if (!state) return;
    svg.replaceChildren();
    const pages = Math.max(1, Math.ceil(state.items.length / pageSize));
    page = Math.min(page, pages - 1);
    const items = state.items.slice(page * pageSize, (page + 1) * pageSize);
    const slots = Math.max(3, items.length);
    const step = Math.PI * 2 / slots;
    const start = -Math.PI / 2 - step / 2;
    const revision = state.revision;
    for (let index = 0; index < slots; index++) {
        const a = start + index * step + .015;
        const b = a + step - .03;
        const middle = (a + b) / 2;
        const item = items[index];
        const group = element('g', item ? { class: 'option', tabindex: 0, role: 'button', 'aria-label': item.label } : { class: 'empty' });
        element('path', { d: sector(68, 190, a, b), class: 'slice' }, group);
        if (!item) continue;
        const [x, y] = point(128, middle);
        icon(group, item.icon, x, y - 12, 22);
        labelLines(item.label).forEach((line, row) => text(group, x, y + 13 + row * 12, line));
        if (item.menu) {
            const [cx, cy] = point(177, middle);
            element('circle', { cx, cy, r: 2, class: 'submenu-dot' }, group);
        }
        const selection = { index: page * pageSize + index + 1, id: item.id, revision };
        activate(group, () => post('select', selection));
        group.addEventListener('mouseenter', () => { hint.textContent = item.label; });
        group.addEventListener('mouseleave', () => { hint.textContent = state?.title || 'Menu'; });
    }
    const hub = element('g', { class: 'hub', tabindex: 0, role: 'button', 'aria-label': state.back ? 'Tilbage' : 'Luk' });
    element('circle', { cx: 200, cy: 200, r: 59 }, hub);
    icon(hub, state.back ? 'arrow-left' : 'xmark', 200, 190, 20);
    text(hub, 200, 218, state.back ? 'Tilbage' : 'Luk', 'centertext');
    activate(hub, () => post(state.back ? 'back' : 'close'));
    hint.textContent = state.title || 'Menu';
    document.querySelector('#pages').hidden = pages <= 1;
    document.querySelector('#count').textContent = `${page + 1} / ${pages}`;
}

function move(direction) {
    if (!state) return;
    const pages = Math.max(1, Math.ceil(state.items.length / pageSize));
    if (pages <= 1) return;
    page = (page + direction + pages) % pages;
    render();
}

document.querySelector('#prev').addEventListener('click', () => move(-1));
document.querySelector('#next').addEventListener('click', () => move(1));
window.addEventListener('message', ({ data }) => {
    if (!data || typeof data !== 'object') return;
    if (data.action === 'hide') {
        menu.hidden = true;
        state = null;
        page = 0;
    } else if (data.action === 'show' && Array.isArray(data.items)) {
        if (!state || state.menuId !== data.menuId) page = 0;
        state = data;
        if (Number.isFinite(data.width)) menu.style.setProperty('--menu-width', `${Math.max(280, Math.min(600, data.width))}px`);
        if (typeof data.accent === 'string' && CSS.supports('color', data.accent)) menu.style.setProperty('--accent', data.accent);
        menu.hidden = false;
        render();
    }
});
document.addEventListener('keydown', event => {
    if (!state || event.repeat) return;
    if (event.key === 'Escape') post('close');
    else if (event.key === 'Backspace') post('back');
    else if (event.key === 'ArrowLeft') move(-1);
    else if (event.key === 'ArrowRight') move(1);
});
document.addEventListener('wheel', event => {
    if (state && event.deltaY) move(event.deltaY > 0 ? 1 : -1);
}, { passive: true });
