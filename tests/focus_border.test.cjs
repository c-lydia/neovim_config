const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test} = require('node:test');

class Signals {
    constructor() { this.callbacks = new Map(); this.next = 0; }
    connect(name, callback) { const id = ++this.next; this.callbacks.set(id, [name, callback]); return id; }
    disconnect(id) { this.callbacks.delete(id); }
    emit(name) { for (const [signal, callback] of [...this.callbacks.values()]) if (signal === name) callback(); }
}

function fixture() {
    const display = new Signals();
    const workspace = new Signals();
    const overview = Object.assign(new Signals(), {visible: false});
    const sessionMode = Object.assign(new Signals(), {isLocked: false});
    let border;
    class Widget {
        constructor(options) { Object.assign(this, options); border = this; }
        set_position(x, y) { this.position = [x, y]; }
        set_size(w, h) { this.size = [w, h]; }
        show() { this.visible = true; }
        hide() { this.visible = false; }
        destroy() { this.destroyed = true; }
    }
    const group = {add_child() {}, set_child_above_sibling() {}};
    const context = vm.createContext({St: {Widget}, Meta: {WindowType: {NORMAL: 0, DIALOG: 1, MODAL_DIALOG: 2}},
        Main: {overview, sessionMode}, global: {display, workspace_manager: workspace, window_group: group}});
    const source = fs.readFileSync(path.join(__dirname, '../desktop/focus-border/controller.js'), 'utf8');
    const controller = vm.runInContext(source + '\nnew FocusBorder()', context);
    controller.enable();
    return {controller, display, workspace, overview, sessionMode, get border() { return border; }};
}

function window() {
    return Object.assign(new Signals(), {
        rect: {x: 10, y: 20, width: 800, height: 600}, minimized: false, fullscreen: false, active: true, type: 0,
        get_frame_rect() { return this.rect; }, is_fullscreen() { return this.fullscreen; },
        showing_on_its_workspace() { return this.active; }, get_window_type() { return this.type; },
    });
}

test('border follows focus, move and resize without capturing input', () => {
    const f = fixture();
    const first = window();
    f.display.focus_window = first;
    f.display.emit('notify::focus-window');
    assert.equal(f.border.reactive, false);
    assert.equal(f.border.can_focus, false);
    assert.match(f.border.style, /4px solid #04d9ff/);
    assert.deepEqual(f.border.position, [10, 20]);
    first.rect = {x: 70, y: 80, width: 500, height: 400};
    first.emit('size-changed');
    assert.deepEqual(f.border.position, [70, 80]);
    assert.deepEqual(f.border.size, [500, 400]);
    const second = window();
    f.display.focus_window = second;
    f.display.emit('notify::focus-window');
    assert.equal(first.callbacks.size, 0);
    f.controller.disable();
    assert.equal(second.callbacks.size, 0);
    assert.equal(f.display.callbacks.size, 0);
    assert.equal(f.overview.callbacks.size, 0);
    assert.equal(f.border.destroyed, true);
});

test('border hides in overview, lock screen, fullscreen and other workspaces', () => {
    const f = fixture();
    const active = window();
    f.display.focus_window = active;
    f.display.emit('restacked');
    assert.equal(f.border.visible, true);
    f.overview.emit('showing');
    assert.equal(f.border.visible, false);
    f.overview.emit('hidden');
    assert.equal(f.border.visible, true);
    f.sessionMode.isLocked = true;
    f.sessionMode.emit('updated');
    assert.equal(f.border.visible, false);
    f.sessionMode.isLocked = false;
    active.fullscreen = true;
    active.emit('notify::fullscreen');
    assert.equal(f.border.visible, false);
    active.fullscreen = false;
    active.active = false;
    f.workspace.emit('active-workspace-changed');
    assert.equal(f.border.visible, false);
    active.active = true;
    active.emit('unmanaged');
    assert.equal(f.border.visible, false);
    assert.equal(active.callbacks.size, 0);
    f.controller.disable();
});
