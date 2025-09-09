fx_version "bodacious" -- fx_version 2020-02
game "gta5"
lua54 'yes'

dependencies {
    "vrp",
    "ox_lib"
}

ui_page "html/index.html"

client_scripts {
    "config.lua",
    "lib/Tunnel.lua",
    "lib/Proxy.lua",
    "client.lua"
}

shared_scripts {
    '@ox_lib/init.lua',
    -- any other shared scripts
}

server_scripts {
    "config.lua",
    "@mysql-async/lib/MySQL.lua",
    "@vrp/lib/utils.lua",
    "server.lua"
}

files {
    "config.lua",
    "html/index.html",
    "html/index.css",
    "html/index.js",
    "html/img/*.png",
    "html/img/*.jpg",
    "html/sounds/*.ogg"
}