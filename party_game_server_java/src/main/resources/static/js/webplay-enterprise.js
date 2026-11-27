(function () {
    'use strict';

    const SIDEBAR_STORAGE_KEY = 'pg_ent_sidebar_collapsed';

    const GAME_META = {
        take6: {
            key: 'take6',
            name: '谁是牛头王',
            shortName: '牛头王',
            icon: '🐂',
            maxPlayers: 6,
            tagClass: 'take6'
        },
        liars_dice: {
            key: 'liars_dice',
            name: '大话骰吹牛',
            shortName: '大话骰',
            icon: '🎲',
            maxPlayers: 6,
            tagClass: 'dice'
        },
        party_wheel: {
            key: 'party_wheel',
            name: '聚会大转盘',
            shortName: '大转盘',
            icon: '🎡',
            maxPlayers: 8,
            tagClass: 'wheel'
        },
        undercover: {
            key: 'undercover',
            name: '谁是卧底',
            shortName: '谁是卧底',
            icon: '🕵️',
            maxPlayers: 8,
            tagClass: 'undercover'
        }
    };

    const state = {
        initialized: false,
        roomFilter: 'all',
        roomSearch: '',
        createGame: 'take6',
        isCreatingRoom: false,
        cmdSelectedIndex: 0,
        cmdFilteredItems: [],
        lastFocusedBeforeCmd: null
    };

    if (!Array.isArray(window.__entRoomsCache)) {
        window.__entRoomsCache = [];
    }

    function escapeHtml(val) {
        return String(val == null ? '' : val)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function getPrefix() {
        if (window.location && window.location.pathname && window.location.pathname.startsWith('/party-game')) {
            return '/party-game';
        }
        if (typeof window.getApiPrefix === 'function') {
            return window.getApiPrefix() || '';
        }
        return '';
    }

    function buildHeaders(includeJson) {
        const headers = {};
        if (includeJson) headers['Content-Type'] = 'application/json';
        try {
            if (typeof window.getAuthHeaders === 'function') {
                const base = window.getAuthHeaders();
                if (base && typeof base === 'object') {
                    Object.keys(base).forEach(function (k) {
                        if (includeJson || k.toLowerCase() !== 'content-type') {
                            headers[k] = base[k];
                        }
                    });
                }
            } else {
                const tok = localStorage.getItem('pg_auth_token') || localStorage.getItem('fwpt_auth_token');
                if (tok) headers['Authorization'] = 'Bearer ' + tok;
            }
        } catch (e) {}
        return headers;
    }

    function notifyUser(msg) {
        if (typeof window.showToast === 'function') {
            window.showToast(msg);
        } else {
            console.info('[EnterpriseLobby]', msg);
        }
    }

    function getUserIdentity() {
        let id = '';
        let name = '';
        let avatar = '';

        const profileUidEl = document.getElementById('profileUidText');
        if (profileUidEl) {
            const match = (profileUidEl.textContent || '').match(/UID:\s*([^\s·]+)/);
            if (match && match[1]) id = match[1].trim();
        }
        if (!id) {
            const headerUidEl = document.getElementById('lobbyUserUidText');
            const rawUid = headerUidEl ? (headerUidEl.textContent || '').trim() : '';
            if (rawUid && rawUid !== '未登录') id = rawUid;
        }
        if (!id) {
            try {
                const rawFwpt = localStorage.getItem('fwpt_auth_user');
                if (rawFwpt) {
                    const fu = JSON.parse(rawFwpt);
                    if (fu && fu.id) id = String(fu.id);
                    if (fu && !name) name = fu.nickname || fu.username || '';
                    if (fu && !avatar) avatar = fu.avatar || '';
                }
            } catch (e) {}
        }
        if (!id) {
            id = 'WEB' + Math.floor(100000 + Math.random() * 899999);
        }

        if (!name) {
            const nameEl = document.getElementById('lobbyUserName');
            const rawName = nameEl ? (nameEl.textContent || '').trim() : '';
            name = (rawName && rawName !== '玩家昵称') ? rawName : '玩家';
        }
        if (!avatar) {
            const avEl = document.getElementById('lobbyUserAvatar');
            const rawAv = avEl ? (avEl.textContent || '').trim() : '';
            avatar = rawAv || '🦊';
        }
        return { id: id, name: name, avatar: avatar };
    }

    function isElementVisible(el) {
        if (!el) return false;
        if (el.style && el.style.display === 'none') return false;
        const cs = window.getComputedStyle ? window.getComputedStyle(el) : null;
        return cs ? cs.display !== 'none' && cs.visibility !== 'hidden' : el.offsetParent !== null;
    }

    /* =========================================================================
       1. Sidebar Collapse (Persistence + Toggle)
       ========================================================================= */
    function applySidebarCollapsed(collapsed) {
        if (!document.body) return;
        document.body.classList.toggle('ent-sidebar-collapsed', Boolean(collapsed));
        const btn = document.getElementById('btnToggleSidebar');
        if (btn) {
            btn.setAttribute('aria-expanded', String(!collapsed));
            btn.setAttribute('title', collapsed ? '展开侧边导航' : '收起侧边导航');
        }
    }

    function initSidebarCollapse() {
        let saved = false;
        try {
            const raw = localStorage.getItem(SIDEBAR_STORAGE_KEY);
            saved = raw === '1' || raw === 'true';
        } catch (e) {}
        applySidebarCollapsed(saved);

        const btn = document.getElementById('btnToggleSidebar');
        if (btn && !btn.dataset.entBound) {
            btn.dataset.entBound = '1';
            btn.addEventListener('click', function () {
                const next = !document.body.classList.contains('ent-sidebar-collapsed');
                applySidebarCollapsed(next);
                try {
                    localStorage.setItem(SIDEBAR_STORAGE_KEY, next ? '1' : '0');
                } catch (e) {}
            });
        }
    }

    /* =========================================================================
       2. Live Room Browser & Counters
       ========================================================================= */
    function getGameMeta(gameType) {
        return GAME_META[gameType] || GAME_META.take6;
    }

    function updateRoomCounters(rooms) {
        const list = Array.isArray(rooms) ? rooms : [];
        const total = list.length;
        let waiting = 0;
        const perGame = {
            take6: 0,
            liars_dice: 0,
            party_wheel: 0,
            undercover: 0
        };

        list.forEach(function (r) {
            if (!r) return;
            const status = String(r.status || 'WAITING').toUpperCase();
            if (status !== 'PLAYING') waiting++;
            const gType = r.gameType || 'take6';
            if (Object.prototype.hasOwnProperty.call(perGame, gType)) {
                perGame[gType]++;
            }
        });

        const sidebarCount = document.getElementById('sidebarRoomCount');
        if (sidebarCount) sidebarCount.textContent = String(total);

        const heroOnline = document.getElementById('heroOnlineRoomsCount');
        if (heroOnline) heroOnline.textContent = String(total);

        const heroWaiting = document.getElementById('heroWaitingRoomsCount');
        if (heroWaiting) heroWaiting.textContent = String(waiting);

        Object.keys(perGame).forEach(function (gKey) {
            const el = document.getElementById('gameLiveCount_' + gKey);
            if (el) {
                const c = perGame[gKey];
                el.textContent = String(c);
                el.dataset.count = String(c);
            }
        });
    }

    function getFilteredRooms() {
        const all = Array.isArray(window.__entRoomsCache) ? window.__entRoomsCache : [];
        const q = state.roomSearch.trim().toLowerCase();
        const f = state.roomFilter;

        return all.filter(function (r) {
            if (!r) return false;
            const gType = r.gameType || 'take6';
            const status = String(r.status || 'WAITING').toUpperCase();

            if (f === 'WAITING') {
                if (status === 'PLAYING') return false;
            } else if (f !== 'all') {
                if (gType !== f) return false;
            }

            if (q) {
                const meta = getGameMeta(gType);
                const code = String(r.roomCode || '').toLowerCase();
                const name = String(r.roomName || '').toLowerCase();
                const host = r.hostPlayer ? String(r.hostPlayer.name || r.hostPlayer.nickname || '').toLowerCase() : '';
                const gName = (meta.name + ' ' + meta.shortName).toLowerCase();
                if (!code.includes(q) && !name.includes(q) && !host.includes(q) && !gName.includes(q)) {
                    return false;
                }
            }
            return true;
        });
    }

    function renderRoomSkeleton(container) {
        if (!container) return;
        const rows = [];
        for (let i = 0; i < 3; i++) {
            rows.push('<div class="ent-room-skeleton" aria-hidden="true"></div>');
        }
        container.innerHTML = rows.join('');
    }

    function renderRoomList() {
        const container = document.getElementById('lobbyRoomList');
        const countBadge = document.getElementById('lobbyRoomCountBadge');
        if (!container) return;

        const all = Array.isArray(window.__entRoomsCache) ? window.__entRoomsCache : [];
        const filtered = getFilteredRooms();

        if (countBadge) {
            countBadge.textContent = String(filtered.length);
        }

        if (all.length === 0) {
            container.innerHTML =
                '<div class="ent-room-empty">' +
                '<div class="ent-room-empty-icon">🎲</div>' +
                '<div class="ent-room-empty-title">当前暂无公开房间</div>' +
                '<div class="ent-room-empty-sub">立即新建一桌，邀请好友或在线牌友开黑</div>' +
                '<button type="button" class="ent-btn-create-room" data-ent-empty-create="1">➕ 创建专属房间</button>' +
                '</div>';
            return;
        }

        if (filtered.length === 0) {
            container.innerHTML =
                '<div class="ent-room-empty">' +
                '<div class="ent-room-empty-icon">🔍</div>' +
                '<div class="ent-room-empty-title">暂无匹配的房间</div>' +
                '<div class="ent-room-empty-sub">换个筛选条件或清空搜索关键词试试</div>' +
                '<button type="button" class="ent-room-reset-btn" data-ent-reset-filter="1">重置筛选</button>' +
                '</div>';
            return;
        }

        container.innerHTML = filtered.map(function (r) {
            const gType = r.gameType || 'take6';
            const meta = getGameMeta(gType);
            const code = String(r.roomCode || '');
            const isPlaying = String(r.status || 'WAITING').toUpperCase() === 'PLAYING';
            const allowSpectator = r.allowSpectator !== false;
            const players = Array.isArray(r.players) ? r.players : [];
            const pCount = players.length || 1;
            const maxPlayers = Number(r.maxPlayers) || meta.maxPlayers || 6;
            const hostName = (r.hostPlayer && (r.hostPlayer.name || r.hostPlayer.nickname))
                || (players[0] && (players[0].name || players[0].nickname))
                || '房主';
            const roomTitle = r.roomName || (hostName + ' 的牌桌');
            const statusClass = isPlaying ? 'playing' : 'waiting';
            const statusText = isPlaying ? '对战中' : '组队中';
            const specText = allowSpectator ? '👁️ 可旁观' : '🔒 禁旁观';
            const canJoin = !isPlaying || allowSpectator;
            const joinLabel = isPlaying ? (allowSpectator ? '旁观' : '已满/禁观') : '加入';

            return (
                '<div class="ent-room-card room-item-row" data-room-code="' + escapeHtml(code) + '" data-game-type="' + escapeHtml(gType) + '">' +
                    '<div class="ent-room-card-main">' +
                        '<div class="ent-room-card-top">' +
                            '<span class="ent-room-game-tag ' + escapeHtml(meta.tagClass) + '">' + meta.icon + ' ' + escapeHtml(meta.shortName) + '</span>' +
                            '<span class="ent-room-status ' + statusClass + '">' + statusText + '</span>' +
                            '<span class="ent-room-code room-code-title pg-title tabular-nums" style="font-size:12.5px; font-weight:800;">#' + escapeHtml(code) + '</span>' +
                        '</div>' +
                        '<div class="ent-room-title pg-title" style="font-size:13px; font-weight:700; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">' + escapeHtml(roomTitle) + '</div>' +
                        '<div class="ent-room-meta pg-sub">' +
                            '<span>房主 ' + escapeHtml(hostName) + '</span>' +
                            '<span class="tabular-nums">👥 ' + pCount + '/' + maxPlayers + '</span>' +
                            '<span class="ent-room-spec ' + (allowSpectator ? 'on' : 'off') + '">' + specText + '</span>' +
                        '</div>' +
                    '</div>' +
                    '<button type="button" class="ent-room-join-btn ' + (isPlaying ? 'is-spectate' : '') + '"' +
                        (canJoin ? '' : ' disabled') +
                        ' data-room="' + escapeHtml(code) + '"' +
                        ' data-game="' + escapeHtml(gType) + '">' +
                        escapeHtml(joinLabel) +
                    '</button>' +
                '</div>'
            );
        }).join('');
    }

    function bindRoomBrowserEvents() {
        const filterBar = document.getElementById('roomFilterBar');
        if (filterBar && !filterBar.dataset.entBound) {
            filterBar.dataset.entBound = '1';
            filterBar.addEventListener('click', function (e) {
                const pill = e.target.closest('[data-room-filter]');
                if (!pill) return;
                const val = pill.getAttribute('data-room-filter') || 'all';
                state.roomFilter = val;
                filterBar.querySelectorAll('[data-room-filter]').forEach(function (el) {
                    el.classList.toggle('active', el === pill);
                });
                renderRoomList();
            });
        }

        const searchInput = document.getElementById('inputSearchRoomCode');
        if (searchInput && !searchInput.dataset.entBound) {
            searchInput.dataset.entBound = '1';
            searchInput.addEventListener('input', function () {
                state.roomSearch = searchInput.value || '';
                renderRoomList();
            });
        }

        const roomList = document.getElementById('lobbyRoomList');
        if (roomList && !roomList.dataset.entBound) {
            roomList.dataset.entBound = '1';
            roomList.addEventListener('click', function (e) {
                const joinBtn = e.target.closest('.ent-room-join-btn');
                if (joinBtn && !joinBtn.disabled) {
                    const code = joinBtn.getAttribute('data-room');
                    const gType = joinBtn.getAttribute('data-game') || 'take6';
                    if (code && typeof window.joinSpecificRoom === 'function') {
                        window.joinSpecificRoom(code, gType);
                    }
                    return;
                }
                const emptyCreate = e.target.closest('[data-ent-empty-create]');
                if (emptyCreate) {
                    if (typeof window.openCreateRoomModal === 'function') {
                        window.openCreateRoomModal(state.roomFilter !== 'all' && state.roomFilter !== 'WAITING' ? state.roomFilter : 'take6');
                    } else if (typeof window.createRoomQuick === 'function') {
                        window.createRoomQuick('take6');
                    }
                    return;
                }
                const resetBtn = e.target.closest('[data-ent-reset-filter]');
                if (resetBtn) {
                    state.roomFilter = 'all';
                    state.roomSearch = '';
                    if (searchInput) searchInput.value = '';
                    if (filterBar) {
                        filterBar.querySelectorAll('[data-room-filter]').forEach(function (el) {
                            el.classList.toggle('active', el.getAttribute('data-room-filter') === 'all');
                        });
                    }
                    renderRoomList();
                }
            });
        }
    }

    function wrapRefreshLobbyRooms() {
        if (window.refreshLobbyRooms && window.refreshLobbyRooms.__entWrapped) return;
        const origRefresh = typeof window.refreshLobbyRooms === 'function' ? window.refreshLobbyRooms : null;

        const wrappedRefresh = async function () {
            const container = document.getElementById('lobbyRoomList');
            if (!container) {
                return origRefresh ? origRefresh.apply(this, arguments) : undefined;
            }
            renderRoomSkeleton(container);
            try {
                const res = await fetch(getPrefix() + '/api/rooms', {
                    headers: buildHeaders(false),
                    credentials: 'same-origin'
                });
                const data = await res.json();
                const list = Array.isArray(data && data.data) ? data.data : [];
                window.__entRoomsCache = list;
                updateRoomCounters(list);
                renderRoomList();
                return list;
            } catch (e) {
                container.innerHTML =
                    '<div class="ent-room-empty">' +
                    '<div style="color:#ef4444; font-size:12px; font-weight:600;">拉取实时房间失败，请检查网络连接</div>' +
                    '<button type="button" class="ent-room-reset-btn" onclick="refreshLobbyRooms()">🔄 重新拉取</button>' +
                    '</div>';
                return [];
            }
        };
        wrappedRefresh.__entWrapped = true;
        window.refreshLobbyRooms = wrappedRefresh;
    }

    /* =========================================================================
       3. Custom Create Room Modal (#createRoomModal)
       ========================================================================= */
    window.selectCreateRoomGame = function (gameType) {
        const key = Object.prototype.hasOwnProperty.call(GAME_META, gameType) ? gameType : 'take6';
        state.createGame = key;
        document.querySelectorAll('#createRoomModal .ent-create-game-opt').forEach(function (opt) {
            const isSelected = opt.getAttribute('data-game') === key;
            opt.classList.toggle('selected', isSelected);
            opt.setAttribute('aria-pressed', String(isSelected));
        });
    };

    window.openCreateRoomModal = function (defaultGame) {
        const modal = document.getElementById('createRoomModal');
        if (!modal) {
            if (typeof window.createRoomQuick === 'function') {
                window.createRoomQuick(defaultGame || 'take6');
            }
            return;
        }
        window.selectCreateRoomGame(defaultGame || 'take6');
        const nameInput = document.getElementById('inputCustomRoomName');
        const identity = getUserIdentity();
        if (nameInput) {
            nameInput.placeholder = identity.name + '的对决房';
        }
        const specChk = document.getElementById('chkCustomAllowSpectator');
        if (specChk && typeof specChk.checked === 'boolean' && specChk.dataset.entInit !== '1') {
            specChk.checked = true;
            specChk.dataset.entInit = '1';
        }
        modal.style.display = 'flex';
        if (nameInput) {
            requestAnimationFrame(function () {
                try { nameInput.focus(); } catch (e) {}
            });
        }
    };

    window.closeCreateRoomModal = function () {
        const modal = document.getElementById('createRoomModal');
        if (modal) modal.style.display = 'none';
    };

    window.submitCustomCreateRoom = async function () {
        if (state.isCreatingRoom) return;
        state.isCreatingRoom = true;

        const btn = document.getElementById('btnConfirmCreateRoom');
        const origBtnText = btn ? btn.textContent : '';
        if (btn) {
            btn.disabled = true;
            btn.textContent = '正在创建房间...';
        }

        const identity = getUserIdentity();
        const nameInput = document.getElementById('inputCustomRoomName');
        const specChk = document.getElementById('chkCustomAllowSpectator');
        const gameType = state.createGame || 'take6';
        const rawName = nameInput ? nameInput.value.trim() : '';
        const roomName = rawName || (identity.name + '的对决房');
        const allowSpectator = specChk ? Boolean(specChk.checked) : true;
        const newCode = String(Math.floor(100000 + Math.random() * 900000));

        try {
            const res = await fetch(getPrefix() + '/api/rooms/create', {
                method: 'POST',
                headers: buildHeaders(true),
                credentials: 'same-origin',
                body: JSON.stringify({
                    roomCode: newCode,
                    roomName: roomName,
                    gameType: gameType,
                    allowSpectator: allowSpectator,
                    hostPlayer: {
                        id: identity.id,
                        name: identity.name,
                        avatar: identity.avatar,
                        isHost: true,
                        isReady: true
                    }
                })
            });
            const data = await res.json();
            if (!res.ok || (data && data.code !== undefined && data.code !== 0 && data.code !== 200)) {
                notifyUser((data && data.message) || '创建房间失败，请重新登录后重试');
                return;
            }
            const createdRoom = data && data.data ? data.data : null;
            const finalCode = (createdRoom && createdRoom.roomCode) ? String(createdRoom.roomCode) : newCode;
            if (createdRoom) {
                window.__entRoomsCache = [createdRoom].concat(
                    (window.__entRoomsCache || []).filter(function (r) {
                        return r && String(r.roomCode) !== finalCode;
                    })
                );
                updateRoomCounters(window.__entRoomsCache);
                renderRoomList();
            }
            window.closeCreateRoomModal();
            if (nameInput) nameInput.value = '';
            if (typeof window.joinSpecificRoom === 'function') {
                window.joinSpecificRoom(finalCode, gameType);
            }
        } catch (e) {
            notifyUser('创建房间失败，请检查网络后重试');
        } finally {
            state.isCreatingRoom = false;
            if (btn) {
                btn.disabled = false;
                btn.textContent = origBtnText || '创建并进入房间';
            }
        }
    };

    function bindCreateRoomModalEvents() {
        const modal = document.getElementById('createRoomModal');
        if (!modal || modal.dataset.entBound) return;
        modal.dataset.entBound = '1';

        modal.addEventListener('click', function (e) {
            if (e.target === modal) {
                window.closeCreateRoomModal();
                return;
            }
            const opt = e.target.closest('.ent-create-game-opt[data-game]');
            if (opt) {
                window.selectCreateRoomGame(opt.getAttribute('data-game'));
            }
        });

        const nameInput = document.getElementById('inputCustomRoomName');
        if (nameInput) {
            nameInput.addEventListener('keydown', function (e) {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    window.submitCustomCreateRoom();
                }
            });
        }
    }

    /* =========================================================================
       4. Command Palette (#commandPaletteModal)
       ========================================================================= */
    function getStaticPaletteCommands() {
        return [
            {
                id: 'nav-games',
                group: '页面导航',
                icon: '🎮',
                title: '前往 游戏大厅',
                subtitle: '切换至桌游模式与实时房间列表',
                keywords: 'games lobby 大厅 游戏',
                run: function () { if (typeof window.switchLobbyTab === 'function') window.switchLobbyTab('games'); }
            },
            {
                id: 'nav-square',
                group: '页面导航',
                icon: '💬',
                title: '前往 社交广场',
                subtitle: '全服世界频道与同城交友聊天',
                keywords: 'square chat 广场 聊天',
                run: function () { if (typeof window.switchLobbyTab === 'function') window.switchLobbyTab('square'); }
            },
            {
                id: 'nav-rank',
                group: '页面导航',
                icon: '🏆',
                title: '前往 荣耀排行榜',
                subtitle: '查看天梯排位积分榜与财富神豪榜',
                keywords: 'rank leaderboard 排行 天梯 榜单',
                run: function () { if (typeof window.switchLobbyTab === 'function') window.switchLobbyTab('rank'); }
            },
            {
                id: 'nav-friends',
                group: '页面导航',
                icon: '👥',
                title: '前往 亲密好友',
                subtitle: '好友列表、亲密关系墙与好友申请',
                keywords: 'friends intimacy 好友 申请',
                run: function () { if (typeof window.switchLobbyTab === 'function') window.switchLobbyTab('friends'); }
            },
            {
                id: 'nav-shop',
                group: '页面导航',
                icon: '🛍️',
                title: '前往 装扮商城',
                subtitle: '骰盅皮肤、头像边框、互动道具与充值',
                keywords: 'shop store 商城 商店 充值',
                run: function () { if (typeof window.switchLobbyTab === 'function') window.switchLobbyTab('shop'); }
            },
            {
                id: 'nav-profile',
                group: '页面导航',
                icon: '👤',
                title: '前往 个人中心',
                subtitle: '查看个人战绩、综合胜率与账户资产',
                keywords: 'profile me 个人 战绩 胜率',
                run: function () { if (typeof window.switchLobbyTab === 'function') window.switchLobbyTab('profile'); }
            },
            {
                id: 'action-create-room',
                group: '快速开局',
                icon: '➕',
                title: '创建自定义房间',
                subtitle: '自选玩法、房间名称与旁观权限',
                keywords: 'create room 创建 房间 开房',
                run: function () { window.openCreateRoomModal('take6'); }
            },
            {
                id: 'quick-take6',
                group: '快速开局',
                icon: '🐂',
                title: '快速开局：谁是牛头王 (Take 6!)',
                subtitle: '自动匹配等待中的牛头王对局或立即开房',
                keywords: 'take6 牛头王 快速 匹配',
                run: function () { if (typeof window.quickPlayGame === 'function') window.quickPlayGame('take6'); }
            },
            {
                id: 'quick-dice',
                group: '快速开局',
                icon: '🎲',
                title: '快速开局：大话骰吹牛',
                subtitle: '自动匹配大话骰房间或立即开房',
                keywords: 'liars_dice dice 大话骰 吹牛 快速',
                run: function () { if (typeof window.quickPlayGame === 'function') window.quickPlayGame('liars_dice'); }
            },
            {
                id: 'quick-wheel',
                group: '快速开局',
                icon: '🎡',
                title: '快速开局：聚会大转盘',
                subtitle: '真心话大冒险四套场景题库',
                keywords: 'party_wheel wheel 转盘 聚会 快速',
                run: function () { if (typeof window.quickPlayGame === 'function') window.quickPlayGame('party_wheel'); }
            },
            {
                id: 'quick-undercover',
                group: '快速开局',
                icon: '🕵️',
                title: '快速开局：谁是卧底',
                subtitle: '多人推理猜词与平票 PK 复投',
                keywords: 'undercover 卧底 推理 快速',
                run: function () { if (typeof window.quickPlayGame === 'function') window.quickPlayGame('undercover'); }
            },
            {
                id: 'action-refresh-rooms',
                group: '快速开局',
                icon: '🔄',
                title: '刷新实时房间列表',
                subtitle: '同步最新活跃开黑房间与在线桌数',
                keywords: 'refresh rooms 刷新 房间',
                run: function () {
                    if (typeof window.switchLobbyTab === 'function') window.switchLobbyTab('games');
                    if (typeof window.refreshLobbyRooms === 'function') window.refreshLobbyRooms();
                }
            },
            {
                id: 'perk-signin',
                group: '福利与设置',
                icon: '📅',
                title: '每日连续签到',
                subtitle: '查看 7 天签到奖励并打卡领金币/钻石',
                keywords: 'signin 签到 每日 福利',
                run: function () { if (typeof window.openSignInModal === 'function') window.openSignInModal(); }
            },
            {
                id: 'perk-first-recharge',
                group: '福利与设置',
                icon: '🎁',
                title: '6元首充豪礼',
                subtitle: '查看首充特惠礼包与 VIP1 激活',
                keywords: 'first recharge 首充 礼包 福利',
                run: function () { if (typeof window.openFirstRechargeModal === 'function') window.openFirstRechargeModal(); }
            },
            {
                id: 'perk-gacha',
                group: '福利与设置',
                icon: '🎯',
                title: '幸运夺宝盲盒',
                subtitle: '抽取钻石、全服喇叭与稀缺互动道具',
                keywords: 'gacha lucky 盲盒 夺宝 抽奖',
                run: function () { if (typeof window.openLuckyGachaModal === 'function') window.openLuckyGachaModal(); }
            },
            {
                id: 'perk-relief',
                group: '福利与设置',
                icon: '🆘',
                title: '免费领救济金',
                subtitle: '每日补给回血金币领取通道',
                keywords: 'relief bankrupt 救济金 补给',
                run: function () { if (typeof window.openBankruptReliefModal === 'function') window.openBankruptReliefModal(); }
            },
            {
                id: 'perk-vip',
                group: '福利与设置',
                icon: '👑',
                title: 'VIP 贵宾特权体系',
                subtitle: '查看 VIP1-SVIP10 等级特权与成长进度',
                keywords: 'vip svip 特权 贵族',
                run: function () { if (typeof window.openVipPrivilegesModal === 'function') window.openVipPrivilegesModal(); }
            },
            {
                id: 'util-theme',
                group: '福利与设置',
                icon: '🌓',
                title: '切换护眼明亮 / 暗黑主题',
                subtitle: '在浅色日间与深色夜间视觉模式间切换',
                keywords: 'theme dark light 主题 暗黑 护眼',
                run: function () { if (typeof window.toggleWebTheme === 'function') window.toggleWebTheme(); }
            },
            {
                id: 'util-rules',
                group: '福利与设置',
                icon: '📖',
                title: '查看玩法宝典',
                subtitle: '浏览牛头王、大话骰、大转盘与谁是卧底规则',
                keywords: 'rules guide 规则 玩法',
                run: function () { if (typeof window.openGameRulesModal === 'function') window.openGameRulesModal('take6'); }
            }
        ];
    }

    async function joinRoomByCodeSmart(code) {
        let targetType = 'take6';
        try {
            const res = await fetch(getPrefix() + '/api/rooms/detail?roomCode=' + encodeURIComponent(code), {
                headers: buildHeaders(false),
                credentials: 'same-origin'
            });
            const d = await res.json();
            if (d && d.code === 0 && d.data && d.data.gameType) {
                targetType = d.data.gameType;
            }
        } catch (e) {}
        if (typeof window.joinSpecificRoom === 'function') {
            window.joinSpecificRoom(code, targetType);
        }
    }

    function buildCommandPaletteItems(rawQuery) {
        const query = (rawQuery || '').trim();
        const qLower = query.toLowerCase();
        const items = [];

        const codeMatch = query.match(/^#?(\d{6})$/);
        if (codeMatch) {
            const roomCode = codeMatch[1];
            items.push({
                id: 'join-code-' + roomCode,
                group: '精确直达',
                icon: '🚀',
                title: '加入房间 ' + roomCode,
                subtitle: '按 6 位房间号查询详情并直接进入对局',
                run: function () { joinRoomByCodeSmart(roomCode); }
            });
        }

        if (qLower) {
            (window.__entRoomsCache || []).forEach(function (r) {
                if (!r || !r.roomCode) return;
                const code = String(r.roomCode);
                if (codeMatch && code === codeMatch[1]) return;
                const meta = getGameMeta(r.gameType || 'take6');
                const rName = String(r.roomName || '');
                if (code.toLowerCase().includes(qLower) || rName.toLowerCase().includes(qLower)) {
                    items.push({
                        id: 'cached-room-' + code,
                        group: '活跃房间',
                        icon: meta.icon,
                        title: '进入 #' + code + ' · ' + (rName || meta.shortName),
                        subtitle: meta.name + ' · ' + ((r.players && r.players.length) || 1) + '人在房',
                        run: function () {
                            if (typeof window.joinSpecificRoom === 'function') {
                                window.joinSpecificRoom(code, r.gameType || 'take6');
                            }
                        }
                    });
                }
            });
        }

        const staticCmds = getStaticPaletteCommands();
        staticCmds.forEach(function (cmd) {
            if (!qLower) {
                items.push(cmd);
                return;
            }
            const haystack = (cmd.title + ' ' + cmd.subtitle + ' ' + cmd.keywords + ' ' + cmd.group).toLowerCase();
            if (haystack.includes(qLower)) {
                items.push(cmd);
            }
        });

        return items;
    }

    function renderCommandPaletteList(rawQuery) {
        const listEl = document.getElementById('cmdPaletteList');
        if (!listEl) return;

        const items = buildCommandPaletteItems(rawQuery);
        state.cmdFilteredItems = items;
        if (state.cmdSelectedIndex >= items.length) {
            state.cmdSelectedIndex = Math.max(0, items.length - 1);
        }

        if (items.length === 0) {
            listEl.innerHTML =
                '<div class="ent-cmd-empty" style="padding:20px 12px; text-align:center; font-size:13px; opacity:0.75;">' +
                '<div>未找到匹配的指令</div>' +
                '<div style="font-size:12px; opacity:0.8; margin-top:4px;">可尝试输入 6 位数字房间号直接进入房间</div>' +
                '</div>';
            return;
        }

        let lastGroup = '';
        const htmlParts = [];
        items.forEach(function (item, idx) {
            if (item.group && item.group !== lastGroup) {
                lastGroup = item.group;
                htmlParts.push('<div class="ent-cmd-group" style="font-size:12px; font-weight:700; opacity:0.68; padding:6px 10px 2px;">' + escapeHtml(item.group) + '</div>');
            }
            const activeClass = idx === state.cmdSelectedIndex ? ' active' : '';
            htmlParts.push(
                '<button type="button" class="ent-cmd-item' + activeClass + '" data-cmd-idx="' + idx + '" role="option" aria-selected="' + String(idx === state.cmdSelectedIndex) + '">' +
                    '<span class="ent-cmd-item-icon" style="font-size:18px; flex-shrink:0;">' + escapeHtml(item.icon) + '</span>' +
                    '<span class="ent-cmd-item-body" style="flex:1; min-width:0; display:flex; flex-direction:column; gap:2px; text-align:left;">' +
                        '<span class="ent-cmd-item-title" style="font-size:13.5px; font-weight:700;">' + escapeHtml(item.title) + '</span>' +
                        '<span class="ent-cmd-item-sub">' + escapeHtml(item.subtitle || '') + '</span>' +
                    '</span>' +
                    '<span class="ent-cmd-item-enter" style="font-size:12px; opacity:0.65; flex-shrink:0;">↵</span>' +
                '</button>'
            );
        });
        listEl.innerHTML = htmlParts.join('');
    }

    function updateCommandSelection(nextIdx) {
        const items = state.cmdFilteredItems;
        if (!items.length) return;
        const len = items.length;
        state.cmdSelectedIndex = ((nextIdx % len) + len) % len;

        const listEl = document.getElementById('cmdPaletteList');
        if (!listEl) return;
        const btns = listEl.querySelectorAll('.ent-cmd-item');
        btns.forEach(function (btn) {
            const idx = Number(btn.getAttribute('data-cmd-idx'));
            const isSel = idx === state.cmdSelectedIndex;
            btn.classList.toggle('active', isSel);
            btn.setAttribute('aria-selected', String(isSel));
            if (isSel && typeof btn.scrollIntoView === 'function') {
                btn.scrollIntoView({ block: 'nearest' });
            }
        });
    }

    function executeCommandAt(idx) {
        const item = state.cmdFilteredItems[idx];
        if (!item) return;
        window.closeCommandPalette();
        if (typeof item.run === 'function') {
            item.run();
        }
    }

    window.openCommandPalette = function () {
        const modal = document.getElementById('commandPaletteModal');
        if (!modal) return;
        state.lastFocusedBeforeCmd = document.activeElement;
        state.cmdSelectedIndex = 0;
        modal.style.display = 'flex';
        const input = document.getElementById('cmdPaletteInput');
        if (input) {
            input.value = '';
            renderCommandPaletteList('');
            requestAnimationFrame(function () {
                try { input.focus(); } catch (e) {}
            });
        } else {
            renderCommandPaletteList('');
        }
    };

    window.closeCommandPalette = function () {
        const modal = document.getElementById('commandPaletteModal');
        if (modal) modal.style.display = 'none';
        if (state.lastFocusedBeforeCmd && typeof state.lastFocusedBeforeCmd.focus === 'function') {
            try { state.lastFocusedBeforeCmd.focus(); } catch (e) {}
        }
        state.lastFocusedBeforeCmd = null;
    };

    function bindCommandPaletteEvents() {
        const triggerBtn = document.getElementById('btnOpenCmdPalette');
        if (triggerBtn && !triggerBtn.dataset.entBound) {
            triggerBtn.dataset.entBound = '1';
            triggerBtn.addEventListener('click', function (e) {
                e.preventDefault();
                window.openCommandPalette();
            });
        }

        const modal = document.getElementById('commandPaletteModal');
        if (modal && !modal.dataset.entBound) {
            modal.dataset.entBound = '1';
            modal.addEventListener('click', function (e) {
                if (e.target === modal) {
                    window.closeCommandPalette();
                }
            });
        }

        const input = document.getElementById('cmdPaletteInput');
        if (input && !input.dataset.entBound) {
            input.dataset.entBound = '1';
            input.addEventListener('input', function () {
                state.cmdSelectedIndex = 0;
                renderCommandPaletteList(input.value);
            });
            input.addEventListener('keydown', function (e) {
                if (e.key === 'ArrowDown') {
                    e.preventDefault();
                    updateCommandSelection(state.cmdSelectedIndex + 1);
                } else if (e.key === 'ArrowUp') {
                    e.preventDefault();
                    updateCommandSelection(state.cmdSelectedIndex - 1);
                } else if (e.key === 'Enter') {
                    e.preventDefault();
                    executeCommandAt(state.cmdSelectedIndex);
                } else if (e.key === 'Escape') {
                    e.preventDefault();
                    e.stopPropagation();
                    window.closeCommandPalette();
                }
            });
        }

        const listEl = document.getElementById('cmdPaletteList');
        if (listEl && !listEl.dataset.entBound) {
            listEl.dataset.entBound = '1';
            listEl.addEventListener('mousemove', function (e) {
                const btn = e.target.closest('.ent-cmd-item[data-cmd-idx]');
                if (!btn) return;
                const idx = Number(btn.getAttribute('data-cmd-idx'));
                if (!Number.isNaN(idx) && idx !== state.cmdSelectedIndex) {
                    updateCommandSelection(idx);
                }
            });
            listEl.addEventListener('click', function (e) {
                const btn = e.target.closest('.ent-cmd-item[data-cmd-idx]');
                if (!btn) return;
                const idx = Number(btn.getAttribute('data-cmd-idx'));
                if (!Number.isNaN(idx)) {
                    executeCommandAt(idx);
                }
            });
        }
    }

    /* =========================================================================
       5. Rank Podium, Win-Rate Ring, Badge Sync & Global Escape
       ========================================================================= */
    function extractRankTop3FromDom() {
        const listEl = document.getElementById('rankListContainer');
        if (!listEl) return [];
        const items = Array.prototype.slice.call(listEl.querySelectorAll('.rank-item'), 0, 3);
        return items.map(function (item, idx) {
            const left = item.children[0];
            const right = item.children[1];
            const spans = left ? left.querySelectorAll('span') : [];
            const medal = spans[0] ? (spans[0].textContent || '').trim() : (idx === 0 ? '🥇' : (idx === 1 ? '🥈' : '🥉'));
            const avatar = spans[1] ? (spans[1].textContent || '').trim() : '🦊';
            const nickEl = item.querySelector('.rank-nick');
            const subEl = item.querySelector('.pg-sub');
            return {
                rank: idx + 1,
                medal: medal,
                avatar: avatar,
                nickname: nickEl ? (nickEl.textContent || '玩家').trim() : '玩家',
                tier: subEl ? (subEl.textContent || '').trim() : '',
                score: right ? (right.textContent || '').trim() : ''
            };
        });
    }

    function renderRankPodium() {
        const podium = document.getElementById('rankPodium');
        if (!podium) return;

        const top3 = extractRankTop3FromDom();
        if (top3.length === 0) {
            podium.innerHTML = '';
            podium.style.display = 'none';
            return;
        }

        // Visual architectural order: 2nd, 1st, 3rd when all 3 exist
        const ordered = top3.length === 3 ? [top3[1], top3[0], top3[2]] : top3;
        podium.style.display = '';
        podium.innerHTML = ordered.map(function (entry) {
            return (
                '<div class="ent-podium-card rank-' + entry.rank + '" data-rank="' + entry.rank + '">' +
                    '<div class="ent-podium-medal">' + escapeHtml(entry.medal) + '</div>' +
                    '<div class="ent-podium-avatar">' + escapeHtml(entry.avatar) + '</div>' +
                    '<div class="ent-podium-name pg-title">' + escapeHtml(entry.nickname) + '</div>' +
                    '<div class="ent-podium-tier pg-sub">' + escapeHtml(entry.tier) + '</div>' +
                    '<div class="ent-podium-score tabular-nums">' + escapeHtml(entry.score) + '</div>' +
                '</div>'
            );
        }).join('');
    }

    function setupRankPodiumSync() {
        if (window.loadRankData && !window.loadRankData.__entWrapped) {
            const origLoadRank = window.loadRankData;
            const wrappedLoadRank = async function () {
                const res = await origLoadRank.apply(this, arguments);
                renderRankPodium();
                return res;
            };
            wrappedLoadRank.__entWrapped = true;
            window.loadRankData = wrappedLoadRank;
        }

        const listEl = document.getElementById('rankListContainer');
        if (listEl && !listEl.dataset.entObserved && typeof MutationObserver === 'function') {
            listEl.dataset.entObserved = '1';
            const obs = new MutationObserver(function () {
                renderRankPodium();
            });
            obs.observe(listEl, { childList: true, subtree: false });
        }
        renderRankPodium();
    }

    function renderWinRateRing() {
        const container = document.getElementById('profileWinRateRing');
        if (!container) return;

        const rateEl = document.getElementById('statWinRate');
        const totalEl = document.getElementById('statTotalGames');
        const winEl = document.getElementById('statWinCount');
        const rawRate = rateEl ? parseFloat((rateEl.textContent || '0').replace(/[^\d.]/g, '')) : 0;
        const pct = Number.isFinite(rawRate) ? Math.max(0, Math.min(100, Math.round(rawRate))) : 0;
        const totalGames = totalEl ? (parseInt((totalEl.textContent || '0').replace(/[^\d]/g, ''), 10) || 0) : 0;
        const winCount = winEl ? (parseInt((winEl.textContent || '0').replace(/[^\d]/g, ''), 10) || 0) : 0;

        const radius = 29;
        const circumference = 2 * Math.PI * radius;
        const dashOffset = circumference * (1 - pct / 100);
        const strokeColor = pct >= 60 ? '#10b981' : (pct >= 40 ? '#3b82f6' : '#f59e0b');

        container.innerHTML =
            '<svg class="ent-winrate-svg" viewBox="0 0 72 72" width="72" height="72" role="img" aria-label="综合胜率 ' + pct + '%">' +
                '<circle class="ent-ring-track" cx="36" cy="36" r="' + radius + '" fill="none" stroke="rgba(148,163,184,0.22)" stroke-width="7"></circle>' +
                '<circle class="ent-ring-progress" cx="36" cy="36" r="' + radius + '" fill="none" stroke="' + strokeColor + '" stroke-width="7" stroke-linecap="round"' +
                    ' stroke-dasharray="' + circumference.toFixed(2) + '"' +
                    ' stroke-dashoffset="' + dashOffset.toFixed(2) + '"' +
                    ' transform="rotate(-90 36 36)"></circle>' +
                '<text x="36" y="36" text-anchor="middle" dominant-baseline="central" class="ent-ring-pct" fill="currentColor" font-size="14" font-weight="800">' + pct + '%</text>' +
            '</svg>' +
            '<div class="ent-winrate-ring-info">' +
                '<div class="ent-winrate-ring-val tabular-nums">' + pct + '% 胜率</div>' +
                '<div class="tabular-nums">' + winCount + ' 胜 / 共 ' + totalGames + ' 局</div>' +
            '</div>';
    }

    function setupProfileWinRateSync() {
        if (window.loadProfileData && !window.loadProfileData.__entWrapped) {
            const origLoadProfile = window.loadProfileData;
            const wrappedLoadProfile = function () {
                const res = origLoadProfile.apply(this, arguments);
                renderWinRateRing();
                return res;
            };
            wrappedLoadProfile.__entWrapped = true;
            window.loadProfileData = wrappedLoadProfile;
        }

        const rateEl = document.getElementById('statWinRate');
        if (rateEl && !rateEl.dataset.entObserved && typeof MutationObserver === 'function') {
            rateEl.dataset.entObserved = '1';
            const obs = new MutationObserver(function () {
                renderWinRateRing();
            });
            obs.observe(rateEl, { childList: true, characterData: true, subtree: true });
        }
        renderWinRateRing();
    }

    function syncFriendReqBadge() {
        const src = document.getElementById('pendingRequestsCountBadge');
        const dst = document.getElementById('sidebarReqBadge');
        if (!src || !dst) return;

        const count = parseInt((src.textContent || '0').trim(), 10) || 0;
        const visible = src.style.display !== 'none' && count > 0;
        dst.textContent = String(count);
        dst.style.display = visible ? 'inline-flex' : 'none';
    }

    function setupBadgeSync() {
        if (window.loadFriendRequestsData && !window.loadFriendRequestsData.__entWrapped) {
            const origLoadReq = window.loadFriendRequestsData;
            const wrappedLoadReq = async function () {
                const res = await origLoadReq.apply(this, arguments);
                syncFriendReqBadge();
                return res;
            };
            wrappedLoadReq.__entWrapped = true;
            window.loadFriendRequestsData = wrappedLoadReq;
        }

        const src = document.getElementById('pendingRequestsCountBadge');
        if (src && !src.dataset.entObserved && typeof MutationObserver === 'function') {
            src.dataset.entObserved = '1';
            const obs = new MutationObserver(function () {
                syncFriendReqBadge();
            });
            obs.observe(src, {
                attributes: true,
                attributeFilter: ['style', 'class'],
                childList: true,
                characterData: true,
                subtree: true
            });
        }
        syncFriendReqBadge();
    }

    function setupSwitchMainViewSync() {
        if (window.switchMainView && !window.switchMainView.__entWrapped) {
            const origSwitchMainView = window.switchMainView;
            const wrappedSwitchMainView = function (viewName) {
                const res = origSwitchMainView.apply(this, arguments);
                if (viewName === 'lobby') {
                    syncFriendReqBadge();
                    renderWinRateRing();
                    if (typeof window.loadFriendRequestsData === 'function') {
                        try { window.loadFriendRequestsData(); } catch (e) {}
                    }
                }
                return res;
            };
            wrappedSwitchMainView.__entWrapped = true;
            window.switchMainView = wrappedSwitchMainView;
        }
    }

    function closeTopmostOpenModal() {
        const modalOrder = [
            { id: 'commandPaletteModal', close: window.closeCommandPalette },
            { id: 'createRoomModal', close: window.closeCreateRoomModal },
            { id: 'gameCashierModal', close: window.closeGameCashierModal },
            { id: 'playerProfileModal', close: window.closePlayerProfileModal },
            { id: 'friendChatModal', close: window.closeFriendChatModal },
            { id: 'diceBidModal', close: window.closeDiceBidModal },
            { id: 'gameRulesModal', close: window.closeGameRulesModal },
            { id: 'itemThrowModal', close: window.closeItemThrowModal },
            { id: 'globalBroadcastModal', close: window.closeGlobalBroadcastModal },
            { id: 'firstRechargeModal', close: window.closeFirstRechargeModal },
            { id: 'bankruptReliefModal', close: window.closeBankruptReliefModal },
            { id: 'luckyGachaModal', close: window.closeLuckyGachaModal },
            { id: 'rechargeModal', close: window.closeRechargeModal },
            { id: 'vipPrivilegesModal', close: window.closeVipPrivilegesModal },
            { id: 'signInModal', close: window.closeSignInModal },
            { id: 'diceSettlementModal', close: window.closeDiceSettlementModal }
        ];

        for (let i = 0; i < modalOrder.length; i++) {
            const entry = modalOrder[i];
            const el = document.getElementById(entry.id);
            if (isElementVisible(el)) {
                if (typeof entry.close === 'function') {
                    entry.close();
                } else {
                    el.style.display = 'none';
                }
                return true;
            }
        }
        return false;
    }

    function bindGlobalShortcuts() {
        if (window.__entKeydownBound) return;
        window.__entKeydownBound = true;

        document.addEventListener('keydown', function (e) {
            if ((e.ctrlKey || e.metaKey) && String(e.key || '').toLowerCase() === 'k') {
                const cmdModal = document.getElementById('commandPaletteModal');
                const viewLobby = document.getElementById('viewLobby');
                if (cmdModal && (!viewLobby || viewLobby.classList.contains('active'))) {
                    e.preventDefault();
                    if (isElementVisible(cmdModal)) {
                        window.closeCommandPalette();
                    } else {
                        window.openCommandPalette();
                    }
                }
                return;
            }

            if (e.key === 'Escape') {
                if (closeTopmostOpenModal()) {
                    e.preventDefault();
                }
            }
        });
    }

    /* =========================================================================
       Bootstrap
       ========================================================================= */
    function bootstrap() {
        if (state.initialized) return;
        state.initialized = true;

        initSidebarCollapse();
        wrapRefreshLobbyRooms();
        bindRoomBrowserEvents();
        bindCreateRoomModalEvents();
        bindCommandPaletteEvents();
        setupRankPodiumSync();
        setupProfileWinRateSync();
        setupBadgeSync();
        setupSwitchMainViewSync();
        bindGlobalShortcuts();

        const viewLobby = document.getElementById('viewLobby');
        if (viewLobby && viewLobby.classList.contains('active') && typeof window.refreshLobbyRooms === 'function') {
            window.refreshLobbyRooms();
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', bootstrap);
    } else {
        bootstrap();
    }
})();
