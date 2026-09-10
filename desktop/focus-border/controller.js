// SPDX-License-Identifier: MIT
// This controller is shared by the legacy and ES-module entry points.
class FocusBorder {
    enable() {
        this._signals = [];
        this._windowSignals = [];
        this._window = null;
        this._overviewVisible = Main.overview.visible;
        this._border = new St.Widget({
            reactive: false,
            can_focus: false,
            visible: false,
            style: 'border: 4px solid #04d9ff; border-radius: 6px; background-color: transparent;',
        });
        global.window_group.add_child(this._border);
        this._connect(global.display, 'notify::focus-window', () => this._focusChanged());
        this._connect(global.display, 'restacked', () => this._focusChanged());
        this._connect(global.workspace_manager, 'active-workspace-changed', () => this._update());
        this._connect(Main.overview, 'showing', () => {
            this._overviewVisible = true;
            this._update();
        });
        this._connect(Main.overview, 'hidden', () => {
            this._overviewVisible = false;
            this._update();
        });
        this._connect(Main.sessionMode, 'updated', () => this._update());
        this._focusChanged();
    }

    _connect(object, signal, callback) {
        this._signals.push([object, object.connect(signal, callback)]);
    }

    _detachWindow() {
        for (const [object, id] of this._windowSignals)
            object.disconnect(id);
        this._windowSignals = [];
        this._window = null;
    }

    _focusChanged() {
        const window = global.display.focus_window;
        if (window !== this._window) {
            this._detachWindow();
            this._window = window;
            if (window) {
                for (const signal of ['position-changed', 'size-changed', 'workspace-changed', 'notify::minimized', 'notify::fullscreen'])
                    this._windowSignals.push([window, window.connect(signal, () => this._update())]);
                this._windowSignals.push([window, window.connect('unmanaged', () => {
                    this._detachWindow();
                    this._border.hide();
                })]);
            }
        }
        this._update();
    }

    _update() {
        const window = this._window;
        if (!window || this._overviewVisible || Main.sessionMode.isLocked ||
            window.minimized || window.is_fullscreen() || !window.showing_on_its_workspace() ||
            ![Meta.WindowType.NORMAL, Meta.WindowType.DIALOG, Meta.WindowType.MODAL_DIALOG].includes(window.get_window_type())) {
            this._border.hide();
            return;
        }
        const rect = window.get_frame_rect();
        this._border.set_position(rect.x, rect.y);
        this._border.set_size(rect.width, rect.height);
        global.window_group.set_child_above_sibling(this._border, null);
        this._border.show();
    }

    disable() {
        this._detachWindow();
        for (const [object, id] of this._signals)
            object.disconnect(id);
        this._signals = [];
        this._border.destroy();
        this._border = null;
    }
}
