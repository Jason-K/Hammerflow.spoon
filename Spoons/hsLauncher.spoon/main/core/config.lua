-- hsLauncher configuration
return {
    -- Temporary test key; set HSLAUNCHER_HYPER_KEY env var to override
    hyperKey = os.getenv('HSLAUNCHER_HYPER_KEY') or 'f15',
    -- Time window to complete leader sequences (seconds)
    leaderTimeout = 1.5,
    -- Max press duration (seconds) to treat Hyper as a tap to arm leader mode
    tapThreshold = 0.5,
    -- Delay (seconds) before deactivating Hyper after release to catch quick chords
    hyperComboGrace = 0.2,
    -- UI and event behavior
    showIndicator = true,
    consumeKeys = true,
    debugInputEngine = false,

    -- Windows native defaults (when not using Rectangle)
    windows = {
        gridSize = "3x2",
        gridMargins = { 0, 0 },
        centerRatio = "80:50",
        adjustNeighbors = false,
    },

    -- Hotkey assignment preferences
    chassisOrder = {
        'cmd+opt+ctrl+shift',
        'cmd+opt+ctrl',
        'cmd+ctrl+shift',
        'cmd+opt+shift',
        'opt+ctrl+shift',
        'opt+shift',
        'opt+ctrl',
        'ctrl+shift',
        'opt+cmd',
    },
    reservedGlobals = {
        'cmd+space', -- Raycast
        'cmd+comma', -- Settings
    },

    -- Optional per-app chassis overrides (bundleID or name fallback)
    perAppChassis = {
        ['com.brnbw.Leader-Key'] = {
            'cmd+opt+ctrl+shift',
            'cmd+opt+ctrl',
            'cmd+ctrl+shift',
            'cmd+opt+shift',
            'opt+ctrl+shift',
            'opt+cmd',
            'opt+ctrl',
            'ctrl+shift',
            'opt+shift'
        },


        -- Replace with actual bundle ID if known
        -- ['com.example.LeaderKey'] = {
        --   'cmd+opt+ctrl','cmd+ctrl+shift','cmd+opt+shift','opt+ctrl+shift','opt+cmd','opt+ctrl','ctrl+shift','opt+shift'
        -- },
    },
    perAppChassisByName = {
        ['Leader Key'] = {
            'cmd+opt+ctrl+shift',
            'cmd+opt+ctrl',
            'cmd+ctrl+shift',
            'cmd+opt+shift',
            'opt+ctrl+shift',
            'opt+cmd',
            'opt+ctrl',
            'ctrl+shift',
            'opt+shift'
        },
        ['LeaderKey'] = {
            'cmd+opt+ctrl', 'cmd+ctrl+shift', 'cmd+opt+shift', 'opt+ctrl+shift', 'opt+cmd', 'opt+ctrl', 'ctrl+shift',
            'opt+shift'
        },
    },
}
