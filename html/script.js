const menu = document.getElementById('hetia-menu');
const tabButtons = document.querySelectorAll('.tab-btn');
const tabContents = document.querySelectorAll('.tab-content');

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'toggle') {
        if (data.show) {
            menu.classList.remove('hidden');
        } else {
            menu.classList.add('hidden');
        }
    }
});

tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
        tabButtons.forEach(b => b.classList.remove('active'));
        tabContents.forEach(c => c.classList.remove('active'));

        btn.classList.add('active');
        const targetTab = document.getElementById(`tab-${btn.dataset.tab}`);
        if (targetTab) targetTab.classList.add('active');
    });
});

document.querySelectorAll('.menu-item').forEach(item => {
    item.addEventListener('click', () => {
        const action = item.dataset.action;
        const value = item.dataset.value || null;

        if (action === 'godmode') {
            const checkbox = document.getElementById('godmode-checkbox');
            checkbox.checked = !checkbox.checked;
            sendToLua('godmode', checkbox.checked);
        } else if (action) {
            sendToLua(action, value);
        }
    });
});

function sendToLua(action, value) {
    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'hetia_nui_temp';

    fetch(`https://${resourceName}/hetiaAction`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            action: action,
            value: value
        })
    }).catch(err => console.error('[Hetia] NUI callback failed:', err));
}

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        sendToLua('close', null);
    }
});