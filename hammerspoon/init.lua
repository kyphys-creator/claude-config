-- Claude for Mac: Cmd+Q 誤終了防止
-- eventtap で低レベルにキーイベントを捕捉し、
-- Claude 宛の Cmd+Q をブロックする

local quitTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local flags = event:getFlags()
    local keyCode = event:getKeyCode()

    -- Cmd+Q (keyCode 12 = Q) かつ Shift なし
    if flags.cmd and not flags.shift and not flags.alt and not flags.ctrl and keyCode == 12 then
        -- フロントアプリが Claude かチェック
        local app = hs.application.frontmostApplication()
        if app and app:name() == "Claude" then
            hs.alert.show("Quit Claude: Cmd+Shift+Q", 1)
            return true  -- イベントを消費（quit を阻止）
        end
    end
    return false  -- 他はそのまま通す
end)
quitTap:start()
