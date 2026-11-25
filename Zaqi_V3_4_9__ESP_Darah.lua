-- Fast Heal multiplier: 10x
local FAST_HEAL_MULTIPLIER = 10
-- Fast Heal: 3x speed
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--==================================================
-- LOCK VIEW PLAYER
--==================================================

--==================================================
-- CINEMATIC ORBIT - NEXT 2
--==================================================

local cinematicOrbitEnabled = false
local cinematicOrbitConnectionName = "ZaqiCinematicOrbit"
local cinematicOrbitAngle = 0
local cinematicOrbitDistance = 9
local cinematicOrbitHeight = 2.8
local cinematicOrbitSpeed = 0.65
local cinematicOrbitPreviousCameraType = nil
local cinematicOrbitPreviousCameraSubject = nil
local cinematicOrbitLastTargetPosition = nil
local cinematicOrbitSnapNextFrame = false

local function getCinematicOrbitTarget()
    -- Orbit selalu mengelilingi karakter kita sendiri.
    local localPlayer = Players.LocalPlayer
    return localPlayer
end

local function setCinematicOrbitEnabled(enabled)
    cinematicOrbitEnabled = enabled

    pcall(function()
        RunService:UnbindFromRenderStep(cinematicOrbitConnectionName)
    end)

    local camera = workspace.CurrentCamera

    if not enabled then
        -- Kembalikan kamera Roblox seperti semula.
        if camera then
            camera.CameraType = cinematicOrbitPreviousCameraType or Enum.CameraType.Custom
            local player = Players.LocalPlayer
            local character = player and player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            camera.CameraSubject = cinematicOrbitPreviousCameraSubject or humanoid
        end

        cinematicOrbitPreviousCameraType = nil
        cinematicOrbitPreviousCameraSubject = nil
        cinematicOrbitLastTargetPosition = nil
        cinematicOrbitSnapNextFrame = false
        return
    end

    if camera then
        cinematicOrbitPreviousCameraType = camera.CameraType
        cinematicOrbitPreviousCameraSubject = camera.CameraSubject
        -- Scriptable mencegah kontrol kamera Roblox menimpa orbit.
        camera.CameraType = Enum.CameraType.Scriptable
    end

    cinematicOrbitAngle = 0
    cinematicOrbitLastTargetPosition = nil
    cinematicOrbitSnapNextFrame = true

    RunService:BindToRenderStep(
        cinematicOrbitConnectionName,
        Enum.RenderPriority.Camera.Value + 10,
        function(deltaTime)
            if not cinematicOrbitEnabled then
                return
            end

            local currentCamera = workspace.CurrentCamera
            local targetPlayer = getCinematicOrbitTarget()
            local targetCharacter = targetPlayer and targetPlayer.Character
            local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

            if not currentCamera or not targetRoot then
                return
            end

            -- Pastikan kamera tetap Scriptable selama fitur aktif.
            if currentCamera.CameraType ~= Enum.CameraType.Scriptable then
                currentCamera.CameraType = Enum.CameraType.Scriptable
            end

            local targetPosition = targetRoot.Position + Vector3.new(0, 1.5, 0)

            -- Jika pemain DIAM, orbit berhenti. Kamera berada di belakang
            -- karakter dan mengikuti arah hadap karakter, sehingga pandangan
            -- tetap ke depan tanpa berputar-putar.
            local horizontalVelocity = Vector3.new(
                targetRoot.AssemblyLinearVelocity.X,
                0,
                targetRoot.AssemblyLinearVelocity.Z
            )
            local isMoving = horizontalVelocity.Magnitude > 1.5

            local desiredPosition

            if isMoving then
                -- Saat bergerak, cinematic orbit tetap berjalan seperti versi lama.
                cinematicOrbitAngle += cinematicOrbitSpeed * deltaTime

                local orbitOffset = Vector3.new(
                    math.cos(cinematicOrbitAngle) * cinematicOrbitDistance,
                    cinematicOrbitHeight,
                    math.sin(cinematicOrbitAngle) * cinematicOrbitDistance
                )

                desiredPosition = targetPosition + orbitOffset
            else
                -- Saat diam: kamera di belakang pemain, menghadap ke arah depan.
                local forward = targetRoot.CFrame.LookVector
                desiredPosition =
                    targetRoot.Position
                    - forward * cinematicOrbitDistance
                    + Vector3.new(0, cinematicOrbitHeight, 0)
            end

            -- Jika karakter berpindah sangat jauh (misalnya Teleport Spawn),
            -- jangan Lerp dari posisi kamera lama karena kamera akan terlihat
            -- "tertinggal" sangat jauh. Langsung pindahkan kamera ke posisi baru.
            local targetMovedFar = false
            if cinematicOrbitLastTargetPosition then
                targetMovedFar = (targetRoot.Position - cinematicOrbitLastTargetPosition).Magnitude > 20
            end

            if cinematicOrbitSnapNextFrame or targetMovedFar then
                currentCamera.CFrame = CFrame.lookAt(desiredPosition, targetPosition)
                currentCamera.Focus = CFrame.new(targetPosition)
                cinematicOrbitSnapNextFrame = false
                cinematicOrbitLastTargetPosition = targetRoot.Position
                return
            end

            cinematicOrbitLastTargetPosition = targetRoot.Position

            local smooth = math.clamp(deltaTime * 7, 0, 1)
            local newPosition = currentCamera.CFrame.Position:Lerp(desiredPosition, smooth)
            local desiredCFrame = CFrame.lookAt(newPosition, targetPosition)

            currentCamera.CFrame = currentCamera.CFrame:Lerp(desiredCFrame, smooth)
            currentCamera.Focus = CFrame.new(targetPosition)
        end
    )
end


local lockViewEnabled = false
local lockViewConnectionName = "ZaqiLockViewPlayer"

local function getNearestPlayer()
    local localPlayer = Players.LocalPlayer
    local character = localPlayer and localPlayer.Character
    local localRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not localRoot then
        return nil
    end

    local nearestPlayer = nil
    local nearestDistance = math.huge

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= localPlayer then
            local targetCharacter = targetPlayer.Character
            local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
            local humanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")

            if targetRoot and humanoid and humanoid.Health > 0 then
                local distance = (targetRoot.Position - localRoot.Position).Magnitude
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestPlayer = targetPlayer
                end
            end
        end
    end

    return nearestPlayer
end

local function setLockViewEnabled(enabled)
    lockViewEnabled = enabled

    pcall(function()
        RunService:UnbindFromRenderStep(lockViewConnectionName)
    end)

    if not enabled then
        return
    end

    -- Priority Camera + 1 supaya Lock View dijalankan setelah
    -- kamera Roblox selesai diperbarui pada frame tersebut.
    RunService:BindToRenderStep(
        lockViewConnectionName,
        Enum.RenderPriority.Camera.Value + 1,
        function()
            if not lockViewEnabled then
                return
            end

            local camera = workspace.CurrentCamera
            local targetPlayer = getNearestPlayer()
            local targetCharacter = targetPlayer and targetPlayer.Character
            local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

            if camera and targetRoot then
                local cameraPosition = camera.CFrame.Position

                -- Sedikit ke arah bagian atas tubuh agar pandangan lebih natural.
                local targetPosition = targetRoot.Position + Vector3.new(0, 1.5, 0)

                camera.CFrame = CFrame.lookAt(cameraPosition, targetPosition)
                camera.Focus = CFrame.new(targetPosition)
            end
        end
    )
end


-- Informasi (Pemain, FPS, Ping) Bottom-Left Overlay
local fpsPingOverlay
local fpsPingOverlayConnection
local fpsPingRenderConnection

local function getCurrentPing()
    local ok, value = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(value) == "number" then
        return math.floor(value + 0.5)
    end
    return 0
end

-- Ambil jumlah SELURUH pemain yang sedang main game ini (semua server)
-- lewat API publik Roblox (games.roblox.com). Mengembalikan angka atau nil.
local function fetchAllPlayersCount()
    local url = "https://games.roblox.com/v1/games?universeIds=" .. tostring(game.GameId)
    local body

    -- Coba fungsi request milik executor (jika ada).
    local requestFn
    pcall(function()
        requestFn = (syn and syn.request) or http_request or request
            or (http and http.request) or (fluxus and fluxus.request)
    end)

    if requestFn then
        local ok, res = pcall(requestFn, {Url = url, Method = "GET"})
        if ok and type(res) == "table" and res.Body then
            body = res.Body
        end
    end

    -- Cadangan: game:HttpGet.
    if not body then
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and type(res) == "string" then
            body = res
        end
    end

    if not body then return nil end

    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(body)
    end)
    if ok and type(data) == "table" and type(data.data) == "table"
        and data.data[1] and type(data.data[1].playing) == "number" then
        return data.data[1].playing
    end
    return nil
end

local function setFpsPingOverlayEnabled(enabled)
    if enabled then
        if fpsPingOverlay then
            fpsPingOverlay.Visible = true
            return
        end

        local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

        local gui = Instance.new("ScreenGui")
        gui.Name = "Zaqi_FPSPingOverlay"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 999
        gui.Parent = playerGui

        local frame = Instance.new("Frame")
        frame.Name = "FPSPingFrame"
        frame.Size = UDim2.new(0, 150, 0, 68)
        frame.Position = UDim2.new(0, 10, 1, -88)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        frame.BackgroundTransparency = 0.35
        frame.BorderSizePixel = 0
        frame.Parent = gui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 7)
        corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Name = "Stats"
        label.Size = UDim2.new(1, -10, 1, -6)
        label.Position = UDim2.new(0, 5, 0, 3)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 14
        label.Font = Enum.Font.GothamSemibold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.RichText = true
        -- Teks mengecil otomatis hanya jika terlalu panjang (mis. all:12345),
        -- supaya lebar panel tetap seperti semula.
        label.TextScaled = true
        local sizeLimit = Instance.new("UITextSizeConstraint")
        sizeLimit.MaxTextSize = 14
        sizeLimit.MinTextSize = 8
        sizeLimit.Parent = label
        label.Text = string.format("👥: %d/%d\nFPS: --\nPing: -- ms", #game:GetService("Players"):GetPlayers(), game:GetService("Players").MaxPlayers)
        label.Parent = frame

        fpsPingOverlay = gui

        -- Baris "Map: ..." (di bawah jam). Nama terlalu panjang = teks berjalan.
        local MAP_CLIP_W = 140
        local MAP_GAP = 30
        local MAP_SPEED = 35 -- piksel per detik

        local mapClip = Instance.new("Frame")
        mapClip.Name = "MapClip"
        mapClip.BackgroundTransparency = 1
        mapClip.ClipsDescendants = true
        mapClip.Position = UDim2.new(0, 5, 0, 22)
        mapClip.Size = UDim2.new(0, MAP_CLIP_W, 0, 18)
        mapClip.Visible = false
        mapClip.Parent = frame

        local function makeMapLabel(name)
            local l = Instance.new("TextLabel")
            l.Name = name
            l.BackgroundTransparency = 1
            l.TextColor3 = Color3.fromRGB(255, 255, 255)
            l.TextSize = 14
            l.Font = Enum.Font.GothamSemibold
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.TextYAlignment = Enum.TextYAlignment.Top
            l.TextWrapped = false
            l.Text = ""
            l.Size = UDim2.new(0, MAP_CLIP_W, 1, 0)
            l.Parent = mapClip
            return l
        end
        local mapLabelA = makeMapLabel("MapA")
        local mapLabelB = makeMapLabel("MapB")
        mapLabelB.Visible = false

        local mapName = "Loading..."
        local mapTextWidth = 0
        local mapScrollX = 0

        local function refreshMapText()
            local text = "Map: " .. mapName
            mapLabelA.Text = text
            mapLabelB.Text = text
            local ok, size = pcall(function()
                return game:GetService("TextService"):GetTextSize(
                    text, 14, Enum.Font.GothamSemibold, Vector2.new(5000, 100))
            end)
            mapTextWidth = (ok and size.X or #text * 8) + 2
            mapScrollX = 0
            if mapTextWidth <= MAP_CLIP_W then
                -- Muat: tampil diam, tidak berjalan.
                mapLabelA.Size = UDim2.new(0, MAP_CLIP_W, 1, 0)
                mapLabelA.Position = UDim2.new(0, 0, 0, 0)
                mapLabelB.Visible = false
            else
                mapLabelA.Size = UDim2.new(0, mapTextWidth, 1, 0)
                mapLabelB.Size = UDim2.new(0, mapTextWidth, 1, 0)
                mapLabelB.Visible = true
            end
        end
        refreshMapText()

        -- Nama map (bahasa Inggris) = nama place yang sedang dimainkan.
        local overlayForMap = gui
        task.spawn(function()
            local lastPlaceId = nil
            while fpsPingOverlay == overlayForMap and overlayForMap.Parent do
                if game.PlaceId ~= lastPlaceId then
                    local ok, info = pcall(function()
                        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
                    end)
                    local name = ok and info and info.Name
                    if type(name) ~= "string" or name == "" then
                        name = (game.Name ~= "" and game.Name ~= "Game") and game.Name or "Unknown"
                    end
                    lastPlaceId = game.PlaceId
                    mapName = name
                    refreshMapText()
                end
                task.wait(10)
            end
        end)

        local RunService = game:GetService("RunService")
        local frames = 0
        local elapsed = 0

        -- Jumlah seluruh pemain game (semua server); nil = belum/ gagal diambil.
        local allCount = nil
        local overlayRef = gui
        task.spawn(function()
            while fpsPingOverlay == overlayRef and overlayRef.Parent do
                local n = fetchAllPlayersCount()
                if n then allCount = n end
                task.wait(30)
            end
        end)

        -- Tampilan bergantian tiap 12 detik: "info" (pemain, FPS, ping) <-> "jam".
        local PHASE_SECONDS = 12
        local showClock = false
        local lastInfoText = nil
        local phaseStart = os.clock()

        fpsPingRenderConnection = RunService.RenderStepped:Connect(function(dt)
            if not fpsPingOverlay or not fpsPingOverlay.Parent or not fpsPingOverlay.Enabled then
                return
            end

            if os.clock() - phaseStart >= PHASE_SECONDS then
                phaseStart = os.clock()
                showClock = not showClock
                mapScrollX = 0
                frames = 0
                elapsed = 0
                if not showClock and lastInfoText then
                    label.RichText = true
                    label.Text = lastInfoText
                end
            end

            -- Jam waktu lokal, diperbarui tiap detik.
            if showClock then
                local clockText = "Jam: " .. os.date("%H:%M:%S")
                -- Rata kiri & atas (baris pertama), sama seperti tampilan info,
                -- agar susunan rapi dan mudah ditambah baris lain nanti.
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.TextYAlignment = Enum.TextYAlignment.Top
                if label.Text ~= clockText then
                    label.RichText = false
                    label.Text = clockText
                end
                mapClip.Visible = true
                if mapTextWidth > MAP_CLIP_W then
                    local loop = mapTextWidth + MAP_GAP
                    mapScrollX = mapScrollX - MAP_SPEED * dt
                    if mapScrollX <= -loop then
                        mapScrollX = mapScrollX + loop
                    end
                    mapLabelA.Position = UDim2.new(0, mapScrollX, 0, 0)
                    mapLabelB.Position = UDim2.new(0, mapScrollX + loop, 0, 0)
                end
                frames = frames + 1
                elapsed = elapsed + dt
                if elapsed >= 0.5 then
                    frames = 0
                    elapsed = 0
                end
                return
            end
            mapClip.Visible = false
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.TextYAlignment = Enum.TextYAlignment.Center

            frames = frames + 1
            elapsed = elapsed + dt

            if elapsed >= 0.5 then
                local fps = math.floor((frames / elapsed) + 0.5)
                local ping = getCurrentPing()
                local fpsColor = (fps < 25 and "#FF4444") or (fps < 40 and "#FFD43B") or "#35D05A"
                local pingColor = (ping >= 150 and "#FF4444") or (ping >= 80 and "#FFD43B") or "#35D05A"
                local playersService = game:GetService("Players")
                local playerCount = #playersService:GetPlayers()
                local maxPlayers = playersService.MaxPlayers
                label.RichText = true
                lastInfoText = string.format(
                    '👥: %d/%d <font color="#00FFFF">(all:%s)</font>\nFPS: <font color="%s">%d</font>\nPing: <font color="%s">%d ms</font>',
                    playerCount, maxPlayers, allCount and tostring(allCount) or "?", fpsColor, fps, pingColor, ping
                )
                label.Text = lastInfoText
                frames = 0
                elapsed = 0
            end
        end)
    else
        if fpsPingRenderConnection then
            fpsPingRenderConnection:Disconnect()
            fpsPingRenderConnection = nil
        end

        if fpsPingOverlay then
            fpsPingOverlay:Destroy()
            fpsPingOverlay = nil
        end
    end
end
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--==================================================
-- VARIABLES
--==================================================

local speedIndex = 1
local speeds = {16, 20.8, 32, 48, 80, 160, 320, 640} -- index 1 (X1) diabaikan = speed original map
local speedNames = {"X1", "X1.3", "X1.6", "X2", "X3", "X5", "X10", "X20"}

-- GAME SPEED (client-side)
local gameSpeedIndex = 1
local gameSpeeds = {1, 2, 3, 5, 0}
local gameSpeedNames = {"OFF", "X2", "X3", "X5", "0X"}
local gameSpeedConnection = nil
local originalNpcWalkSpeed = {}
local originalTrackSpeed = {}

local noclip = false
local flightMode = false
local playerESP = false
local npcESP = false
local itemESP = false

--==================================================


-- FREE CAM COORDINATE DISPLAY
local freeCamCoordGui
local freeCamCoordLabel
local freeCamCopyButton
local freeCamOffButton
local freeCamSetEnabled
local customTpBox
local freeCamCustomTeleportToCoordinates

local function createFreeCamCoordinateUI(parent)
    if freeCamCoordGui then return end

    freeCamCoordGui = Instance.new("Frame")
    freeCamCoordGui.Name = "FreeCamCoordinates"
    freeCamCoordGui.AnchorPoint = Vector2.new(1, 0.5)
    freeCamCoordGui.Position = UDim2.new(1, -20, 0.5, 0)
    freeCamCoordGui.Size = UDim2.new(0, 205, 0, 82)
    freeCamCoordGui.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    freeCamCoordGui.BackgroundTransparency = 0.18
    freeCamCoordGui.BorderSizePixel = 0
    freeCamCoordGui.Visible = false
    freeCamCoordGui.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = freeCamCoordGui

    freeCamCoordLabel = Instance.new("TextLabel")
    freeCamCoordLabel.Name = "Coordinates"
    freeCamCoordLabel.BackgroundTransparency = 1
    freeCamCoordLabel.Position = UDim2.new(0, 10, 0, 0)
    freeCamCoordLabel.Size = UDim2.new(1, -48, 0, 44)
    freeCamCoordLabel.Font = Enum.Font.GothamMedium
    freeCamCoordLabel.TextSize = 14
    freeCamCoordLabel.TextColor3 = Color3.new(1, 1, 1)
    freeCamCoordLabel.TextXAlignment = Enum.TextXAlignment.Left
    freeCamCoordLabel.Text = "X0, Y0, Z0"
    freeCamCoordLabel.Parent = freeCamCoordGui

    freeCamCopyButton = Instance.new("TextButton")
    freeCamCopyButton.Name = "Copy"
    freeCamCopyButton.AnchorPoint = Vector2.new(1, 0.5)
    freeCamCopyButton.Position = UDim2.new(1, -7, 1, -22)
    freeCamCopyButton.Size = UDim2.new(0, 30, 0, 30)
    freeCamCopyButton.BackgroundTransparency = 1
    freeCamCopyButton.Text = "📋"
    freeCamCopyButton.TextSize = 18
    freeCamCopyButton.Parent = freeCamCoordGui

    -- Tombol Go di samping Salin.
    -- Menggunakan fungsi teleport Custom TP yang sama dengan tombol Go utama.
    local freeCamGoButton = Instance.new("TextButton")
    freeCamGoButton.Name = "Go"
    freeCamGoButton.AnchorPoint = Vector2.new(1, 0.5)
    freeCamGoButton.Position = UDim2.new(1, -43, 1, -22)
    freeCamGoButton.Size = UDim2.fromOffset(30, 30)
    freeCamGoButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    freeCamGoButton.BackgroundTransparency = 0
    freeCamGoButton.BorderSizePixel = 0
    freeCamGoButton.Text = "Go"
    freeCamGoButton.TextSize = 12
    freeCamGoButton.Font = Enum.Font.GothamBold
    freeCamGoButton.TextColor3 = Color3.new(1, 1, 1)
    freeCamGoButton.AutoButtonColor = true
    freeCamGoButton.Parent = freeCamCoordGui

    local freeCamGoCorner = Instance.new("UICorner")
    freeCamGoCorner.CornerRadius = UDim.new(0, 6)
    freeCamGoCorner.Parent = freeCamGoButton

    freeCamGoButton.Activated:Connect(function()
        if freeCamCustomTeleportToCoordinates then
            freeCamCustomTeleportToCoordinates()
        end
    end)

    -- customTpBox memakai referensi yang sama dengan kolom Custom TP utama.

    freeCamCopyButton.Activated:Connect(function()
        if not freeCamCoordLabel then return end

        local coords = freeCamCoordLabel.Text
        if not coords or coords == "" then return end

        -- Masukkan koordinat Free Cam langsung ke kolom Custom TP.
        -- Tidak menggunakan clipboard pemain.
        if customTpBox then
            customTpBox.Text = coords

            if customTpBox.Parent then
                customTpBox:CaptureFocus()
                customTpBox.CursorPosition = #customTpBox.Text + 1
            end
        end
    end)

    -- Tombol OFF Free Cam: berada tepat di atas tombol salin koordinat.
    freeCamOffButton = Instance.new("TextButton")
    freeCamOffButton.Name = "FreeCamOff"
    freeCamOffButton.AnchorPoint = Vector2.new(1, 0.5)
    freeCamOffButton.Position = UDim2.new(1, -7, 0, 22)
    freeCamOffButton.Size = UDim2.fromOffset(30, 30)
    freeCamOffButton.BackgroundTransparency = 1
    freeCamOffButton.Text = "OFF"
    freeCamOffButton.TextSize = 12
    freeCamOffButton.Font = Enum.Font.GothamBold
    freeCamOffButton.TextColor3 = Color3.fromRGB(255, 90, 90)
    freeCamOffButton.AutoButtonColor = true
    freeCamOffButton.Parent = freeCamCoordGui

    freeCamOffButton.Activated:Connect(function()
        -- Matikan Free Cam melalui fungsi utama agar semua cleanup tetap jalan.
        if freeCamSetEnabled then
            freeCamSetEnabled(false)
        end

        -- Sinkronkan tombol Free Cam di menu utama.
        local mainGui = playerGui:FindFirstChild("ZaqiAdmin")
        local mainButton = mainGui and mainGui:FindFirstChild("FreeCamMainButton", true)
        if mainButton and mainButton:IsA("TextButton") then
            mainButton.Text = "🎥 Free Cam: OFF"
            -- setButtonState didefinisikan lebih bawah, jadi gunakan warna
            -- OFF secara langsung agar background pasti ikut berubah.
            mainButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        end

        if freeCamCoordGui then
            freeCamCoordGui.Visible = false
        end
    end)
end

local function setFreeCamCoordinateVisible(visible)
    if freeCamCoordGui then
        freeCamCoordGui.Visible = visible
    end
end

local function updateFreeCamCoordinates(camera)
    if not freeCamCoordLabel or not camera then return end
    local p = camera.CFrame.Position
    freeCamCoordLabel.Text = string.format("X%d, Y%d, Z%d", math.round(p.X), math.round(p.Y), math.round(p.Z))
end

-- FREE CAM - MOBILE / TOUCH
--==================================================
-- Free Cam menggunakan kamera Scriptable + virtual joystick.
-- Geser sisi kanan layar untuk melihat sekeliling.
-- Joystick virtual kiri untuk menggerakkan posisi kamera.
-- Sistem ini sengaja tidak memakai Humanoid.CameraOffset atau
-- mengunci CFrame ke Character setiap frame.

local freeCamEnabled = false
local freeCamConnectionName = "ZaqiFreeCam"
local freeCamRenderConnection = nil
local freeCamInputBeganConnection = nil
local freeCamInputChangedConnection = nil
local freeCamInputEndedConnection = nil

local freeCamSpeed = 260
local freeCamForwardSpeed = 110
local freeCamSensitivity = 2.0
local freeCamSmoothness = 14

local freeCamPosition = nil
local freeCamYaw = 0
local freeCamPitch = 0
local freeCamTargetPosition = nil
local freeCamTargetYaw = 0
local freeCamTargetPitch = 0

local freeCamPreviousCameraType = nil
local freeCamPreviousCameraSubject = nil
local freeCamPreviousCameraCFrame = nil

-- Kunci Character secara lokal saat Free Cam aktif agar joystick Free Cam
-- tidak ikut diterima sebagai input gerakan Character.
local freeCamLockedRoot = nil
local freeCamPreviousRootAnchored = nil
local freeCamPreviousAutoRotate = nil

local freeCamTouchLook = nil
local freeCamTouchLookStart = nil
local freeCamTouchLookLast = nil

local freeCamMoveInput = Vector2.zero
local freeCamMoveTouch = nil
local freeCamMoveCenter = nil
local freeCamMoveRadius = 75

local freeCamGui = nil
local freeCamJoystick = nil
local freeCamJoystickKnob = nil
local freeCamHint = nil

local function freeCamClampPitch(value)
    return math.clamp(value, math.rad(-89), math.rad(89))
end

local function freeCamGetCamera()
    return workspace.CurrentCamera
end

local function freeCamCleanupInput()
    if freeCamInputBeganConnection then
        freeCamInputBeganConnection:Disconnect()
        freeCamInputBeganConnection = nil
    end
    if freeCamInputChangedConnection then
        freeCamInputChangedConnection:Disconnect()
        freeCamInputChangedConnection = nil
    end
    if freeCamInputEndedConnection then
        freeCamInputEndedConnection:Disconnect()
        freeCamInputEndedConnection = nil
    end
    if freeCamRenderConnection then
        freeCamRenderConnection:Disconnect()
        freeCamRenderConnection = nil
    end

    freeCamTouchLook = nil
    freeCamTouchLookStart = nil
    freeCamTouchLookLast = nil
    freeCamMoveTouch = nil
    freeCamMoveInput = Vector2.zero

    if freeCamJoystick then
        freeCamJoystick.Visible = false
    end
    if freeCamJoystickKnob then
        freeCamJoystickKnob.Position = UDim2.fromOffset(65,65)
    end
    if freeCamHint then
        freeCamHint.Visible = false
    end
end

local function freeCamCreateMobileGui()
    if freeCamGui and freeCamGui.Parent then
        freeCamJoystick.Visible = true
        freeCamHint.Visible = true
        return
    end

    freeCamGui = Instance.new("ScreenGui")
    freeCamGui.Name = "ZaqiFreeCamControls"
    freeCamGui.ResetOnSpawn = false
    freeCamGui.IgnoreGuiInset = true
    freeCamGui.DisplayOrder = 999
    freeCamGui.Parent = playerGui

    freeCamJoystick = Instance.new("Frame")
    freeCamJoystick.Name = "MoveJoystick"
    freeCamJoystick.Size = UDim2.fromOffset(150,150)
    freeCamJoystick.Position = UDim2.new(0,30,1,-185)
    freeCamJoystick.BackgroundColor3 = Color3.fromRGB(30,30,30)
    freeCamJoystick.BackgroundTransparency = 0.35
    freeCamJoystick.BorderSizePixel = 0
    freeCamJoystick.Visible = true
    freeCamJoystick.Active = false
    freeCamJoystick.Parent = freeCamGui
    Instance.new("UICorner",freeCamJoystick).CornerRadius = UDim.new(1,0)

    freeCamJoystickKnob = Instance.new("Frame")
    freeCamJoystickKnob.Name = "Knob"
    freeCamJoystickKnob.Size = UDim2.fromOffset(48,48)
    freeCamJoystickKnob.Position = UDim2.fromOffset(75,75)
    freeCamJoystickKnob.AnchorPoint = Vector2.new(0.5,0.5)
    freeCamJoystickKnob.BackgroundColor3 = Color3.fromRGB(0,200,100)
    freeCamJoystickKnob.BackgroundTransparency = 0.1
    freeCamJoystickKnob.BorderSizePixel = 0
    freeCamJoystickKnob.Active = false
    freeCamJoystickKnob.Parent = freeCamJoystick
    Instance.new("UICorner",freeCamJoystickKnob).CornerRadius = UDim.new(1,0)

    freeCamHint = Instance.new("TextLabel")
    freeCamHint.Name = "Hint"
    freeCamHint.Size = UDim2.fromOffset(250,30)
    freeCamHint.Position = UDim2.new(1,-260,1,-45)
    freeCamHint.BackgroundTransparency = 1
    freeCamHint.Text = "Joystick = gerak • Geser kanan = lihat"
    freeCamHint.TextColor3 = Color3.fromRGB(255,255,255)
    freeCamHint.TextTransparency = 0.15
    freeCamHint.TextSize = 12
    freeCamHint.Font = Enum.Font.Gotham
    freeCamHint.TextXAlignment = Enum.TextXAlignment.Right
    freeCamHint.Visible = true
    freeCamHint.Parent = freeCamGui
end

freeCamSetEnabled = function(enabled)
    if freeCamEnabled == enabled then
        return
    end

    freeCamEnabled = enabled
    local camera = freeCamGetCamera()

    -- Jangan biarkan fitur kamera lain merebut CurrentCamera.
    if enabled then
        if lockViewEnabled then
            lockViewEnabled = false
            setLockViewEnabled(false)
            if next1Button then
                next1Button.Text = "🔒 Lock View Player: OFF"
                setButtonState(next1Button,false)
            end
        end

        if cinematicOrbitEnabled then
            cinematicOrbitEnabled = false
            setCinematicOrbitEnabled(false)
            if next2Button then
                next2Button.Text = "🎬 Cinematic Orbit: OFF"
                setButtonState(next2Button,false)
            end
        end

        if not camera then
            freeCamEnabled = false
            return
        end

        -- Kunci karakter hanya di sisi client selama Free Cam aktif.
        -- Dengan begitu joystick virtual Free Cam tidak membuat Character
        -- berjalan/berputar, sementara kamera tetap bebas bergerak.
        do
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")

            if root then
                freeCamLockedRoot = root
                freeCamPreviousRootAnchored = root.Anchored
                root.Anchored = true
            end

            if humanoid then
                freeCamPreviousAutoRotate = humanoid.AutoRotate
                humanoid.AutoRotate = false
                humanoid:Move(Vector3.zero, true)
            end
        end

        freeCamPreviousCameraType = camera.CameraType
        freeCamPreviousCameraSubject = camera.CameraSubject
        freeCamPreviousCameraCFrame = camera.CFrame

        local lookVector = camera.CFrame.LookVector
        freeCamPosition = camera.CFrame.Position
        freeCamTargetPosition = freeCamPosition

        freeCamYaw = math.atan2(-lookVector.X,-lookVector.Z)
        freeCamPitch = math.asin(math.clamp(lookVector.Y,-1,1))
        freeCamTargetYaw = freeCamYaw
        freeCamTargetPitch = freeCamPitch

        -- Scriptable mencegah kamera Roblox mengambil alih.
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CameraSubject = nil

        freeCamCreateMobileGui()

        -- Koordinat selalu dibuat di ScreenGui Free Cam yang valid.
        createFreeCamCoordinateUI(freeCamGui)
        setFreeCamCoordinateVisible(true)
        updateFreeCamCoordinates(camera)

        -- Semua input touch dipantau lewat UserInputService, bukan lewat
        -- Frame joystick. Dengan cara ini jari tetap terdeteksi walaupun
        -- sudah keluar/melewati lingkaran joystick.
        freeCamInputBeganConnection = UserInputService.InputBegan:Connect(function(input, gpe)
            if not freeCamEnabled then return end

            if input.UserInputType == Enum.UserInputType.Touch then
                local pos = Vector2.new(input.Position.X, input.Position.Y)
                local viewport = camera.ViewportSize

                -- Touch yang dimulai di area joystick menjadi kontrol gerakan.
                local jpos = freeCamJoystick and freeCamJoystick.AbsolutePosition
                local jsize = freeCamJoystick and freeCamJoystick.AbsoluteSize
                local insideJoystick =
                    jpos
                    and pos.X >= jpos.X
                    and pos.X <= jpos.X + jsize.X
                    and pos.Y >= jpos.Y
                    and pos.Y <= jpos.Y + jsize.Y

                if insideJoystick and not freeCamMoveTouch then
                    freeCamMoveTouch = input
                    freeCamMoveCenter = jpos + jsize / 2

                    local delta = pos - freeCamMoveCenter
                    if delta.Magnitude > freeCamMoveRadius then
                        delta = delta.Unit * freeCamMoveRadius
                    end

                    freeCamMoveInput = Vector2.new(
                        math.clamp(delta.X / freeCamMoveRadius, -1, 1),
                        math.clamp(delta.Y / freeCamMoveRadius, -1, 1)
                    )

                    if freeCamJoystickKnob then
                        freeCamJoystickKnob.Position =
                            UDim2.fromOffset(75 + delta.X, 75 + delta.Y)
                    end
                    return
                end

                -- Touch kedua di sisi kanan menjadi kontrol pandangan.
                -- Ini memungkinkan joystick dan look dipakai bersamaan.
                if pos.X > viewport.X * 0.42 and input ~= freeCamMoveTouch then
                    freeCamTouchLook = input
                    freeCamTouchLookStart = input.Position
                    freeCamTouchLookLast = input.Position
                end
            end
        end)

        freeCamInputChangedConnection = UserInputService.InputChanged:Connect(function(input, gpe)
            if not freeCamEnabled then return end

            -- Global touch tracking: tetap bekerja walaupun jari sudah
            -- melewati batas visual joystick.
            if input.UserInputType == Enum.UserInputType.Touch then
                if input == freeCamMoveTouch then
                    local pos = Vector2.new(input.Position.X, input.Position.Y)
                    local delta = pos - freeCamMoveCenter

                    if delta.Magnitude > freeCamMoveRadius then
                        delta = delta.Unit * freeCamMoveRadius
                    end

                    freeCamMoveInput = Vector2.new(
                        math.clamp(delta.X / freeCamMoveRadius, -1, 1),
                        math.clamp(delta.Y / freeCamMoveRadius, -1, 1)
                    )

                    if freeCamJoystickKnob then
                        freeCamJoystickKnob.Position =
                            UDim2.fromOffset(75 + delta.X, 75 + delta.Y)
                    end

                elseif input == freeCamTouchLook then
                    local current = input.Position
                    local delta = current - freeCamTouchLookLast
                    freeCamTouchLookLast = current

                    freeCamTargetYaw -= delta.X * freeCamSensitivity * 0.018
                    freeCamTargetPitch = freeCamClampPitch(
                        freeCamTargetPitch
                        - delta.Y * freeCamSensitivity * 0.018
                    )
                end

            elseif input.UserInputType == Enum.UserInputType.MouseMovement then
                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                    freeCamTargetYaw -= input.Delta.X * freeCamSensitivity * 0.018
                    freeCamTargetPitch = freeCamClampPitch(
                        freeCamTargetPitch
                        - input.Delta.Y * freeCamSensitivity * 0.018
                    )
                end
            end
        end)

        freeCamInputEndedConnection = UserInputService.InputEnded:Connect(function(input)
            if input == freeCamMoveTouch then
                freeCamMoveTouch = nil
                freeCamMoveInput = Vector2.zero

                if freeCamJoystickKnob then
                    freeCamJoystickKnob.Position =
                        UDim2.fromOffset(75,75)
                end
            end

            if input == freeCamTouchLook then
                freeCamTouchLook = nil
                freeCamTouchLookStart = nil
                freeCamTouchLookLast = nil
            end
        end)

        freeCamRenderConnection = RunService.RenderStepped:Connect(function(dt)
            if not freeCamEnabled then return end

            local currentCamera = freeCamGetCamera()
            if not currentCamera then return end

            -- Pastikan input joystick Free Cam tidak menggerakkan Character.
            do
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:Move(Vector3.zero, true)
                    humanoid.AutoRotate = false
                end
                if freeCamLockedRoot and freeCamLockedRoot.Parent
                    and not (freeCamCoordGui and freeCamCoordGui:GetAttribute("Teleporting")) then
                    freeCamLockedRoot.Anchored = true
                end
            end

            -- Update koordinat secara real-time selama Free Cam aktif.
            if freeCamCoordGui then
                freeCamCoordGui.Visible = true
                updateFreeCamCoordinates(currentCamera)
            end

            -- Pastikan kamera tetap bebas dan tidak direbut CameraModule.
            if currentCamera.CameraType ~= Enum.CameraType.Scriptable then
                currentCamera.CameraType = Enum.CameraType.Scriptable
                currentCamera.CameraSubject = nil
            end

            local alpha = 1 - math.exp(-freeCamSmoothness * math.max(dt,0))
            freeCamYaw += (freeCamTargetYaw - freeCamYaw) * alpha
            freeCamPitch += (freeCamTargetPitch - freeCamPitch) * alpha

            local rotation = CFrame.fromOrientation(freeCamPitch,freeCamYaw,0)
            local forward = rotation.LookVector
            local right = rotation.RightVector
            local up = Vector3.new(0,1,0)

            local moveX = freeCamMoveInput.X
            local moveZ = -freeCamMoveInput.Y

            local moveDirection = right * moveX + forward * moveZ

            if moveDirection.Magnitude > 1 then
                moveDirection = moveDirection.Unit
            end

            -- Kecepatan kanan/kiri tetap cepat, sedangkan maju/mundur
            -- dibuat lebih terkontrol agar tidak terlalu melesat.
            local strafeDirection = right * moveX
            local forwardDirection = forward * moveZ

            local targetPosition = freeCamPosition
                + strafeDirection * freeCamSpeed * dt
                + forwardDirection * freeCamForwardSpeed * dt

            -- Gerakan posisi tetap responsif; smoothness terutama dipakai
            -- untuk rotasi agar kamera tidak terasa patah-patah.
            freeCamPosition = targetPosition

            currentCamera.CFrame =
                CFrame.new(freeCamPosition)
                * CFrame.fromOrientation(freeCamPitch,freeCamYaw,0)
        end)

    else
        freeCamCleanupInput()
        setFreeCamCoordinateVisible(false)

        -- Kembalikan kondisi Character sebelum Free Cam.
        do
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if freeCamLockedRoot and freeCamLockedRoot.Parent then
                freeCamLockedRoot.Anchored =
                    freeCamPreviousRootAnchored or false
            end

            if humanoid and freeCamPreviousAutoRotate ~= nil then
                humanoid.AutoRotate = freeCamPreviousAutoRotate
                humanoid:Move(Vector3.zero, true)
            end

            freeCamLockedRoot = nil
            freeCamPreviousRootAnchored = nil
            freeCamPreviousAutoRotate = nil
        end

        if camera then
            --==================================================
            -- RESTORE CAMERA ROBUST
            --==================================================
            -- Jangan mengembalikan CameraType lama jika nilainya
            -- Scriptable. Setelah Free Cam dimatikan, kamera harus
            -- kembali ke kamera Roblox normal dan mengikuti Humanoid.
            local character = player.Character
            local humanoid = character
                and character:FindFirstChildOfClass("Humanoid")

            if humanoid then
                -- Lepaskan Scriptable terlebih dahulu.
                camera.CameraSubject = humanoid
                camera.CameraType = Enum.CameraType.Custom

                -- Beri CameraModule Roblox kesempatan mengambil alih
                -- pada frame berikutnya. Ini mencegah kamera tetap diam.
                task.defer(function()
                    if not freeCamEnabled and camera and camera.Parent then
                        local currentCharacter = player.Character
                        local currentHumanoid = currentCharacter
                            and currentCharacter:FindFirstChildOfClass("Humanoid")

                        if currentHumanoid then
                            camera.CameraSubject = currentHumanoid
                            camera.CameraType = Enum.CameraType.Custom
                        end
                    end
                end)

                -- Satu pemulihan tambahan untuk kasus CameraModule
                -- terlambat melakukan update pada perangkat/mobile.
                task.delay(0.1, function()
                    if not freeCamEnabled and camera and camera.Parent then
                        local currentCharacter = player.Character
                        local currentHumanoid = currentCharacter
                            and currentCharacter:FindFirstChildOfClass("Humanoid")

                        if currentHumanoid then
                            camera.CameraSubject = currentHumanoid
                            camera.CameraType = Enum.CameraType.Custom
                        end
                    end
                end)
            else
                -- Jika Humanoid sedang belum tersedia (misalnya respawn),
                -- jangan biarkan kamera tertinggal di Scriptable.
                camera.CameraType = Enum.CameraType.Custom

                task.delay(0.15, function()
                    if not freeCamEnabled and camera and camera.Parent then
                        local currentCharacter = player.Character
                        local currentHumanoid = currentCharacter
                            and currentCharacter:FindFirstChildOfClass("Humanoid")

                        if currentHumanoid then
                            camera.CameraSubject = currentHumanoid
                            camera.CameraType = Enum.CameraType.Custom
                        end
                    end
                end)
            end
        end

        freeCamPosition = nil
        freeCamTargetPosition = nil
        freeCamPreviousCameraType = nil
        freeCamPreviousCameraSubject = nil
        freeCamPreviousCameraCFrame = nil
    end
end

--==================================================
-- GUI
--==================================================

local gui = Instance.new("ScreenGui")
gui.Name = "ZaqiAdmin"
gui.ResetOnSpawn = false

-- SELALU DI DEPAN: menu + tombol Z memakai DisplayOrder tertinggi
-- (nilai maksimum Roblox), sehingga tidak tertimpa GUI/tombol game.
-- Dijaga terus: jika game mengubahnya atau memindahkan GUI, dipulihkan.
do
    local TOP_DISPLAY_ORDER = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = TOP_DISPLAY_ORDER
    gui.Parent = playerGui

    gui:GetPropertyChangedSignal("DisplayOrder"):Connect(function()
        if gui.DisplayOrder ~= TOP_DISPLAY_ORDER then
            gui.DisplayOrder = TOP_DISPLAY_ORDER
        end
    end)

    gui:GetPropertyChangedSignal("Parent"):Connect(function()
        if gui.Parent ~= playerGui then
            task.defer(function()
                pcall(function() gui.Parent = playerGui end)
            end)
        end
    end)

    task.spawn(function()
        while gui do
            task.wait(1)
            if gui.DisplayOrder ~= TOP_DISPLAY_ORDER then
                gui.DisplayOrder = TOP_DISPLAY_ORDER
            end
            if gui.Parent ~= playerGui then
                pcall(function() gui.Parent = playerGui end)
            end
        end
    end)
end

--==================================================
-- OPEN BUTTON
--==================================================

local openButton = Instance.new("TextButton")
openButton.Size = UDim2.fromOffset(42,42)
openButton.Position = UDim2.new(0.5,-21,0.5,-21)
openButton.Text = "Z"
openButton.TextSize = 20
openButton.Font = Enum.Font.GothamBold
openButton.TextColor3 = Color3.new(1,1,1)
openButton.BackgroundColor3 = Color3.fromRGB(35,35,35)
openButton.Parent = gui

Instance.new("UICorner",openButton).CornerRadius = UDim.new(0,10)

-- LOCK MENU: mengunci posisi tombol Z agar tidak bergeser.
local menuLocked = false

-- DRAG OPEN BUTTON
local openDragging = false
local openDragStart
local openStartPosition

openButton.InputBegan:Connect(function(input)
    if menuLocked then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then

        openDragging = true
        openDragStart = input.Position
        openStartPosition = openButton.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not openDragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then

        local delta = input.Position - openDragStart

        openButton.Position = UDim2.new(
            openStartPosition.X.Scale,
            openStartPosition.X.Offset + delta.X,
            openStartPosition.Y.Scale,
            openStartPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then

        openDragging = false
    end
end)

--==================================================
-- MAIN MENU
--==================================================

local menu = Instance.new("Frame")
menu.Size = UDim2.fromOffset(220,300)
menu.Position = UDim2.new(0.5,-110,0.5,-150)
menu.BackgroundColor3 = Color3.fromRGB(30,30,30)
menu.BorderSizePixel = 0
menu.Parent = gui

Instance.new("UICorner",menu).CornerRadius = UDim.new(0,10)

--==================================================
-- TITLE
--==================================================

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-45,0,40)
title.Position = UDim2.fromOffset(10,0)
title.BackgroundTransparency = 1
title.Text = "Zaqi Admin"
title.TextColor3 = Color3.fromRGB(255,230,0)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true
title.Parent = menu

-- Animasi warna judul: hijau <-> biru
task.spawn(function()
    local t = 0
    while title.Parent do
        t += 0.02

        -- Nilai 0 = hijau, 1/3 = biru, lalu kembali ke hijau
        local phase = (math.sin(t) + 1) / 2
        title.TextColor3 = Color3.new(
            0,
            1 - phase * 0.55,
            0.15 + phase * 0.85
        )

        task.wait(0.03)
    end
end)

--==================================================
-- CLOSE
--==================================================

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(30,30)
close.Position = UDim2.new(1,-35,0,5)
close.BackgroundTransparency = 1
close.Text = "×"
close.TextColor3 = Color3.new(1,1,1)
close.TextSize = 20
close.Parent = menu

openButton.MouseButton1Click:Connect(function()
	menu.Visible = true
end)

close.MouseButton1Click:Connect(function()
	menu.Visible = false
end)

--==================================================
-- DRAG
--==================================================

local dragging = false
local dragStart
local startPosition

title.InputBegan:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then

		dragging = true
		dragStart = input.Position
		startPosition = menu.Position

	end
end)

UserInputService.InputChanged:Connect(function(input)

	if not dragging then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch then

		local delta = input.Position - dragStart

		menu.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)

	end
end)

UserInputService.InputEnded:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then

		dragging = false

	end
end)

--==================================================
-- SCROLL / STABLE AUTO LAYOUT
--==================================================

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-20,1,-55)
scroll.Position = UDim2.fromOffset(10,45)
scroll.BackgroundColor3 = Color3.fromRGB(35,35,35)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.Parent = menu

Instance.new("UICorner",scroll).CornerRadius = UDim.new(0,8)

local content = Instance.new("Frame")
content.Size = UDim2.new(1,-10,0,0)
content.Position = UDim2.fromOffset(5,5)
content.BackgroundTransparency = 1
content.Parent = scroll

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0,7)
listLayout.Parent = content

local function updateCanvas()
    local height = listLayout.AbsoluteContentSize.Y + 10
    content.Size = UDim2.new(1,-10,0,height)
    scroll.CanvasSize = UDim2.new(0,0,0,height + 10)
end

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

--==================================================
-- BUTTON CREATOR
--==================================================

local buttonOrder = 0

--==================================================
-- BUTTON COLORS
--==================================================

local BUTTON_DEFAULT_COLOR = Color3.fromRGB(55,55,55)
local BUTTON_ACTIVE_COLOR = Color3.fromRGB(0,170,80)

local function setButtonState(button, active)
    if not button then return end

    button.BackgroundColor3 =
        active and BUTTON_ACTIVE_COLOR or BUTTON_DEFAULT_COLOR
end

local function makeButton(text)
    buttonOrder = buttonOrder + 1

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1,0,0,35)
    button.LayoutOrder = buttonOrder

    button.BackgroundColor3 = BUTTON_DEFAULT_COLOR
    button.TextColor3 = Color3.new(1,1,1)
    button.Text = text
    button.TextSize = 13
    button.Font = Enum.Font.Gotham

    button.Parent = content

    Instance.new("UICorner",button).CornerRadius = UDim.new(0,6)

    return button
end

--==================================================
-- SPEED
--==================================================

-- X1 = ORIGINAL: memakai WalkSpeed bawaan game/map (script tidak menyentuhnya).
-- X1.3 dst = angka tetap seperti sebelumnya (20.8, 32, 48, 80, 160, 320, 640).
local speedOriginal = setmetatable({}, {__mode = "k"}) -- humanoid -> speed bawaan game
local speedApplied  = setmetatable({}, {__mode = "k"}) -- humanoid -> nilai terakhir yg di-set script

local function sameSpeed(a, b)
    return math.abs(a - b) < 0.01
end

local function applySelectedSpeed()
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local applied = speedApplied[humanoid]

    if speedIndex == 1 then
        -- Mode ORIGINAL: kembalikan ke speed bawaan game (sekali saja), lalu lepas kendali.
        if applied ~= nil then
            local original = speedOriginal[humanoid]
            -- Jika game sudah mengubahnya sendiri sejak itu, jangan ditimpa.
            if original and sameSpeed(humanoid.WalkSpeed, applied) then
                humanoid.WalkSpeed = original
            end
            speedApplied[humanoid] = nil
            speedOriginal[humanoid] = nil
        end
        return
    end

    local current = humanoid.WalkSpeed

    -- Catat speed bawaan game (untuk dikembalikan saat kembali ke X1).
    if applied == nil or not sameSpeed(current, applied) then
        speedOriginal[humanoid] = current
    end

    local target = speeds[speedIndex]
    if not sameSpeed(current, target) then
        humanoid.WalkSpeed = target
    end
    speedApplied[humanoid] = target
end

local speedButton = makeButton("🏃 Speed: X1")

speedButton.MouseButton1Click:Connect(function()

	speedIndex += 1

	if speedIndex > #speeds then
		speedIndex = 1
	end

	applySelectedSpeed()

	speedButton.Text =
		"🏃 Speed: "..speedNames[speedIndex]

	-- X1 = original (tidak aktif), mode lain = aktif
	setButtonState(speedButton, speedIndex > 1)
end)

--==================================================
-- SPEED PERSISTENCE
-- Hanya bekerja saat speed X1.3 ke atas: menjaga angka speed yang dipilih.
local speedPersistenceRunning = true

task.spawn(function()
    while speedPersistenceRunning do
        task.wait(0.15)
        if speedIndex > 1 then
            applySelectedSpeed()
        end
    end
end)

player.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid", 8)
    if humanoid and speedIndex > 1 then
        task.wait(0.2)
        applySelectedSpeed()
    end
end)

--==================================================
-- GAME SPEED
--==================================================
-- Tombol ini mengubah kecepatan yang terlihat di client:
-- animasi NPC, WalkSpeed NPC yang bisa diubah client, dan
-- laju ClockTime secara visual.
--
-- Penting: game speed server-side yang sebenarnya tidak bisa
-- dipaksa dari LocalScript. Game yang server-authoritative
-- tetap menentukan waktu/AI NPC di server.

local function isNPC(model)
	if not model or not model:IsA("Model") then
		return false
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	return Players:GetPlayerFromCharacter(model) == nil
end

local function restoreGameSpeed()
	for humanoid, oldSpeed in pairs(originalNpcWalkSpeed) do
		if humanoid and humanoid.Parent then
			pcall(function()
				humanoid.WalkSpeed = oldSpeed
			end)
		end
	end
	originalNpcWalkSpeed = {}

	for track, oldSpeed in pairs(originalTrackSpeed) do
		if track and track.Parent then
			pcall(function()
				track:AdjustSpeed(oldSpeed)
			end)
		end
	end
	originalTrackSpeed = {}
end

local function applyGameSpeed(multiplier)
	if gameSpeedConnection then
		gameSpeedConnection:Disconnect()
		gameSpeedConnection = nil
	end

	restoreGameSpeed()

	if multiplier == 1 then
		return
	end

	gameSpeedConnection = RunService.Heartbeat:Connect(function(dt)
		for _, model in ipairs(workspace:GetChildren()) do
			if isNPC(model) then
				local humanoid = model:FindFirstChildOfClass("Humanoid")

				if humanoid then
					if originalNpcWalkSpeed[humanoid] == nil then
						originalNpcWalkSpeed[humanoid] = humanoid.WalkSpeed
					end

					pcall(function()
						if multiplier == 0 then
							-- 0X: NPC tidak dapat berjalan.
							humanoid.WalkSpeed = 0
							humanoid.JumpPower = 0
							humanoid.JumpHeight = 0
						else
							humanoid.WalkSpeed =
								(originalNpcWalkSpeed[humanoid] or 16) * multiplier
						end
					end)
				end

				local animator = model:FindFirstChildOfClass("Animator", true)
				if animator then
					for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
						if originalTrackSpeed[track] == nil then
							originalTrackSpeed[track] = track.Speed
						end

						pcall(function()
							if multiplier == 0 then
								track:AdjustSpeed(0)
							else
								track:AdjustSpeed(
									(originalTrackSpeed[track] or 1) * multiplier
								)
							end
						end)
					end
				end
			end
		end

		-- Pada 0X, jangan majukan waktu visual.
		if multiplier > 0 then
			local lighting = game:GetService("Lighting")
			if lighting then
				lighting.ClockTime =
					(lighting.ClockTime + dt * multiplier * 0.25) % 24
			end
		end
	end)
end

local gameSpeedButton = makeButton("⏩ Game Speed: OFF")

gameSpeedButton.MouseButton1Click:Connect(function()
	gameSpeedIndex += 1

	if gameSpeedIndex > #gameSpeeds then
		gameSpeedIndex = 1
	end

	local multiplier = gameSpeeds[gameSpeedIndex]

	gameSpeedButton.Text =
		"⏩ Game Speed: "..gameSpeedNames[gameSpeedIndex]

	-- OFF = default, mode lain = aktif
	setButtonState(gameSpeedButton, gameSpeedIndex > 1)

	applyGameSpeed(multiplier)

end)

--==================================================
-- NOCLIP
--==================================================

local noclipButton = makeButton("👻 Noclip: OFF")

noclipButton.MouseButton1Click:Connect(function()

	noclip = not noclip

	noclipButton.Text =
		noclip and "👻 Noclip: ON" or "👻 Noclip: OFF"

	setButtonState(noclipButton, noclip)

end)

RunService.Stepped:Connect(function()

	if not noclip then
		return
	end

	local character = player.Character

	if character then

		for _,part in ipairs(character:GetDescendants()) do

			if part:IsA("BasePart") then
				part.CanCollide = false
			end

		end
	end
end)

--==================================================
-- HIGH JUMP
--==================================================

local jumpIndex = 1
local jumpPowers = {50, 75, 100, 150, 200, 250, 500}
local jumpNames = {"OFF", "X1.5", "X2", "X3", "X4", "X5", "X10"}

local jumpButton = makeButton("🦘 High Jump: OFF")

jumpButton.MouseButton1Click:Connect(function()

	jumpIndex += 1

	if jumpIndex > #jumpPowers then
		jumpIndex = 1
	end

	local character = player.Character
	if not character then return end

	local humanoid =
		character:FindFirstChildOfClass("Humanoid")

	if not humanoid then return end

	humanoid.UseJumpPower = true
	humanoid.JumpPower = jumpPowers[jumpIndex]

	jumpButton.Text =
		"🦘 High Jump: "..jumpNames[jumpIndex]

	-- OFF = default, mode lain = aktif
	setButtonState(jumpButton, jumpIndex > 1)
end)


--==================================================

--==================================================
-- FLIGHT MODE
--==================================================

local flightButton =
	makeButton("✈️ Flight Mode: OFF")

local flightConnection
local flightVelocity

flightButton.MouseButton1Click:Connect(function()

	flightMode = not flightMode

	if flightConnection then
		flightConnection:Disconnect()
		flightConnection = nil
	end

	if flightVelocity then
		flightVelocity:Destroy()
		flightVelocity = nil
	end

	local character = player.Character
	if not character then
		flightMode = false
		flightButton.Text = "✈️ Flight Mode: OFF"
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid then
		flightMode = false
		flightButton.Text = "✈️ Flight Mode: OFF"
		return
	end

	if flightMode then

		flightButton.Text = "✈️ Flight Mode: ON"

		flightVelocity = Instance.new("BodyVelocity")
		flightVelocity.MaxForce = Vector3.new(100000,100000,100000)
		flightVelocity.Velocity = Vector3.zero
		flightVelocity.Parent = root

		flightConnection = RunService.RenderStepped:Connect(function()

			if not flightMode or not root.Parent then
				return
			end

			-- Kontrol Flight Mode untuk Android:
			-- joystick menentukan gerakan, sedangkan arah kamera
			-- menentukan arah 3D (termasuk naik/turun).
			local moveDirection = humanoid.MoveDirection
			local camera = workspace.CurrentCamera
			local flightDirection = Vector3.zero

			if camera and moveDirection.Magnitude > 0.01 then

				local cameraLook = camera.CFrame.LookVector
				local cameraRight = camera.CFrame.RightVector

				-- Ambil komponen joystick maju/mundur terhadap kamera.
				local forwardAmount =
					moveDirection:Dot(
						Vector3.new(cameraLook.X, 0, cameraLook.Z).Unit
					)

				-- Arah kanan/kiri tetap mengikuti arah kamera.
				local rightAmount =
					moveDirection:Dot(
						Vector3.new(cameraRight.X, 0, cameraRight.Z).Unit
					)

				-- Forward mengikuti kemiringan kamera, sehingga:
				-- kamera melihat ke atas -> terbang naik
				-- kamera melihat ke bawah -> terbang turun
				local forward3D = cameraLook

				flightDirection =
					(forward3D * forwardAmount) +
					(Vector3.new(cameraRight.X, 0, cameraRight.Z) * rightAmount)

				if flightDirection.Magnitude > 0.01 then
					flightDirection = flightDirection.Unit
				end
			end

			flightVelocity.Velocity = flightDirection * 55

		end)

	else

		flightButton.Text = "✈️ Flight Mode: OFF"

	end

	setButtonState(flightButton, flightMode)

end)

--==================================================
-- ESP
--==================================================
-- ESP bersifat "live": saat ON, pemain baru, karakter yang respawn,
-- NPC baru, dan item baru yang muncul di workspace ikut otomatis di-ESP.

local function removeESP(name)

	for _,object in ipairs(workspace:GetDescendants()) do

		if object:IsA("Highlight")
		and object.Name == "ZaqiESP_"..name then

			object:Destroy()

		end
	end
end

local function addESP(object,color,name)

	if not object or not object.Parent then return end

	if object:FindFirstChild("ZaqiESP_"..name) then
		return
	end

	local highlight = Instance.new("Highlight")

	highlight.Name = "ZaqiESP_"..name
	highlight.Adornee = object
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.2
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = object

end

-- Satu baris 3 tombol (sama seperti Sudut Pandang), diberi judul "Esp mode".
-- Dibungkus fungsi agar tidak menambah variabel local tingkat atas.
local playerButton, npcButton, itemButton = (function()
	-- Judul: teks putih tebal bergaris bawah (bukan tombol).
	buttonOrder = buttonOrder + 1
	local label = Instance.new("TextLabel")
	label.Name = "LabelEspMode"
	label.Size = UDim2.new(1, 0, 0, 22)
	label.LayoutOrder = buttonOrder
	label.BackgroundTransparency = 1
	label.RichText = true
	label.Text = "<b><u>Esp mode</u></b>"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = content

	buttonOrder = buttonOrder + 1
	-- Panel dua baris: [Pemain | Npc | Item] lalu [Interactable ESP | Auto TP+Collect]
	local panel = Instance.new("Frame")
	panel.Name = "EspModePanel"
	panel.Size = UDim2.new(1, 0, 0, 75)
	panel.LayoutOrder = buttonOrder
	panel.BackgroundTransparency = 1
	panel.Parent = content

	local panelLayout = Instance.new("UIListLayout")
	panelLayout.FillDirection = Enum.FillDirection.Vertical
	panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
	panelLayout.Padding = UDim.new(0, 5)
	panelLayout.Parent = panel

	local function makeRow(name, order)
		local row = Instance.new("Frame")
		row.Name = name
		row.Size = UDim2.new(1, 0, 0, 35)
		row.LayoutOrder = order
		row.BackgroundTransparency = 1
		row.Parent = panel

		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Padding = UDim.new(0, 5)
		rowLayout.Parent = row
		return row
	end

	local row = makeRow("EspRow1", 1)
	makeRow("EspRow2", 2)

	local function makeEspButton(name, text, order)
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.new(1 / 3, -4, 1, 0)
		b.LayoutOrder = order
		b.BackgroundColor3 = BUTTON_DEFAULT_COLOR
		b.BorderSizePixel = 0
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = text
		b.TextSize = 12
		b.TextWrapped = true
		b.Font = Enum.Font.GothamBold
		b.AutoButtonColor = true
		b.Parent = row
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		return b
	end

	return makeEspButton("EspPemain", "Pemain", 1),
		makeEspButton("EspNpc", "Npc", 2),
		makeEspButton("EspItem", "Item", 3)
end)()

-- Dibungkus fungsi sendiri agar tidak menambah jumlah variabel local
-- global script (batas Lua = 200 local per fungsi).
;(function()
	-- Semua koneksi ESP disimpan di sini agar bisa diputus saat OFF.
	local espConnections = {
		Player = {},
		NPC = {},
		Item = {},
	}

	-- Daftar NPC yang sedang di-ESP (dipakai untuk label nama + jarak).
	local npcSet = {}
	-- Diisi di bagian bawah (sinkronisasi label nama + jarak).
	local syncEspLabels

	local function clearConnections(name)
		for _,connection in ipairs(espConnections[name]) do
			connection:Disconnect()
		end
		espConnections[name] = {}
	end

	local function track(name,connection)
		table.insert(espConnections[name],connection)
	end

	--==============================================
	-- PLAYER ESP
	--==============================================

	local function watchPlayer(otherPlayer)

		if otherPlayer == player then return end

		if otherPlayer.Character then
			addESP(
				otherPlayer.Character,
				Color3.fromRGB(0,255,255),
				"Player"
			)
		end

		-- Karakter baru (pemain baru join / respawn) otomatis ikut.
		track("Player",otherPlayer.CharacterAdded:Connect(function(character)

			task.defer(function()
				if playerESP then
					addESP(
						character,
						Color3.fromRGB(0,255,255),
						"Player"
					)
				end
			end)

		end))
	end

	playerButton.MouseButton1Click:Connect(function()

		playerESP = not playerESP

		removeESP("Player")
		clearConnections("Player")

		if playerESP then


			for _,otherPlayer in ipairs(Players:GetPlayers()) do
				watchPlayer(otherPlayer)
			end

			-- Pemain yang join setelah ESP dinyalakan.
			track("Player",Players.PlayerAdded:Connect(function(otherPlayer)
				watchPlayer(otherPlayer)
			end))

		else


		end

		setButtonState(playerButton, playerESP)
		if syncEspLabels then syncEspLabels() end
	end)

	--==============================================
	-- NPC ESP
	--==============================================

	local function tryAddNPC(model)

		if not model or not model:IsA("Model") then return end

		if model:FindFirstChildOfClass("Humanoid")
		and not Players:GetPlayerFromCharacter(model) then

			addESP(
				model,
				Color3.fromRGB(255,0,30),
				"NPC"
			)
			npcSet[model] = true

		end
	end

	npcButton.MouseButton1Click:Connect(function()

		npcESP = not npcESP

		removeESP("NPC")
		clearConnections("NPC")
		npcSet = {}

		if npcESP then


			for _,object in ipairs(workspace:GetDescendants()) do
				tryAddNPC(object)
			end

			-- NPC baru: bisa berupa Model baru, atau Humanoid yang
			-- ditambahkan belakangan ke Model yang sudah ada.
			track("NPC",workspace.DescendantAdded:Connect(function(object)

				if object:IsA("Model") then

					task.defer(function()
						if npcESP then tryAddNPC(object) end
					end)

				elseif object:IsA("Humanoid") then

					task.defer(function()
						if npcESP then tryAddNPC(object.Parent) end
					end)

				end
			end))

		else


		end

		setButtonState(npcButton, npcESP)
		if syncEspLabels then syncEspLabels() end
	end)

	--==============================================
	-- ITEM ESP
	--==============================================
	-- Item dikenali dari: Tool, Model/Part dengan nama berisi kata kunci, atau
	-- benda yang punya ProximityPrompt / ClickDetector (item yang bisa diambil).
	-- Roblox hanya merender maksimal ~31 Highlight sekaligus, jadi item yang
	-- di-ESP dibatasi ITEM_ESP_MAX terdekat dari pemain; sisanya otomatis
	-- masuk saat kamu mendekat / item lain hilang.

	local ITEM_ESP_MAX = 24
	local ITEM_KEYWORDS = {"item","product","food","box","drop","loot","pickup"}
	local itemKnown = {}      -- [target] = true (kandidat item)
	local itemScanToken = 0
	local itemRefreshPending = false

	local function isInsideAnyCharacter(object)
		local model = object:FindFirstAncestorOfClass("Model")
		while model do
			if model:FindFirstChildOfClass("Humanoid") then
				return true
			end
			model = model:FindFirstAncestorOfClass("Model")
		end
		return false
	end

	local function hasKeyword(name)
		name = string.lower(name)
		for _,key in ipairs(ITEM_KEYWORDS) do
			if string.find(name,key,1,true) then
				return true
			end
		end
		return false
	end

	-- Ubah sebuah object menjadi target ESP (atau nil jika bukan item).
	local function resolveItem(object)
		if not object or not object.Parent then return nil end
		if object:IsA("Highlight") or object:IsA("Terrain") then return nil end

		local target = nil

		if object:IsA("Tool") then
			target = object

		elseif object:IsA("ProximityPrompt") or object:IsA("ClickDetector") then
			local p = object.Parent
			if p and p:IsA("Attachment") then p = p.Parent end
			if p and p:IsA("BasePart") then
				local m = p.Parent
				if m and m:IsA("Model") and m ~= workspace and #m:GetChildren() <= 40 then
					target = m
				else
					target = p
				end
			elseif p and p:IsA("Model") then
				target = p
			end

		elseif object:IsA("Model") then
			if hasKeyword(object.Name) then target = object end

		elseif object:IsA("BasePart") then
			-- Part lepas (bukan bagian dari Model) yang namanya cocok.
			if hasKeyword(object.Name) and not object.Parent:IsA("Model") then
				target = object
			end
		end

		if not target then return nil end
		if target:FindFirstChildOfClass("Humanoid") then return nil end
		if isInsideAnyCharacter(target) then return nil end

		return target
	end

	local function considerItem(object)
		local target = resolveItem(object)
		if target then
			itemKnown[target] = true
		end
	end

	local function itemDistance(target,origin)
		local ok,pivot = pcall(function() return target:GetPivot().Position end)
		if ok and origin then
			return (pivot - origin).Magnitude
		end
		return 0
	end

	-- Sinkronkan Highlight dengan daftar item: terdekat dapat ESP, sisanya dilepas.
	local function refreshItemESP()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		local origin = (root and root.Position) or (cam and cam.CFrame.Position)

		local list = {}
		for target in pairs(itemKnown) do
			if target.Parent then
				table.insert(list,{target = target, dist = itemDistance(target,origin)})
			else
				itemKnown[target] = nil
			end
		end

		table.sort(list,function(a,b) return a.dist < b.dist end)

		local keep = {}
		for i = 1,math.min(#list,ITEM_ESP_MAX) do
			keep[list[i].target] = true
		end

		for target in pairs(itemKnown) do
			local existing = target:FindFirstChild("ZaqiESP_Item")
			if keep[target] then
				if not existing then
					addESP(target,Color3.fromRGB(255,255,0),"Item")
				end
			elseif existing then
				existing:Destroy()
			end
		end
	end

	itemButton.MouseButton1Click:Connect(function()

		itemESP = not itemESP

		removeESP("Item")
		clearConnections("Item")
		itemKnown = {}
		itemScanToken = itemScanToken + 1

		if itemESP then

			local myToken = itemScanToken

			for _,object in ipairs(workspace:GetDescendants()) do
				considerItem(object)
			end
			refreshItemESP()

			-- Item baru yang muncul / spawn / di-clone setelah ESP dinyalakan.
			-- Dicek ulang beberapa kali karena nama / isi item sering diisi
			-- game SETELAH object dimasukkan ke workspace.
			track("Item",workspace.DescendantAdded:Connect(function(object)
				if not itemESP then return end

				-- Abaikan object yang jelas bukan item (hemat performa saat map load).
				if not (object:IsA("Model") or object:IsA("Tool") or object:IsA("BasePart")
					or object:IsA("ProximityPrompt") or object:IsA("ClickDetector")) then
					return
				end

				for _,delayTime in ipairs({0,0.3,1.2}) do
					task.delay(delayTime,function()
						if itemESP and myToken == itemScanToken then
							considerItem(object)
							-- Part / prompt di dalam Model / Tool baru: cek induknya juga.
							local model = object.Parent
							if model and (model:IsA("Model") or model:IsA("Tool")) then
								considerItem(model)
							end
							-- Refresh digabung (debounce) supaya tidak berat.
							if not itemRefreshPending then
								itemRefreshPending = true
								task.delay(0.25,function()
									itemRefreshPending = false
									if itemESP and myToken == itemScanToken then
										refreshItemESP()
									end
								end)
							end
						end
					end)
				end
			end))

			-- Pengaman: scan ulang berkala (menangkap item yang diganti nama,
			-- ter-stream masuk, atau terlewat) + perbarui item terdekat.
			task.spawn(function()
				while itemESP and myToken == itemScanToken do
					task.wait(1.5)
					if not (itemESP and myToken == itemScanToken) then break end
					for _,object in ipairs(workspace:GetDescendants()) do
						considerItem(object)
					end
					refreshItemESP()
				end
			end)

		else


		end

		setButtonState(itemButton, itemESP)
		if syncEspLabels then syncEspLabels() end
	end)

	--==============================================
	-- LABEL NAMA + JARAK (Pemain / NPC / Item)
	--==============================================
	-- Sama seperti Interactable ESP: tiap target diberi tulisan nama dan
	-- jarak ("12 m"). Bisa di-ON/OFF lewat tombol "Tulisan" di sebelah
	-- judul "Esp mode". Hanya berlaku untuk ESP Pemain, Npc, dan Item.
	local labelsEnabled = true
	local labelGui = nil
	local labelEntries = {}        -- [target] = {billboard, nameLabel, distLabel, part, kind}
	local LABEL_MAX_NPC = 40       -- batasi jumlah label NPC (terdekat)
	local LABEL_INTERVAL = 0.2     -- detik

	local LABEL_COLORS = {
		Player = Color3.fromRGB(0,255,255),
		NPC = Color3.fromRGB(255,60,70),
		Item = Color3.fromRGB(255,255,0),
	}

	local function labelPartOf(target)
		if not target or not target.Parent then return nil end
		if target:IsA("BasePart") then return target end
		if target:IsA("Model") then
			return target:FindFirstChild("Head")
				or target:FindFirstChild("HumanoidRootPart")
				or target.PrimaryPart
				or target:FindFirstChildWhichIsA("BasePart",true)
		end
		if target:IsA("Tool") then
			return target:FindFirstChild("Handle") or target:FindFirstChildWhichIsA("BasePart",true)
		end
		return nil
	end

	local function destroyLabel(target)
		local e = labelEntries[target]
		if not e then return end
		labelEntries[target] = nil
		if e.billboard then e.billboard:Destroy() end
	end

	local function makeLabel(target,part,kind)
		if not (labelGui and labelGui.Parent) then
			labelGui = Instance.new("ScreenGui")
			labelGui.Name = "ZaqiEspLabels"
			labelGui.ResetOnSpawn = false
			labelGui.IgnoreGuiInset = true
			labelGui.DisplayOrder = 4
			labelGui.Parent = playerGui
		end

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ZaqiEspLabel_"..kind
		billboard.Adornee = part
		billboard.AlwaysOnTop = true
		-- Pemain punya 3 baris (nama, darah, jarak) jadi sedikit lebih tinggi
		-- dan digeser lebih ke atas agar tidak menutupi karakter.
		local isPlayer = kind == "Player"
		billboard.Size = isPlayer and UDim2.fromOffset(180,56) or UDim2.fromOffset(180,38)
		-- Item digeser lebih tinggi supaya tidak menumpuk dengan label Interactable.
		billboard.StudsOffset = Vector3.new(0,kind == "Item" and 4.2 or (isPlayer and 3.4 or 2.5),0)
		billboard.MaxDistance = math.huge
		billboard.ResetOnSpawn = false
		billboard.Parent = labelGui

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = isPlayer and UDim2.new(1,0,0.34,0) or UDim2.new(1,0,0.55,0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 14
		nameLabel.TextColor3 = LABEL_COLORS[kind]
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = billboard

		local distLabel = Instance.new("TextLabel")
		distLabel.Name = "Distance"
		distLabel.Size = isPlayer and UDim2.new(1,0,0.30,0) or UDim2.new(1,0,0.45,0)
		distLabel.Position = isPlayer and UDim2.new(0,0,0.70,0) or UDim2.new(0,0,0.55,0)
		distLabel.BackgroundTransparency = 1
		distLabel.Font = Enum.Font.Gotham
		distLabel.TextSize = 12
		distLabel.TextColor3 = Color3.new(1,1,1)
		distLabel.TextStrokeTransparency = 0.3
		distLabel.Parent = billboard

		-- Baris darah (hanya untuk Pemain), tepat di bawah nama.
		local hpLabel = nil
		if isPlayer then
			hpLabel = Instance.new("TextLabel")
			hpLabel.Name = "Health"
			hpLabel.Size = UDim2.new(1,0,0.36,0)
			hpLabel.Position = UDim2.new(0,0,0.34,0)
			hpLabel.BackgroundTransparency = 1
			hpLabel.Font = Enum.Font.GothamBlack
			hpLabel.TextSize = 15
			hpLabel.TextColor3 = Color3.fromRGB(60,255,80)
			hpLabel.TextStrokeColor3 = Color3.new(0,0,0)
			hpLabel.TextStrokeTransparency = 0 -- outline hitam penuh supaya jelas dibaca
			hpLabel.Text = ""
			hpLabel.Parent = billboard
		end

		local e = {billboard = billboard, nameLabel = nameLabel, distLabel = distLabel, hpLabel = hpLabel, part = part, kind = kind}
		labelEntries[target] = e
		return e
	end

	syncEspLabels = function()
		-- Kumpulkan target yang harus punya label saat ini.
		local wanted = {}

		if labelsEnabled and (playerESP or npcESP or itemESP) then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local cam = workspace.CurrentCamera
			local origin = (root and root.Position) or (cam and cam.CFrame.Position)

			local function add(target,kind,text)
				local part = labelPartOf(target)
				if not part then return end
				local dist = origin and (part.Position - origin).Magnitude or 0
				wanted[target] = {kind = kind, part = part, text = text, dist = dist}
			end

			if playerESP then
				for _,other in ipairs(Players:GetPlayers()) do
					if other ~= player and other.Character then
						local humanoid = other.Character:FindFirstChildOfClass("Humanoid")
						if not humanoid or humanoid.Health > 0 then
							add(other.Character,"Player",other.DisplayName ~= "" and other.DisplayName or other.Name)
						end
					end
				end
			end

			if npcESP then
				local npcList = {}
				for model in pairs(npcSet) do
					if model.Parent then
						local part = labelPartOf(model)
						if part then
							table.insert(npcList,{
								model = model,
								dist = origin and (part.Position - origin).Magnitude or 0,
							})
						end
					else
						npcSet[model] = nil
					end
				end
				table.sort(npcList,function(a,b) return a.dist < b.dist end)
				for i = 1,math.min(#npcList,LABEL_MAX_NPC) do
					add(npcList[i].model,"NPC",npcList[i].model.Name)
				end
			end

			if itemESP then
				-- Hanya item yang sedang di-ESP (yang punya Highlight).
				for target in pairs(itemKnown) do
					if target.Parent and target:FindFirstChild("ZaqiESP_Item") then
						add(target,"Item",target.Name)
					end
				end
			end
		end

		-- Buang label yang tidak diperlukan lagi.
		for target in pairs(labelEntries) do
			local w = wanted[target]
			if not w or labelEntries[target].kind ~= w.kind then
				destroyLabel(target)
			end
		end

		-- Buat / perbarui label.
		for target,w in pairs(wanted) do
			local e = labelEntries[target]
			if not e then
				e = makeLabel(target,w.part,w.kind)
			elseif e.part ~= w.part then
				e.part = w.part
				e.billboard.Adornee = w.part
			end
			e.nameLabel.Text = w.text
			e.distLabel.Text = string.format("%d m",math.floor(w.dist + 0.5))

			-- Darah pemain: "sekarang-maks", warna sesuai persentase darah.
			if e.hpLabel then
				local hum = target:FindFirstChildOfClass("Humanoid")
				if hum then
					local maxHp = math.max(hum.MaxHealth,1)
					local hp = math.clamp(hum.Health,0,maxHp)
					local pct = math.floor(hp / maxHp * 100 + 0.5)
					e.hpLabel.Text = string.format("%d-%d",math.floor(hp + 0.5),math.floor(maxHp + 0.5))
					if pct <= 35 then
						e.hpLabel.TextColor3 = Color3.fromRGB(255,45,45)   -- merah
					elseif pct <= 50 then
						e.hpLabel.TextColor3 = Color3.fromRGB(255,140,0)   -- oranye
					elseif pct <= 70 then
						e.hpLabel.TextColor3 = Color3.fromRGB(255,235,0)   -- kuning
					else
						e.hpLabel.TextColor3 = Color3.fromRGB(60,255,80)   -- hijau
					end
				else
					e.hpLabel.Text = ""
				end
			end
		end

		-- ScreenGui kosong tidak perlu dipertahankan.
		if next(labelEntries) == nil and labelGui then
			labelGui:Destroy()
			labelGui = nil
		end
	end

	-- Pembaruan berkala (jarak berubah, pemain/NPC/item datang & pergi).
	task.spawn(function()
		while true do
			task.wait(LABEL_INTERVAL)
			if labelsEnabled and (playerESP or npcESP or itemESP) or next(labelEntries) ~= nil then
				pcall(syncEspLabels)
			end
		end
	end)

	-- Tombol ON/OFF tulisan, di sebelah judul "Esp mode".
	-- Menjadi anak dari judul agar ikut tampil/sembunyi bersama folder.
	do
		local titleLabel = content:WaitForChild("LabelEspMode")
		local toggle = Instance.new("TextButton")
		toggle.Name = "EspLabelToggle"
		toggle.AnchorPoint = Vector2.new(0,0.5)
		toggle.Position = UDim2.new(0,88,0.5,0)
		toggle.Size = UDim2.fromOffset(98,20)
		toggle.BorderSizePixel = 0
		toggle.TextColor3 = Color3.new(1,1,1)
		toggle.TextSize = 11
		toggle.Font = Enum.Font.GothamBold
		toggle.AutoButtonColor = true
		toggle.Parent = titleLabel
		Instance.new("UICorner",toggle).CornerRadius = UDim.new(0,5)

		local function refreshToggle()
			toggle.Text = labelsEnabled and "Tulisan: ON" or "Tulisan: OFF"
			setButtonState(toggle,labelsEnabled)
		end
		refreshToggle()

		toggle.MouseButton1Click:Connect(function()
			labelsEnabled = not labelsEnabled
			refreshToggle()
			syncEspLabels()
		end)
	end
end)()

--==================================================
-- INTERACTABLE ESP
--==================================================
-- Menandai semua objek yang bisa diinteraksikan: ProximityPrompt,
-- ClickDetector, Tool di tanah, serta part sentuh (TouchInterest) bernama
-- koin / peti / tombol / labu / dll. Tiap objek diberi label nama + jarak
-- dan highlight. Deteksi otomatis diperbarui (objek baru, hilang, prompt
-- aktif/nonaktif, jarak) selama fitur ON.
-- Dibungkus fungsi agar tidak menambah variabel local tingkat atas.
;(function()
	local interactableESPEnabled = false

	-- Dua tombol ini berada di baris kedua panel "Esp mode".
	local espRow2 = content:WaitForChild("EspModePanel"):WaitForChild("EspRow2")
	local function makeRow2Button(name,text,order)
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.new(1 / 2, -3, 1, 0)
		b.LayoutOrder = order
		b.BackgroundColor3 = BUTTON_DEFAULT_COLOR
		b.BorderSizePixel = 0
		b.TextColor3 = Color3.new(1,1,1)
		b.Text = text
		b.TextSize = 12
		b.TextWrapped = true
		b.Font = Enum.Font.GothamBold
		b.AutoButtonColor = true
		b.Parent = espRow2
		Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
		return b
	end
	local interactableButton = makeRow2Button("EspInteractable","Interactable ESP",1)

	local MAX_LABELS = 60        -- jumlah label maksimum (terdekat dari pemain)
	local MAX_HIGHLIGHTS = 20    -- Roblox membatasi ~31 Highlight; sisakan untuk ESP lain
	local MAX_DISTANCE = 1500    -- studs; objek lebih jauh diabaikan
	local REFRESH_INTERVAL = 0.2 -- detik, update jarak/label
	local RESCAN_INTERVAL = 3    -- detik, scan ulang penuh sebagai pengaman

	-- Kategori berdasarkan kata kunci nama (urutan = prioritas).
	local CATEGORIES = {
		{name = "Koin",  color = Color3.fromRGB(255,215,0),   keys = {"coin","koin","gold","cash","money","gem","diamond","crystal"}},
		{name = "Peti",  color = Color3.fromRGB(255,140,0),   keys = {"chest","peti","crate","loot","treasure","reward","gift"}},
		{name = "Tombol",color = Color3.fromRGB(255,80,120),  keys = {"button","tombol","lever","switch","door","pintu"}},
		{name = "Ambil", color = Color3.fromRGB(80,255,120),  keys = {"pumpkin","labu","fruit","seed","plant","pickup","drop","item","food","key","egg","harvest"}},
	}
	local DEFAULT_COLOR = Color3.fromRGB(0,220,255)

	-- Auto Collect
	local AUTO_STEP_DELAY = 0.35     -- jeda antar item (detik)
	local AUTO_RETRY_COOLDOWN = 4    -- target yang sama baru dicoba lagi setelah N detik
	local AUTO_COLLECT_ALL = false   -- true = ambil SEMUA interaksi kecuali Tombol/pintu
	local COLLECT_ACTION_KEYS = {"pick","take","collect","get","grab","ambil","harvest","claim","open","buka","panen","loot"}
	local TOUCH_ONLY_KEYS = {"coin","koin","gold","cash","money","gem","diamond","crystal","chest","peti","pickup","drop","pumpkin","labu","key","egg"}

	local espGui = nil
	local folder = nil
	local connections = {}
	local known = {}      -- [trigger instance] = true
	local entries = {}    -- [target] = {billboard, nameLabel, distLabel, highlight, part}
	local token = 0
	local refreshPending = false
	local lastList = {}        -- hasil scan terakhir (terurut dari terdekat)
	local autoEnabled = false
	local autoToken = 0
	local autoCooldown = {}    -- [target] = waktu terakhir dicoba

	local function lowerHas(name,keys)
		name = string.lower(name)
		for _,key in ipairs(keys) do
			if string.find(name,key,1,true) then return true end
		end
		return false
	end

	local function isInsideCharacter(object)
		local model = object:FindFirstAncestorOfClass("Model")
		while model do
			if model:FindFirstChildOfClass("Humanoid") then return true end
			model = model:FindFirstAncestorOfClass("Model")
		end
		return false
	end

	-- Ubah trigger menjadi target (Model / Part / Tool) atau nil.
	local function resolveTarget(trigger)
		if not trigger or not trigger.Parent then return nil end
		local target = nil

		if trigger:IsA("Tool") or trigger:IsA("BasePart") then
			-- Tool tergeletak, atau part sentuh (koin/pickup) itu sendiri.
			target = trigger
		else
			local p = trigger.Parent
			if p:IsA("Attachment") then p = p.Parent end
			if p and p:IsA("BasePart") then
				local m = p.Parent
				if m and m:IsA("Model") and m ~= workspace and #m:GetChildren() <= 40 then
					target = m
				else
					target = p
				end
			elseif p and (p:IsA("Model") or p:IsA("Tool")) and p ~= workspace then
				target = p
			end
		end

		if not target then return nil end
		if target:IsA("Model") and target:FindFirstChildOfClass("Humanoid") then return nil end
		if isInsideCharacter(target) then return nil end
		if target:IsDescendantOf(espGui) then return nil end
		return target
	end

	local function considerObject(object)
		if object:IsA("ProximityPrompt") or object:IsA("ClickDetector") then
			known[object] = true
		elseif object:IsA("Tool") then
			-- Tool yang tergeletak di workspace (bukan di Backpack / karakter).
			if object:IsDescendantOf(workspace) and not isInsideCharacter(object) then
				known[object] = true
			end
		elseif object:IsA("TouchTransmitter") then
			-- Part sentuh (koin, pickup, dll) dengan nama yang cocok.
			local part = object.Parent
			if part and part:IsA("BasePart") and lowerHas(part.Name,TOUCH_ONLY_KEYS) then
				known[part] = true
			end
		end
	end

	-- Info tampilan: nama, kategori/warna, apakah masih valid.
	local function describe(trigger,target)
		local label = nil
		local actionText = nil

		if trigger:IsA("ProximityPrompt") then
			if not trigger.Enabled then return nil end
			if trigger.ObjectText and trigger.ObjectText ~= "" then label = trigger.ObjectText end
			if trigger.ActionText and trigger.ActionText ~= "" then actionText = trigger.ActionText end
		end

		local rawName = target.Name
		label = label or rawName

		local color = DEFAULT_COLOR
		local catName = nil
		local haystack = rawName.." "..(label or "").." "..(actionText or "")
		if trigger ~= target and trigger.Parent then
			haystack = haystack.." "..trigger.Parent.Name
		end
		for _,cat in ipairs(CATEGORIES) do
			if lowerHas(haystack,cat.keys) then
				color = cat.color
				catName = cat.name
				break
			end
		end

		if actionText and string.lower(actionText) ~= string.lower(label) then
			label = label.." ("..actionText..")"
		end
		return label,color,catName,actionText
	end

	local function getAdorneePart(target,cached)
		if cached and cached.Parent and cached:IsDescendantOf(workspace) then
			return cached
		end
		if target:IsA("BasePart") then return target end
		if target:IsA("Model") then
			return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart",true)
		end
		if target:IsA("Tool") then
			return target:FindFirstChild("Handle") or target:FindFirstChildWhichIsA("BasePart",true)
		end
		return nil
	end

	local function destroyEntry(target)
		local e = entries[target]
		if not e then return end
		entries[target] = nil
		if e.billboard then e.billboard:Destroy() end
		if e.highlight then e.highlight:Destroy() end
	end

	local function makeEntry(target,part,color)
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ZaqiInteractableLabel"
		billboard.Adornee = part
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.fromOffset(180,38)
		billboard.StudsOffset = Vector3.new(0,2.5,0)
		billboard.MaxDistance = math.huge
		billboard.ResetOnSpawn = false
		billboard.Parent = folder

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = isPlayer and UDim2.new(1,0,0.34,0) or UDim2.new(1,0,0.55,0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 14
		nameLabel.TextColor3 = color
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = billboard

		local distLabel = Instance.new("TextLabel")
		distLabel.Name = "Distance"
		distLabel.Size = isPlayer and UDim2.new(1,0,0.30,0) or UDim2.new(1,0,0.45,0)
		distLabel.Position = isPlayer and UDim2.new(0,0,0.70,0) or UDim2.new(0,0,0.55,0)
		distLabel.BackgroundTransparency = 1
		distLabel.Font = Enum.Font.Gotham
		distLabel.TextSize = 12
		distLabel.TextColor3 = Color3.new(1,1,1)
		distLabel.TextStrokeTransparency = 0.3
		distLabel.Parent = billboard

		local e = {billboard = billboard, nameLabel = nameLabel, distLabel = distLabel, part = part}
		entries[target] = e
		return e
	end

	local function setHighlight(target,e,color,on)
		if on then
			if not (e.highlight and e.highlight.Parent) then
				local h = Instance.new("Highlight")
				h.Name = "ZaqiInteractableHL"
				h.Adornee = target
				h.FillTransparency = 0.6
				h.OutlineTransparency = 0
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Parent = folder
				e.highlight = h
			end
			e.highlight.FillColor = color
			e.highlight.OutlineColor = color
			e.highlight.Adornee = target
		elseif e.highlight then
			e.highlight:Destroy()
			e.highlight = nil
		end
	end

	local function refresh()
		if not interactableESPEnabled or not folder then return end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		local origin = (root and root.Position) or (cam and cam.CFrame.Position)

		-- Kumpulkan kandidat valid (dedupe per target).
		local byTarget = {}
		for trigger in pairs(known) do
			if not trigger.Parent or not trigger:IsDescendantOf(workspace) then
				known[trigger] = nil
			else
				local target = resolveTarget(trigger)
				if target then
					local part = getAdorneePart(target,entries[target] and entries[target].part)
					local label,color,catName,actionText = describe(trigger,target)
					if part and label then
						local dist = origin and (part.Position - origin).Magnitude or 0
						if dist <= MAX_DISTANCE then
							local cur = byTarget[target]
							if not cur or (trigger:IsA("ProximityPrompt") and not cur.isPrompt) then
								byTarget[target] = {
									target = target, part = part, label = label,
									color = color, dist = dist,
									trigger = trigger, cat = catName, action = actionText,
									isPrompt = trigger:IsA("ProximityPrompt"),
								}
							end
						end
					end
				end
			end
		end

		local list = {}
		for _,item in pairs(byTarget) do table.insert(list,item) end
		table.sort(list,function(a,b) return a.dist < b.dist end)

		lastList = list -- dipakai Auto Collect

		local keep = {}
		for i = 1,math.min(#list,MAX_LABELS) do
			local item = list[i]
			keep[item.target] = true

			local e = entries[item.target]
			if not e then
				e = makeEntry(item.target,item.part,item.color)
			elseif e.part ~= item.part then
				e.part = item.part
				e.billboard.Adornee = item.part
			end

			e.nameLabel.Text = item.label
			e.nameLabel.TextColor3 = item.color
			e.distLabel.Text = string.format("%d m",math.floor(item.dist + 0.5))
			setHighlight(item.target,e,item.color,i <= MAX_HIGHLIGHTS)
		end

		for target in pairs(entries) do
			if not keep[target] then destroyEntry(target) end
		end
	end

	local function requestRefresh(myToken)
		if refreshPending then return end
		refreshPending = true
		task.delay(0.25,function()
			refreshPending = false
			if interactableESPEnabled and myToken == token then refresh() end
		end)
	end

	local function stop()
		token = token + 1
		for _,c in ipairs(connections) do c:Disconnect() end
		connections = {}
		known = {}
		refreshPending = false
		if espGui then espGui:Destroy() end
		espGui = nil
		folder = nil
		entries = {}
	end

	local function start()
		token = token + 1
		local myToken = token

		espGui = Instance.new("ScreenGui")
		espGui.Name = "ZaqiInteractableESP"
		espGui.ResetOnSpawn = false
		espGui.IgnoreGuiInset = true
		espGui.DisplayOrder = 5
		espGui.Parent = playerGui
		folder = espGui

		for _,object in ipairs(workspace:GetDescendants()) do
			considerObject(object)
		end
		refresh()

		-- Objek baru (spawn / clone / stream-in). Dicek ulang karena game
		-- sering mengisi nama / properti setelah objek masuk workspace.
		table.insert(connections,workspace.DescendantAdded:Connect(function(object)
			if not interactableESPEnabled or myToken ~= token then return end
			if not (object:IsA("ProximityPrompt") or object:IsA("ClickDetector")
				or object:IsA("Tool") or object:IsA("TouchTransmitter")) then
				return
			end
			for _,delayTime in ipairs({0,0.5}) do
				task.delay(delayTime,function()
					if interactableESPEnabled and myToken == token and object.Parent then
						considerObject(object)
						requestRefresh(myToken)
					end
				end)
			end
		end))

		-- Objek yang dihapus / diambil langsung hilang dari ESP.
		table.insert(connections,workspace.DescendantRemoving:Connect(function(object)
			if not interactableESPEnabled or myToken ~= token then return end
			if known[object] then
				known[object] = nil
				requestRefresh(myToken)
			end
		end))

		-- Update jarak / status prompt secara berkala + scan ulang penuh.
		task.spawn(function()
			local sinceScan = 0
			while interactableESPEnabled and myToken == token do
				task.wait(REFRESH_INTERVAL)
				if not (interactableESPEnabled and myToken == token) then break end
				sinceScan = sinceScan + REFRESH_INTERVAL
				if sinceScan >= RESCAN_INTERVAL then
					sinceScan = 0
					for _,object in ipairs(workspace:GetDescendants()) do
						considerObject(object)
					end
				end
				pcall(refresh)
			end
		end)
	end

	local autoButton = makeRow2Button("EspAutoCollect","Auto TP+Collect",2)
	local setAuto -- forward declaration

	local function setESP(on)
		interactableESPEnabled = on
		if on then
			start()
		else
			if autoEnabled then setAuto(false) end
			stop()
		end
		setButtonState(interactableButton,on)
	end

	-- Apakah item ini layak diambil otomatis?
	local function isCollectable(item)
		if item.cat == "Tombol" then return false end
		if AUTO_COLLECT_ALL then return true end
		if item.cat then return true end -- Koin / Peti / Ambil
		if not item.trigger:IsA("ProximityPrompt") and not item.trigger:IsA("ClickDetector") then
			return true -- Tool / part sentuh yang sudah lolos filter nama
		end
		return item.action ~= nil and lowerHas(item.action,COLLECT_ACTION_KEYS)
	end

	-- Teleport ke item lalu interaksi (prompt / click / sentuh).
	local function collectItem(item)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local part = item.part
		if not (root and part and part.Parent) then return end

		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
		task.wait(0.12)

		local trigger = item.trigger
		if not trigger.Parent then return end

		if trigger:IsA("ProximityPrompt") then
			if typeof(fireproximityprompt) == "function" then
				pcall(fireproximityprompt,trigger)
			else
				-- Cadangan: tahan tombol interaksi sesuai HoldDuration.
				pcall(function()
					trigger:InputHoldBegin()
					task.wait(trigger.HoldDuration + 0.05)
					trigger:InputHoldEnd()
				end)
			end
		elseif trigger:IsA("ClickDetector") then
			if typeof(fireclickdetector) == "function" then
				pcall(fireclickdetector,trigger)
			end
		elseif trigger:IsA("BasePart") then
			if typeof(firetouchinterest) == "function" then
				pcall(function()
					firetouchinterest(root,trigger,0)
					firetouchinterest(root,trigger,1)
				end)
			end
			-- Teleport ke atas part biasanya sudah memicu Touched.
		end
	end

	setAuto = function(on)
		autoEnabled = on
		autoToken = autoToken + 1
		local myToken = autoToken

		if on then
			-- Auto Collect butuh scan ESP; nyalakan otomatis bila belum.
			if not interactableESPEnabled then
				setESP(true)
				autoEnabled = true
			end
			autoCooldown = {}

			task.spawn(function()
				while autoEnabled and myToken == autoToken do
					task.wait(AUTO_STEP_DELAY)
					if not (autoEnabled and myToken == autoToken) then break end

					local now = os.clock()
					local pick = nil
					for _,item in ipairs(lastList) do
						local last = autoCooldown[item.target]
						if item.trigger.Parent and (not last or now - last >= AUTO_RETRY_COOLDOWN)
							and isCollectable(item) then
							pick = item
							break
						end
					end

					if pick then
						autoCooldown[pick.target] = now
						pcall(collectItem,pick)
						pcall(refresh)
					end
				end
			end)
		end

		setButtonState(autoButton,on)
	end

	interactableButton.MouseButton1Click:Connect(function()
		setESP(not interactableESPEnabled)
	end)

	autoButton.MouseButton1Click:Connect(function()
		setAuto(not autoEnabled)
	end)
end)()

--==================================================
-- FUTURE BUTTON SLOTS
--==================================================

-- Slot kosong sementara, belum memiliki fungsi.
local next1Button = makeButton("🔒 Lock View Player: OFF")

next1Button.MouseButton1Click:Connect(function()
    lockViewEnabled = not lockViewEnabled
    setLockViewEnabled(lockViewEnabled)

    next1Button.Text = lockViewEnabled
        and "🔒 Lock View Player: ON"
        or "🔒 Lock View Player: OFF"

    setButtonState(next1Button, lockViewEnabled)
end)

local next2Button = makeButton("🎬 Cinematic Orbit: OFF")

next2Button.MouseButton1Click:Connect(function()
    local newState = not cinematicOrbitEnabled

    -- Pastikan Lock View tidak berebut kontrol kamera.
    if newState and lockViewEnabled then
        lockViewEnabled = false
        setLockViewEnabled(false)
        next1Button.Text = "🔒 Lock View Player: OFF"
        setButtonState(next1Button, false)
    end

    setCinematicOrbitEnabled(newState)

    next2Button.Text = newState
        and "🎬 Cinematic Orbit: ON"
        or "🎬 Cinematic Orbit: OFF"

    setButtonState(next2Button, newState)
end)

--==================================================
-- NEXT 7 & NEXT 8
--==================================================
-- Next 7 sekarang menjadi tombol Spectate Player.
local next7Button = makeButton("👁️ Spectate Player")

--==================================================
-- SUDUT PANDANG: Orang 1 | Normal | Orang 3
-- Ditaruh tepat di ATAS tombol Auto Emote 1-5.
-- Normal = bawaan game (posisi awal). Orang 2 tidak ada.
--==================================================
do
    buttonOrder = buttonOrder + 1
    do
        local label = Instance.new("TextLabel")
        label.Name = "LabelSudutPandang"
        label.Size = UDim2.new(1, 0, 0, 22)
        label.LayoutOrder = buttonOrder
        label.BackgroundTransparency = 1
        label.RichText = true
        label.Text = "<b><u>Sudut pandang</u></b>"
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextSize = 14
        label.Font = Enum.Font.GothamBold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = content
    end
    buttonOrder = buttonOrder + 1

    local row = Instance.new("Frame")
    row.Name = "SudutPandangPanel"
    row.Size = UDim2.new(1, 0, 0, 35)
    row.LayoutOrder = buttonOrder
    row.BackgroundTransparency = 1
    row.Parent = content

    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Padding = UDim.new(0, 5)
    rowLayout.Parent = row

    -- Pengaturan kamera ASLI game (untuk mode Normal). Diambil SEKALI,
    -- tepat sebelum pemain pertama kali mengubah sudut pandang, supaya
    -- kondisi game sudah stabil (mis. game yang memang orang pertama).
    local svOrig = nil

    local function svCapture()
        if svOrig then return end
        svOrig = {
            mode = player.CameraMode,
            min = player.CameraMinZoomDistance,
            max = player.CameraMaxZoomDistance,
            zoom = nil,
        }
        pcall(function()
            local cam = workspace.CurrentCamera
            local char = player.Character
            local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
            local z
            if cam and head then
                z = (cam.CFrame.Position - head.Position).Magnitude
            elseif cam then
                z = (cam.CFrame.Position - cam.Focus.Position).Magnitude
            end
            if type(z) == "number" and z == z and z < 1000 then
                svOrig.zoom = z
            end
        end)
    end

    local svMode = "normal"
    local svToken = 0
    local svForceUntil = 0
    local svButtons = {}

    local function svRefreshColors()
        for id, b in pairs(svButtons) do
            setButtonState(b, id == svMode)
        end
    end

    -- Paksa jarak kamera ke 'jarak' sebentar, lalu bebaskan zoom lagi.
    local function svForceZoom(jarak, bebasMin, bebasMax)
        svToken = svToken + 1
        local token = svToken
        svForceUntil = os.clock() + 0.4
        player.CameraMinZoomDistance = jarak
        player.CameraMaxZoomDistance = jarak
        task.delay(0.25, function()
            if token ~= svToken then return end
            player.CameraMinZoomDistance = bebasMin
            player.CameraMaxZoomDistance = bebasMax
        end)
    end

    local function svApply(mode)
        svCapture()
        svMode = mode
        svRefreshColors()

        if mode == "pertama" then
            svToken = svToken + 1
            player.CameraMinZoomDistance = 0.5
            player.CameraMaxZoomDistance = 128
            player.CameraMode = Enum.CameraMode.LockFirstPerson

        elseif mode == "ketiga" then
            player.CameraMode = Enum.CameraMode.Classic
            svForceZoom(12, 0.5, 128)

        else -- "normal": kembalikan PERSIS seperti bawaan game
            player.CameraMode = svOrig.mode
            if svOrig.mode == Enum.CameraMode.LockFirstPerson or not svOrig.zoom then
                svToken = svToken + 1
                player.CameraMinZoomDistance = svOrig.min
                player.CameraMaxZoomDistance = svOrig.max
            else
                -- Kembalikan jarak kamera asli (termasuk orang pertama ~0.5),
                -- lalu pulihkan batas zoom asli game.
                local z = math.clamp(svOrig.zoom, svOrig.min, svOrig.max)
                svForceZoom(z, svOrig.min, svOrig.max)
            end
        end
    end

    local svDaftar = {
        { id = "pertama", teks = "Orang 1" },
        { id = "normal",  teks = "Normal" },
        { id = "ketiga",  teks = "Orang 3" },
    }

    for i, item in ipairs(svDaftar) do
        local b = Instance.new("TextButton")
        b.Name = "SudutPandang_" .. item.id
        b.Size = UDim2.new(1 / 3, -4, 1, 0)
        b.LayoutOrder = i
        b.BackgroundColor3 = BUTTON_DEFAULT_COLOR
        b.BorderSizePixel = 0
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Text = item.teks
        b.TextSize = 12
        b.TextWrapped = true
        b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = true
        b.Parent = row
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        svButtons[item.id] = b

        b.MouseButton1Click:Connect(function()
            -- Klik mode yang sama: jalankan ulang saja (aman).
            svApply(item.id)
        end)
    end

    svRefreshColors() -- awal: Normal aktif (hijau), kamera tidak disentuh

    -- Setelah respawn, terapkan ulang pilihan pemain (Normal = biarkan game).
    player.CharacterAdded:Connect(function()
        if svMode == "normal" then return end
        task.wait(0.5)
        if svMode ~= "normal" then
            svApply(svMode)
        end
    end)

    -- PAKSA sudut pandang pilihan pemain terus-menerus.
    -- Game / pindah map / teleport sering mengembalikan CameraMode, batas zoom,
    -- atau jarak kamera ke bawaan. Loop ini mengembalikannya ke pilihan pemain.
    -- Mode Normal tidak disentuh sama sekali.
    local svAccum = 0
    RunService.Heartbeat:Connect(function(dt)
        if svMode == "normal" then return end

        svAccum = svAccum + dt
        if svAccum < 0.1 then return end
        svAccum = 0

        -- Free Cam / Cinematic Orbit memakai kamera Scriptable: jangan ganggu.
        local cam = workspace.CurrentCamera
        if cam and cam.CameraType == Enum.CameraType.Scriptable then return end
        if freeCamEnabled then return end

        if svMode == "pertama" then
            if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
                player.CameraMode = Enum.CameraMode.LockFirstPerson
            end
            if player.CameraMinZoomDistance > 0.5 then
                player.CameraMinZoomDistance = 0.5
            end
            if player.CameraMaxZoomDistance < 0.5 then
                player.CameraMaxZoomDistance = 128
            end

        elseif svMode == "ketiga" then
            if player.CameraMode ~= Enum.CameraMode.Classic then
                player.CameraMode = Enum.CameraMode.Classic
            end

            if os.clock() < svForceUntil then return end

            -- Game membatasi zoom (mis. max 0.5 = orang pertama): bebaskan lagi.
            if player.CameraMaxZoomDistance < 12 or player.CameraMinZoomDistance > 12 then
                player.CameraMinZoomDistance = 0.5
                player.CameraMaxZoomDistance = 128
            end

            -- Kamera terlalu dekat kepala = tampilan orang pertama: jauhkan lagi.
            local char = player.Character
            local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
            if cam and head and (cam.CFrame.Position - head.Position).Magnitude < 2 then
                svForceZoom(12, 0.5, 128)
            end
        end
    end)
end

-- NEXT 8 = AUTO EMOTE 1-5
-- Tombol 1-5 menjadi toggle Auto Emote.
-- Saat karakter bergerak: emote berhenti.
-- Saat karakter diam: emote dimainkan lagi.
buttonOrder = buttonOrder + 1
do
    local label = Instance.new("TextLabel")
    label.Name = "LabelAutoEmot"
    label.Size = UDim2.new(1, 0, 0, 22)
    label.LayoutOrder = buttonOrder
    label.BackgroundTransparency = 1
    label.RichText = true
    label.Text = "<b><u>Auto emot</u></b>"
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = content
end
buttonOrder = buttonOrder + 1

local next8Frame = Instance.new("Frame")
next8Frame.Name = "Next8AutoEmotePanel"
next8Frame.Size = UDim2.new(1, 0, 0, 35)
next8Frame.LayoutOrder = buttonOrder
next8Frame.BackgroundTransparency = 1
next8Frame.Parent = content

local next8Layout = Instance.new("UIListLayout")
next8Layout.FillDirection = Enum.FillDirection.Horizontal
next8Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
next8Layout.VerticalAlignment = Enum.VerticalAlignment.Center
next8Layout.Padding = UDim.new(0, 7)
next8Layout.Parent = next8Frame

local next8EmoteButtons = {}
local activeEmoteIndex = nil
local autoEmoteConnection
local movementConnection
local activeEmoteName = nil
-- Auto Emote default OFF. Atribut "RestoreIndex" pada next8Frame hanya dipakai
-- untuk memulihkan emote yang SEBELUMNYA sengaja dinyalakan pemain setelah
-- respawn (tanpa variabel local baru agar aman dari batas local Lua).

local EMOTE_ON_COLOR = Color3.fromRGB(45, 170, 80)

for i = 1, 5 do
    local emoteButton = Instance.new("TextButton")
    emoteButton.Name = "AutoEmote" .. i
    emoteButton.Size = UDim2.fromOffset(32, 32)
    emoteButton.BackgroundColor3 = BUTTON_DEFAULT_COLOR
    emoteButton.BorderSizePixel = 0
    emoteButton.TextColor3 = Color3.new(1, 1, 1)
    emoteButton.Text = tostring(i)
    emoteButton.TextSize = 13
    emoteButton.Font = Enum.Font.GothamBold
    emoteButton.AutoButtonColor = true
    emoteButton.Parent = next8Frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = emoteButton

    next8EmoteButtons[i] = emoteButton
end

local function getEquippedEmoteNames()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return {}
    end

    local ok, equipped = pcall(function()
        return humanoid.HumanoidDescription:GetEquippedEmotes()
    end)

    if not ok or type(equipped) ~= "table" then
        return {}
    end

    table.sort(equipped, function(a, b)
        return (a.Slot or math.huge) < (b.Slot or math.huge)
    end)

    local names = {}
    for _, info in ipairs(equipped) do
        if info and info.Name then
            names[#names + 1] = info.Name
        end
    end

    return names
end

local function updateEmoteButtonColors()
    for i = 1, 5 do
        local button = next8EmoteButtons[i]
        local emoteName = button:GetAttribute("EmoteName")

        if activeEmoteIndex == i then
            -- Emote yang sedang aktif.
            button.BackgroundColor3 = EMOTE_ON_COLOR
            button.TextTransparency = 0
            button.Active = true
            button.AutoButtonColor = true
        elseif activeEmoteIndex ~= nil then
            -- Ada emote lain yang aktif: semua tombol lain dikunci.
            button.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
            button.TextTransparency = 0.55
            button.Active = false
            button.AutoButtonColor = false
        elseif emoteName and emoteName ~= "" then
            -- Tidak ada emote aktif: semua slot boleh dipilih.
            button.BackgroundColor3 = BUTTON_DEFAULT_COLOR
            button.TextTransparency = 0
            button.Active = true
            button.AutoButtonColor = true
        else
            button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            button.TextTransparency = 0.45
            button.Active = false
            button.AutoButtonColor = false
        end
    end
end

local function stopAutoEmote()
    if autoEmoteConnection then
        autoEmoteConnection:Disconnect()
        autoEmoteConnection = nil
    end

    if movementConnection then
        movementConnection:Disconnect()
        movementConnection = nil
    end

    activeEmoteName = nil
end

local function stopCurrentEmote()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    pcall(function()
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                if track.Priority == Enum.AnimationPriority.Action then
                    track:Stop(0.1)
                end
            end
        end
    end)
end

local function playActiveEmote()
    if not activeEmoteIndex or not activeEmoteName then
        return
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return
    end

    if humanoid.MoveDirection.Magnitude > 0.05 then
        return
    end

    -- Mainkan sekali, lalu matikan loop pada track emote yang baru dibuat.
    pcall(function()
        humanoid:PlayEmote(activeEmoteName)
    end)

    task.delay(0.05, function()
        if activeEmoteIndex == nil or not activeEmoteName then
            return
        end

        local currentCharacter = player.Character
        local currentHumanoid = currentCharacter
            and currentCharacter:FindFirstChildOfClass("Humanoid")

        if not currentHumanoid
            or currentHumanoid.Health <= 0
            or currentHumanoid.MoveDirection.Magnitude > 0.05 then
            return
        end

        pcall(function()
            local animator = currentHumanoid:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    if track.Priority == Enum.AnimationPriority.Action
                        and track.IsPlaying then
                        track.Looped = false
                    end
                end
            end
        end)
    end)
end

local function startAutoEmote(index, emoteName)
    stopAutoEmote()

    activeEmoteIndex = index
    activeEmoteName = emoteName
    updateEmoteButtonColors()

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local wasMoving = humanoid.MoveDirection.Magnitude > 0.05

    movementConnection = RunService.Heartbeat:Connect(function()
        if activeEmoteIndex ~= index then
            return
        end

        local currentCharacter = player.Character
        local currentHumanoid = currentCharacter
            and currentCharacter:FindFirstChildOfClass("Humanoid")

        if not currentHumanoid or currentHumanoid.Health <= 0 then
            return
        end

        local isMoving = currentHumanoid.MoveDirection.Magnitude > 0.05

        if isMoving and not wasMoving then
            -- Mulai bergerak: hentikan emote.
            stopCurrentEmote()

        elseif not isMoving and wasMoving then
            -- Baru berhenti: beri sedikit waktu agar movement animation
            -- selesai, lalu mainkan emote SATU KALI.
            task.delay(0.12, function()
                if activeEmoteIndex ~= index then
                    return
                end

                local idleCharacter = player.Character
                local idleHumanoid = idleCharacter
                    and idleCharacter:FindFirstChildOfClass("Humanoid")

                if idleHumanoid
                    and idleHumanoid.Health > 0
                    and idleHumanoid.MoveDirection.Magnitude <= 0.05 then
                    playActiveEmote()
                end
            end)
        end

        wasMoving = isMoving
    end)

    -- Jika saat tombol ditekan karakter sedang diam, mainkan langsung sekali.
    if not wasMoving then
        playActiveEmote()
    end
end

local function refreshNext8Emotes()
    local names = getEquippedEmoteNames()

    for i = 1, 5 do
        local button = next8EmoteButtons[i]
        local emoteName = names[i]

        button.Text = tostring(i)
        button:SetAttribute("EmoteName", emoteName or "")

        if emoteName then
            button.TextTransparency = 0
            button.Active = true
            button.AutoButtonColor = true
        else
            button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            button.TextTransparency = 0.45
            button.Active = false
            button.AutoButtonColor = false
        end
    end

    updateEmoteButtonColors()
end

for i = 1, 5 do
    next8EmoteButtons[i].MouseButton1Click:Connect(function()
        -- Jika ada emote lain yang aktif, tombol ini sengaja dikunci.
        if activeEmoteIndex ~= nil and activeEmoteIndex ~= i then
            return
        end

        -- Pilihan manual pemain selalu menang atas pemulihan otomatis.
        next8Frame:SetAttribute("RestoreIndex", nil)

        local emoteName = next8EmoteButtons[i]:GetAttribute("EmoteName")
        if not emoteName or emoteName == "" then
            refreshNext8Emotes()
            return
        end

        -- Tekan tombol yang sedang aktif = OFF.
        if activeEmoteIndex == i then
            activeEmoteIndex = nil
            stopAutoEmote()
            updateEmoteButtonColors()
            return
        end

        -- Hanya satu Auto Emote aktif.
        startAutoEmote(i, emoteName)
    end)
end

--==================================================
-- AUTO EMOTE INITIALIZER / SERVER-HOP SAFE
--==================================================
-- Saat pindah server, Character/HumanoidDescription kadang belum selesai
-- dimuat ketika script sudah berjalan. Karena itu jangan langsung mengunci
-- tombol 1-5. Auto Emote default OFF (tidak ada yang dinyalakan otomatis).
local function waitForEmotesAndActivateDefault()
    -- Jika pemain sebelumnya menyalakan Auto Emote, ingat untuk dipulihkan
    -- setelah respawn. Saat pertama kali script dijalankan: tetap OFF.
    if activeEmoteIndex ~= nil then
        next8Frame:SetAttribute("RestoreIndex", activeEmoteIndex)
    end

    -- Pastikan state lama tidak meninggalkan tombol dalam keadaan terkunci.
    stopAutoEmote()
    activeEmoteIndex = nil
    activeEmoteName = nil
    updateEmoteButtonColors()

    local character = player.Character
    if not character then
        character = player.CharacterAdded:Wait()
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
        or character:WaitForChild("Humanoid", 10)

    if not humanoid then
        refreshNext8Emotes()
        return false
    end

    -- Beri waktu HumanoidDescription/avatar selesai dimuat.
    for attempt = 1, 20 do
        if player.Character ~= character then
            return false
        end

        local names = getEquippedEmoteNames()

        if #names > 0 then
            refreshNext8Emotes()

            -- DEFAULT OFF: tidak ada emote yang dinyalakan otomatis.
            -- Hanya pulihkan jika pemain sendiri yang menyalakannya sebelum respawn.
            local restoreIndex = next8Frame:GetAttribute("RestoreIndex")
            next8Frame:SetAttribute("RestoreIndex", nil)

            if restoreIndex then
                local restoreName = names[restoreIndex]
                if restoreName and restoreName ~= "" and activeEmoteIndex == nil then
                    startAutoEmote(restoreIndex, restoreName)
                end
            end

            return true
        end

        task.wait(0.25)
    end

    -- Gagal mendapatkan emote bukan berarti tombol harus dikunci.
    -- Biarkan 1-5 tetap bisa dicoba setelah data avatar tersedia.
    refreshNext8Emotes()
    updateEmoteButtonColors()
    return false
end

refreshNext8Emotes()

-- Default: Auto Emote OFF. Pemain menyalakan sendiri lewat tombol 1-5.
task.spawn(function()
    waitForEmotesAndActivateDefault()
end)

-- Saat pindah server/respawn, ulangi proses dari awal.
player.CharacterAdded:Connect(function(character)
    task.spawn(function()
        -- Pastikan Character baru benar-benar siap.
        local humanoid = character:FindFirstChildOfClass("Humanoid")
            or character:WaitForChild("Humanoid", 10)

        if not humanoid then
            return
        end

        task.wait(0.5)
        waitForEmotesAndActivateDefault()
    end)
end)

-- Beberapa pengalaman memuat avatar/emote sedikit setelah CharacterAdded.
-- Event ini memberi kesempatan kedua tanpa membuat tombol terkunci.
pcall(function()
    player.CharacterAppearanceLoaded:Connect(function(character)
        if character == player.Character then
            task.spawn(function()
                task.wait(0.15)

                if activeEmoteIndex == nil then
                    waitForEmotesAndActivateDefault()
                else
                    refreshNext8Emotes()
                end
            end)
        end
    end)
end)

local next9Button = makeButton("🎬 AFK Cinematic: OFF")

--==================================================
-- AFK CINEMATIC - 9 SECOND IDLE / FRONT FACE FOCUS
--==================================================
do
    local afkCinematicEnabled = false
    local afkAutoMode = false
    local afkMonitorConnection = nil
    local afkShotToken = 0

    local afkBarsGui = nil
    local afkTopBar = nil
    local afkBottomBar = nil

    local afkPreviousCameraType = nil
    local afkPreviousCameraSubject = nil
    local afkPreviousFOV = nil

    local afkLastShot = nil
    local afkLastMoveTime = os.clock()
    local afkWasMoving = false

    local AFK_DELAY = 9

    local function afkCreateBars()
        if afkBarsGui and afkBarsGui.Parent then
            return
        end

        afkBarsGui = Instance.new("ScreenGui")
        afkBarsGui.Name = "ZaqiAFKCinematicBars"
        afkBarsGui.ResetOnSpawn = false
        afkBarsGui.IgnoreGuiInset = true
        afkBarsGui.DisplayOrder = 999
        afkBarsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        afkBarsGui.Parent = playerGui

        afkTopBar = Instance.new("Frame")
        afkTopBar.Name = "TopBar"
        afkTopBar.Size = UDim2.new(1, 0, 0, 52)
        afkTopBar.Position = UDim2.new(0, 0, 0, -52)
        afkTopBar.BackgroundColor3 = Color3.new(0, 0, 0)
        afkTopBar.BorderSizePixel = 0
        afkTopBar.ZIndex = 999
        afkTopBar.Parent = afkBarsGui

        afkBottomBar = Instance.new("Frame")
        afkBottomBar.Name = "BottomBar"
        afkBottomBar.Size = UDim2.new(1, 0, 0, 52)
        afkBottomBar.Position = UDim2.new(0, 0, 1, 0)
        afkBottomBar.BackgroundColor3 = Color3.new(0, 0, 0)
        afkBottomBar.BorderSizePixel = 0
        afkBottomBar.ZIndex = 999
        afkBottomBar.Parent = afkBarsGui
    end

    local function afkShowBars()
        afkCreateBars()

        if afkTopBar then
            afkTopBar:TweenPosition(
                UDim2.new(0, 0, 0, 0),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Quad,
                0.45,
                true
            )
        end

        if afkBottomBar then
            afkBottomBar:TweenPosition(
                UDim2.new(0, 0, 1, -52),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Quad,
                0.45,
                true
            )
        end
    end

    local function afkHideBars()
        if afkTopBar then
            afkTopBar:TweenPosition(
                UDim2.new(0, 0, 0, -52),
                Enum.EasingDirection.In,
                Enum.EasingStyle.Quad,
                0.35,
                true
            )
        end

        if afkBottomBar then
            afkBottomBar:TweenPosition(
                UDim2.new(0, 0, 1, 0),
                Enum.EasingDirection.In,
                Enum.EasingStyle.Quad,
                0.35,
                true
            )
        end
    end

    local function afkDestroyBars()
        if afkBarsGui then
            afkBarsGui:Destroy()
        end

        afkBarsGui = nil
        afkTopBar = nil
        afkBottomBar = nil
    end

    local function afkGetTarget()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if not humanoid or not root or humanoid.Health <= 0 then
            return nil, nil
        end

        return root, humanoid
    end

    local function afkRestoreCamera()
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end

        camera.CameraType = afkPreviousCameraType or Enum.CameraType.Custom

        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        camera.CameraSubject = afkPreviousCameraSubject or humanoid

        if afkPreviousFOV then
            camera.FieldOfView = afkPreviousFOV
        end
    end

    local function afkChooseShot()
        -- Front-facing shots dibuat lebih sering muncul.
        local weightedShots = {
            "FrontClose",
            "FrontClose",
            "FrontMedium",
            "FrontMedium",
            "FrontZoom",
            "FrontZoom",
            "Orbit",
            "PanLeft",
            "PanRight",
            "Side",
            "Low",
            "High",
            "Wide",
            "Arc",
            "Static",
        }

        local available = {}

        for _, shot in ipairs(weightedShots) do
            if shot ~= afkLastShot then
                table.insert(available, shot)
            end
        end

        local selected = available[math.random(1, #available)]
        afkLastShot = selected
        return selected
    end

    local function afkShotCFrame(shot, root, elapsed, duration)
        local character = root.Parent
        local target = root.Position + Vector3.new(0, 1.7, 0)

        local progress = math.clamp(elapsed / duration, 0, 1)
        local wave = math.sin(progress * math.pi * 2)

        local distance = 9
        local height = 3
        local angle = math.rad(35)

        -- Front camera memakai LookVector karakter sehingga kamera
        -- benar-benar berada di depan wajah pemain.
        local frontDirection = root.CFrame.LookVector
        local rightDirection = root.CFrame.RightVector

        if shot == "FrontClose" then
            -- Sering menghadap wajah pemain.
            distance = 4.8 + math.sin(progress * math.pi) * 0.45
            height = 2.0 + wave * 0.08

            local position = target + frontDirection * distance
            return CFrame.lookAt(position, target)

        elseif shot == "FrontMedium" then
            distance = 8.0 + wave * 0.35
            height = 2.7 + wave * 0.12

            local position = target + frontDirection * distance
            return CFrame.lookAt(position, target)

        elseif shot == "FrontZoom" then
            -- Zoom out -> zoom in secara halus.
            local zoomCycle = (math.sin(progress * math.pi * 2) + 1) / 2
            distance = 5.5 + (7.5 * zoomCycle)
            height = 2.4 + wave * 0.12

            local position = target + frontDirection * distance
            return CFrame.lookAt(position, target)

        elseif shot == "Orbit" then
            angle = math.rad(25) + elapsed * 0.32
            distance = 9
            height = 3

        elseif shot == "PanLeft" then
            angle = math.rad(65) - progress * math.rad(50)
            distance = 10
            height = 3.2

        elseif shot == "PanRight" then
            angle = math.rad(-65) + progress * math.rad(50)
            distance = 10
            height = 3.2

        elseif shot == "Side" then
            angle = math.rad(90) + wave * math.rad(5)
            distance = 8
            height = 2.7

        elseif shot == "Low" then
            angle = math.rad(20)
            distance = 9
            height = 0.9

        elseif shot == "High" then
            angle = math.rad(25)
            distance = 10
            height = 8

        elseif shot == "Wide" then
            angle = math.rad(155) + progress * math.rad(50)
            distance = 15
            height = 5

        elseif shot == "Arc" then
            angle = math.rad(-80) + progress * math.rad(160)
            distance = 10
            height = 4.2

        elseif shot == "Static" then
            angle = math.rad(40)
            distance = 10
            height = 3.5
        end

        distance = math.max(distance, 4.5)

        local offset = Vector3.new(
            math.cos(angle) * distance,
            height,
            math.sin(angle) * distance
        )

        local position = target + offset
        return CFrame.lookAt(position, target)
    end

    local function afkRunShot()
        if not afkCinematicEnabled or afkWasMoving then
            return
        end

        local camera = workspace.CurrentCamera
        local root = afkGetTarget()

        if not camera or not root then
            return
        end

        afkShotToken += 1
        local myToken = afkShotToken

        local shot = afkChooseShot()
        local duration = math.random(4, 8)
        local elapsed = 0

        local startFOV = camera.FieldOfView
        local targetFOV = startFOV

        if shot == "FrontClose" then
            targetFOV = 45
        elseif shot == "FrontMedium" then
            targetFOV = 52
        elseif shot == "FrontZoom" then
            targetFOV = 48
        elseif shot == "Wide" then
            targetFOV = 72
        elseif shot == "Static" then
            targetFOV = startFOV
        else
            targetFOV = math.clamp(startFOV + math.random(-4, 4), 45, 75)
        end

        camera.CameraType = Enum.CameraType.Scriptable
        camera.CameraSubject = nil

        while afkCinematicEnabled
            and afkAutoMode
            and not afkWasMoving
            and myToken == afkShotToken
            and elapsed < duration do

            local delta = task.wait()
            elapsed += math.max(delta, 0)

            if afkWasMoving then
                break
            end

            local currentRoot = afkGetTarget()
            if not currentRoot then
                break
            end

            local desired = afkShotCFrame(
                shot,
                currentRoot,
                elapsed,
                duration
            )

            local blend = math.clamp(delta * 4.5, 0, 1)
            camera.CFrame = camera.CFrame:Lerp(desired, blend)

            local fovBlend = math.clamp(delta * 2.5, 0, 1)
            camera.FieldOfView = camera.FieldOfView
                + (targetFOV - camera.FieldOfView) * fovBlend
        end
    end

    local function afkStartCinematic()
        local camera = workspace.CurrentCamera
        local root, humanoid = afkGetTarget()

        if not camera or not root or not humanoid then
            return
        end

        afkPreviousCameraType = camera.CameraType
        afkPreviousCameraSubject = camera.CameraSubject
        afkPreviousFOV = camera.FieldOfView
        afkLastShot = nil

        afkShowBars()

        task.spawn(function()
            while afkCinematicEnabled and afkAutoMode do
                afkRunShot()

                if afkCinematicEnabled and afkAutoMode and not afkWasMoving then
                    task.wait(0.15)
                end
            end
        end)
    end

    local function afkStopCinematic()
        afkCinematicEnabled = false
        afkShotToken += 1

        afkHideBars()
        afkRestoreCamera()

        task.delay(0.4, function()
            if not afkCinematicEnabled then
                afkDestroyBars()
            end
        end)

        afkPreviousCameraType = nil
        afkPreviousCameraSubject = nil
        afkPreviousFOV = nil
        afkLastShot = nil
    end

    -- Tombol hanya ON/OFF.
    -- Tombol ON = sistem AFK otomatis aktif.
    -- Cinematic baru berjalan setelah 9 detik tanpa gerak.
    next9Button.MouseButton1Click:Connect(function()
        afkAutoMode = not afkAutoMode

        if afkAutoMode then
            afkLastMoveTime = os.clock()
            afkWasMoving = false
            next9Button.Text = "🎬 AFK Cinematic: ON"
            setButtonState(next9Button, true)
        else
            afkStopCinematic()
            afkLastMoveTime = os.clock()
            afkWasMoving = false
            next9Button.Text = "🎬 AFK Cinematic: OFF"
            setButtonState(next9Button, false)
        end
    end)

    -- Monitor gerakan dan timer AFK.
    afkMonitorConnection = RunService.Heartbeat:Connect(function()
        if not afkAutoMode then
            return
        end

        local root, humanoid = afkGetTarget()
        if not root or not humanoid then
            return
        end

        local moving = humanoid.MoveDirection.Magnitude > 0.05

        if moving then
            afkLastMoveTime = os.clock()

            if not afkWasMoving then
                afkWasMoving = true

                if afkCinematicEnabled then
                    afkStopCinematic()
                end
            end

            return
        end

        afkWasMoving = false

        local idleTime = os.clock() - afkLastMoveTime

        if not afkCinematicEnabled and idleTime >= AFK_DELAY then
            afkCinematicEnabled = true
            setButtonState(next9Button, true)
            next9Button.Text = "🎬 AFK Cinematic: ON"
            afkStartCinematic()
        end
    end)

    player.CharacterAdded:Connect(function()
        afkCinematicEnabled = false
        afkAutoMode = false
        afkShotToken += 1
        afkWasMoving = false
        afkLastMoveTime = os.clock()

        afkHideBars()
        afkDestroyBars()

        task.wait(0.2)

        local camera = workspace.CurrentCamera
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if camera then
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = humanoid
        end

        next9Button.Text = "🎬 AFK Cinematic: OFF"
        setButtonState(next9Button, false)
    end)

    -- Default OFF.
    next9Button.Text = "🎬 AFK Cinematic: OFF"
    setButtonState(next9Button, false)
end

-- SPECTATE PLAYER - SQUID GAME STYLE
--==================================================
do
    local spectateEnabled = false
    local spectateIndex = 0
    local spectateTarget = nil
    -- Menyimpan target terakhir agar saat Spectate dibuka kembali,
    -- target tetap pemain terakhir yang dipilih jika masih tersedia.
    local spectateLastTargetUserId = nil
    local spectatePlayers = {}
    local spectatePanel
    local spectateNameLabel
    local spectatePrevButton
    local spectateNextButton
    local spectateStopButton
    local spectateAutoTeleportButton
    local spectateCharacterConnection
    local spectateAutoTeleportConnection
    local spectateRemovingConnection
    local spectateAddedConnection

    local function spectateDisconnectConnection(connection)
        if connection then
            connection:Disconnect()
        end
        return nil
    end

    local function spectateGetPlayers()
        local result = {}

        for _, target in ipairs(Players:GetPlayers()) do
            if target ~= player then
                local character = target.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                -- Hanya pemain yang memiliki karakter aktif.
                if character and character.Parent and humanoid and humanoid.Health > 0 then
                    table.insert(result, target)
                end
            end
        end

        table.sort(result, function(a, b)
            return a.UserId < b.UserId
        end)

        return result
    end

    local function spectateRestoreCamera()
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end

        camera.CameraType = Enum.CameraType.Custom

        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if humanoid then
            camera.CameraSubject = humanoid
        else
            camera.CameraSubject = nil
        end
    end

    local function spectateUpdateTarget()
        if not spectateEnabled then
            return
        end

        spectatePlayers = spectateGetPlayers()

        if #spectatePlayers == 0 then
            spectateTarget = nil
            spectateIndex = 0

            if spectateNameLabel then
                spectateNameLabel.Text = "Tidak Ada Player"
            end

            return
        end

        -- Pastikan index selalu valid.
        if spectateIndex < 1 then
            spectateIndex = 1
        elseif spectateIndex > #spectatePlayers then
            spectateIndex = 1
        end

        local target = spectatePlayers[spectateIndex]
        spectateTarget = target
        spectateLastTargetUserId = target.UserId

        if spectateNameLabel then
            spectateNameLabel.Text =
                target.DisplayName ~= ""
                and target.DisplayName
                or target.Name
        end

        local character = target.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if humanoid and humanoid.Health > 0 then
            local camera = workspace.CurrentCamera

            if camera then
                camera.CameraType = Enum.CameraType.Custom
                camera.CameraSubject = humanoid
            end
        end
    end

    local function spectateRefresh()
        if not spectateEnabled then
            return
        end

        local oldTarget = spectateTarget
        local oldUserId = oldTarget and oldTarget.UserId

        spectatePlayers = spectateGetPlayers()

        if #spectatePlayers == 0 then
            spectateTarget = nil
            spectateIndex = 0

            if spectateNameLabel then
                spectateNameLabel.Text = "Tidak Ada Player"
            end

            return
        end

        -- Pertahankan target saat ini jika masih hidup/tersedia.
        if oldUserId then
            for i, target in ipairs(spectatePlayers) do
                if target.UserId == oldUserId then
                    spectateIndex = i
                    spectateUpdateTarget()
                    return
                end
            end
        end

        -- Target sudah tidak tersedia, pindah ke pemain berikutnya.
        if spectateIndex > #spectatePlayers then
            spectateIndex = 1
        end

        spectateUpdateTarget()
    end

    local autoTeleportEnabled = false

    local function autoTeleportDisconnect()
        if spectateAutoTeleportConnection then
            spectateAutoTeleportConnection:Disconnect()
            spectateAutoTeleportConnection = nil
        end
    end

    local function setAutoTeleportButtonState()
        if not spectateAutoTeleportButton then
            return
        end

        spectateAutoTeleportButton.Text =
            autoTeleportEnabled
            and "Auto Teleport: ON"
            or "Auto Teleport: OFF"

        setButtonState(spectateAutoTeleportButton, autoTeleportEnabled)
    end

    local function setAutoTeleportEnabled(enabled)
        autoTeleportEnabled = enabled == true
        autoTeleportDisconnect()

        if autoTeleportEnabled then
            spectateAutoTeleportConnection = RunService.Heartbeat:Connect(function()
                if not autoTeleportEnabled or not spectateEnabled then
                    return
                end

                local target = spectateTarget
                local targetCharacter = target and target.Character
                local targetRoot =
                    targetCharacter
                    and targetCharacter:FindFirstChild("HumanoidRootPart")

                local localCharacter = player.Character
                local localRoot =
                    localCharacter
                    and localCharacter:FindFirstChild("HumanoidRootPart")

                local localHumanoid =
                    localCharacter
                    and localCharacter:FindFirstChildOfClass("Humanoid")

                if not targetRoot
                    or not targetRoot.Parent
                    or not localRoot
                    or not localRoot.Parent
                    or not localHumanoid
                    or localHumanoid.Health <= 0 then
                    return
                end

                -- Ikuti posisi target secara terus-menerus.
                -- PivotTo memindahkan seluruh karakter, bukan hanya kamera.
                pcall(function()
                    localCharacter:PivotTo(targetCharacter:GetPivot())
                    localRoot.AssemblyLinearVelocity = targetRoot.AssemblyLinearVelocity
                    localRoot.AssemblyAngularVelocity = targetRoot.AssemblyAngularVelocity
                end)
            end)
        end

        setAutoTeleportButtonState()
    end

    local function spectateStop()
        setAutoTeleportEnabled(false)

        -- Simpan target yang sedang dilihat sebelum Spectate dihentikan.
        if spectateTarget and spectateTarget.Parent == Players then
            spectateLastTargetUserId = spectateTarget.UserId
        end

        spectateEnabled = false
        spectateTarget = nil
        spectateIndex = 0
        spectatePlayers = {}

        spectateCharacterConnection =
            spectateDisconnectConnection(spectateCharacterConnection)
        spectateRemovingConnection =
            spectateDisconnectConnection(spectateRemovingConnection)
        spectateAddedConnection =
            spectateDisconnectConnection(spectateAddedConnection)

        if spectatePanel then
            spectatePanel.Visible = false
        end

        if spectateAutoTeleportButton then
            spectateAutoTeleportButton.Visible = false
        end

        spectateRestoreCamera()
    end

    local function spectateStart()
        if spectateEnabled then
            return
        end

        -- Jangan mengambil alih kamera jika FreeCam sedang aktif.
        if freeCamEnabled then
            return
        end

        spectateEnabled = true
        spectatePlayers = spectateGetPlayers()

        if #spectatePlayers == 0 then
            spectateIndex = 0
            spectateTarget = nil

            if spectateNameLabel then
                spectateNameLabel.Text = "Tidak Ada Player"
            end

            if spectatePanel then
                spectatePanel.Visible = true
            end

            if spectateAutoTeleportButton then
                spectateAutoTeleportButton.Visible = true
                setAutoTeleportButtonState()
            end

            return
        end

        -- Pertahankan pemain terakhir yang dipilih.
        -- Jika pemain tersebut masih tersedia, mulai kembali dari pemain itu.
        -- Jika sudah tidak tersedia, gunakan pemain pertama yang tersedia.
        spectateIndex = 1

        if spectateLastTargetUserId then
            for i, target in ipairs(spectatePlayers) do
                if target.UserId == spectateLastTargetUserId then
                    spectateIndex = i
                    break
                end
            end
        end

        spectateTarget = spectatePlayers[spectateIndex]

        if spectatePanel then
            spectatePanel.Visible = true
        end

        if spectateAutoTeleportButton then
            spectateAutoTeleportButton.Visible = true
            setAutoTeleportButtonState()
        end

        spectateUpdateTarget()

        -- Jika target respawn, kamera kembali mengikuti karakter barunya.
        spectateCharacterConnection =
            spectateTarget.CharacterAdded:Connect(function(character)
                if not spectateEnabled then
                    return
                end

                task.defer(function()
                    local humanoid = character:WaitForChild("Humanoid", 5)

                    if humanoid
                        and humanoid.Health > 0
                        and spectateEnabled
                        and spectateTarget then

                        local camera = workspace.CurrentCamera

                        if camera then
                            camera.CameraType = Enum.CameraType.Custom
                            camera.CameraSubject = humanoid
                        end
                    end
                end)
            end)

        -- Jika pemain keluar, otomatis pilih pemain yang tersedia berikutnya.
        spectateRemovingConnection =
            Players.PlayerRemoving:Connect(function(leavingPlayer)
                if not spectateEnabled then
                    return
                end

                if leavingPlayer == spectateTarget then
                    task.defer(function()
                        if not spectateEnabled then
                            return
                        end

                        spectatePlayers = spectateGetPlayers()

                        if #spectatePlayers == 0 then
                            spectateTarget = nil
                            spectateIndex = 0

                            if spectateNameLabel then
                                spectateNameLabel.Text = "Tidak Ada Player"
                            end

                            return
                        end

                        if spectateIndex > #spectatePlayers then
                            spectateIndex = 1
                        end

                        spectateUpdateTarget()
                    end)
                else
                    task.defer(spectateRefresh)
                end
            end)

        spectateAddedConnection =
            Players.PlayerAdded:Connect(function()
                if spectateEnabled then
                    task.defer(spectateRefresh)
                end
            end)
    end

    local function spectatePrevious()
        if not spectateEnabled then
            return
        end

        spectatePlayers = spectateGetPlayers()

        if #spectatePlayers == 0 then
            return
        end

        spectateIndex -= 1

        if spectateIndex < 1 then
            spectateIndex = #spectatePlayers
        end

        spectateUpdateTarget()
    end

    local function spectateNext()
        if not spectateEnabled then
            return
        end

        spectatePlayers = spectateGetPlayers()

        if #spectatePlayers == 0 then
            return
        end

        spectateIndex += 1

        if spectateIndex > #spectatePlayers then
            spectateIndex = 1
        end

        spectateUpdateTarget()
    end

    -- Menggunakan tombol Next 7 sebagai tombol utama Spectate Player.
    -- Tidak membuat tombol Spectate Player tambahan.
    next7Button.Text = "👁️ Spectate Player"
    next7Button.Name = "SpectatePlayerButton"

    -- Panel spectator berada di tengah bawah layar.
    spectatePanel = Instance.new("Frame")
    spectatePanel.Name = "SpectatePlayerPanel"
    spectatePanel.Size = UDim2.fromOffset(300, 58)
    spectatePanel.AnchorPoint = Vector2.new(0.5, 1)
    spectatePanel.Position = UDim2.new(0.5, 0, 1, -22)
    spectatePanel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    spectatePanel.BorderSizePixel = 0
    spectatePanel.Visible = false
    spectatePanel.ZIndex = 50
    spectatePanel.Parent = gui

    Instance.new("UICorner", spectatePanel).CornerRadius = UDim.new(0, 10)

    local panelPadding = Instance.new("UIPadding")
    panelPadding.PaddingLeft = UDim.new(0, 7)
    panelPadding.PaddingRight = UDim.new(0, 7)
    panelPadding.PaddingTop = UDim.new(0, 7)
    panelPadding.PaddingBottom = UDim.new(0, 7)
    panelPadding.Parent = spectatePanel

    local panelLayout = Instance.new("UIListLayout")
    panelLayout.FillDirection = Enum.FillDirection.Horizontal
    panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    panelLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    panelLayout.Padding = UDim.new(0, 6)
    panelLayout.Parent = spectatePanel

    spectatePrevButton = Instance.new("TextButton")
    spectatePrevButton.Name = "Previous"
    spectatePrevButton.Size = UDim2.fromOffset(48, 42)
    spectatePrevButton.BackgroundColor3 = BUTTON_DEFAULT_COLOR
    spectatePrevButton.TextColor3 = Color3.new(1, 1, 1)
    spectatePrevButton.Text = "◀"
    spectatePrevButton.TextSize = 18
    spectatePrevButton.Font = Enum.Font.GothamBold
    spectatePrevButton.ZIndex = 51
    spectatePrevButton.Parent = spectatePanel
    Instance.new("UICorner", spectatePrevButton).CornerRadius = UDim.new(0, 7)

    spectateNameLabel = Instance.new("TextLabel")
    spectateNameLabel.Name = "Nickname"
    spectateNameLabel.Size = UDim2.fromOffset(170, 42)
    spectateNameLabel.BackgroundColor3 = BUTTON_DEFAULT_COLOR
    spectateNameLabel.TextColor3 = Color3.new(1, 1, 1)
    spectateNameLabel.Text = "Pilih Player"
    spectateNameLabel.TextSize = 13
    spectateNameLabel.Font = Enum.Font.GothamBold
    spectateNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    spectateNameLabel.ZIndex = 51
    spectateNameLabel.Parent = spectatePanel
    Instance.new("UICorner", spectateNameLabel).CornerRadius = UDim.new(0, 7)

    spectateNextButton = Instance.new("TextButton")
    spectateNextButton.Name = "Next"
    spectateNextButton.Size = UDim2.fromOffset(48, 42)
    spectateNextButton.BackgroundColor3 = BUTTON_DEFAULT_COLOR
    spectateNextButton.TextColor3 = Color3.new(1, 1, 1)
    spectateNextButton.Text = "▶"
    spectateNextButton.TextSize = 18
    spectateNextButton.Font = Enum.Font.GothamBold
    spectateNextButton.ZIndex = 51
    spectateNextButton.Parent = spectatePanel
    Instance.new("UICorner", spectateNextButton).CornerRadius = UDim.new(0, 7)

    spectateStopButton = Instance.new("TextButton")
    spectateStopButton.Name = "Stop"
    spectateStopButton.Size = UDim2.fromOffset(100, 35)
    spectateStopButton.Position = UDim2.new(0.5, -59, 1, -85)
    spectateStopButton.AnchorPoint = Vector2.new(0.5, 1)
    spectateStopButton.BackgroundColor3 = Color3.fromRGB(150, 45, 45)
    spectateStopButton.TextColor3 = Color3.new(1, 1, 1)
    spectateStopButton.Text = "Stop Spectate"
    spectateStopButton.TextSize = 12
    spectateStopButton.Font = Enum.Font.GothamBold
    spectateStopButton.Visible = false
    spectateStopButton.ZIndex = 50
    spectateStopButton.Parent = gui
    Instance.new("UICorner", spectateStopButton).CornerRadius = UDim.new(0, 7)

    spectateAutoTeleportButton = Instance.new("TextButton")
    spectateAutoTeleportButton.Name = "AutoTeleport"
    spectateAutoTeleportButton.Size = UDim2.fromOffset(112, 35)
    spectateAutoTeleportButton.Position = UDim2.new(0.5, 59, 1, -85)
    spectateAutoTeleportButton.AnchorPoint = Vector2.new(0.5, 1)
    spectateAutoTeleportButton.BackgroundColor3 = BUTTON_DEFAULT_COLOR
    spectateAutoTeleportButton.TextColor3 = Color3.new(1, 1, 1)
    spectateAutoTeleportButton.Text = "Auto Teleport: OFF"
    spectateAutoTeleportButton.TextSize = 11
    spectateAutoTeleportButton.Font = Enum.Font.GothamBold
    spectateAutoTeleportButton.Visible = false
    spectateAutoTeleportButton.ZIndex = 50
    spectateAutoTeleportButton.Parent = gui
    Instance.new("UICorner", spectateAutoTeleportButton).CornerRadius = UDim.new(0, 7)

    next7Button.MouseButton1Click:Connect(function()
        if spectateEnabled then
            spectateStop()
            spectateStopButton.Visible = false
            setButtonState(next7Button, false)
        else
            -- FreeCam tetap memiliki prioritas.
            if freeCamEnabled then
                return
            end

            spectateStart()
            spectateStopButton.Visible = spectateEnabled
            spectateAutoTeleportButton.Visible = spectateEnabled
            setButtonState(next7Button, spectateEnabled)
        end
    end)

    spectatePrevButton.MouseButton1Click:Connect(spectatePrevious)
    spectateNextButton.MouseButton1Click:Connect(spectateNext)

    spectateStopButton.MouseButton1Click:Connect(function()
        spectateStop()
        spectateStopButton.Visible = false
        spectateAutoTeleportButton.Visible = false
        setButtonState(next7Button, false)
    end)

    spectateAutoTeleportButton.MouseButton1Click:Connect(function()
        if not spectateEnabled then
            return
        end

        setAutoTeleportEnabled(not autoTeleportEnabled)
    end)
end

--==================================================

--==================================================
-- FREE CAM - NEXT 3
--==================================================

local next3Button = makeButton("🎥 Free Cam: OFF")
next3Button.Name = "FreeCamMainButton"

next3Button.MouseButton1Click:Connect(function()
    local newState = not freeCamEnabled
    freeCamSetEnabled(newState)

    -- Selalu sinkronkan tampilan tombol utama dengan status Free Cam.
    next3Button.Text = newState
        and "🎥 Free Cam: ON"
        or "🎥 Free Cam: OFF"

    setButtonState(next3Button, newState)
end)

--==================================================

--==================================================
-- NEXT 10 / 11 / 12 - EXTRA CONTROLS
--==================================================

-- NEXT 10: SIT TOGGLE
local next10Button = makeButton("🪑 Sit: OFF")
local next10Enabled = false

next10Button.MouseButton1Click:Connect(function()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if not humanoid or humanoid.Health <= 0 then
        next10Enabled = false
        next10Button.Text = "🪑 Sit: OFF"
        setButtonState(next10Button, false)
        return
    end

    next10Enabled = not next10Enabled
    humanoid.Sit = next10Enabled

    next10Button.Text = next10Enabled
        and "🪑 Sit: ON"
        or "🪑 Sit: OFF"

    setButtonState(next10Button, next10Enabled)
end)

-- NEXT 11: FOV ZOOM
local next11Button = makeButton("🔭 FOV Zoom: OFF")
local next11Enabled = false
local next11DefaultFOV = 70
local next11ZoomFOV = 45

local function next11ApplyFOV()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    if next11Enabled then
        camera.FieldOfView = next11ZoomFOV
    else
        camera.FieldOfView = next11DefaultFOV
    end
end

next11Button.MouseButton1Click:Connect(function()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    if not next11Enabled then
        -- Simpan FOV normal saat pertama kali diaktifkan.
        next11DefaultFOV = camera.FieldOfView
        next11Enabled = true
        camera.FieldOfView = next11ZoomFOV
    else
        next11Enabled = false
        camera.FieldOfView = next11DefaultFOV
    end

    next11Button.Text = next11Enabled
        and "🔭 FOV Zoom: ON"
        or "🔭 FOV Zoom: OFF"

    setButtonState(next11Button, next11Enabled)
end)

-- NEXT 12: CAMERA RESET
local next12Button = makeButton("☀️ Full Bright: OFF")
local next12Enabled = false

next12Button.MouseButton1Click:Connect(function()
    next12Enabled = not next12Enabled

    local Lighting = game:GetService("Lighting")

    if next12Enabled then
        Lighting.Brightness = 3
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)

        next12Button.Text = "☀️ Full Bright: ON"
    else
        Lighting.Brightness = 1
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = true
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)

        next12Button.Text = "☀️ Full Bright: OFF"
    end

    setButtonState(next12Button, next12Enabled)
end)

-- Reset state tombol tambahan setelah respawn.
player.CharacterAdded:Connect(function()
    next10Enabled = false
    next10Button.Text = "🪑 Sit: OFF"
    setButtonState(next10Button, false)

    next11Enabled = false
    next11Button.Text = "🔭 FOV Zoom: OFF"
    setButtonState(next11Button, false)
end)

--==================================================
-- CUSTOM TP - COORDINATES
--==================================================
-- Format yang diterima:
-- 111,11,11
-- x111,y11,z11
-- x=111,y=11,z=11
local customTpFrame = Instance.new("Frame")
customTpFrame.Name = "CustomTeleport"
customTpFrame.Size = UDim2.new(1, 0, 0, 35)
customTpFrame.BackgroundTransparency = 1

-- Masuk ke content yang memakai UIListLayout supaya posisi
-- benar-benar berada setelah tombol Free Cam dan sebelum Boombox.
buttonOrder += 1
customTpFrame.LayoutOrder = buttonOrder
customTpFrame.Parent = content

customTpBox = Instance.new("TextBox")
customTpBox.Name = "CoordinateBox"
customTpBox.Size = UDim2.new(1, -62, 0, 35)
customTpBox.Position = UDim2.fromOffset(0, 1)
customTpBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
customTpBox.TextColor3 = Color3.new(1, 1, 1)
customTpBox.PlaceholderColor3 = Color3.fromRGB(170, 170, 170)
customTpBox.PlaceholderText = "Custom Tp"
customTpBox.Text = ""
customTpBox.TextSize = 13
customTpBox.Font = Enum.Font.Gotham
customTpBox.ClearTextOnFocus = false
customTpBox.ZIndex = 10
customTpBox.Parent = customTpFrame

local customTpCorner = Instance.new("UICorner")
customTpCorner.CornerRadius = UDim.new(0, 6)
customTpCorner.Parent = customTpBox

local customTpGoButton = Instance.new("TextButton")
customTpGoButton.Name = "GoButton"
customTpGoButton.Size = UDim2.new(0, 56, 0, 35)
customTpGoButton.Position = UDim2.new(1, -56, 0, 1)
customTpGoButton.BackgroundColor3 = BUTTON_DEFAULT_COLOR
customTpGoButton.TextColor3 = Color3.new(1, 1, 1)
customTpGoButton.Text = "Go"
customTpGoButton.TextSize = 13
customTpGoButton.Font = Enum.Font.GothamBold
customTpGoButton.ZIndex = 10
customTpGoButton.Parent = customTpFrame

local customTpGoCorner = Instance.new("UICorner")
customTpGoCorner.CornerRadius = UDim.new(0, 6)
customTpGoCorner.Parent = customTpGoButton

local function parseCustomCoordinates(input)
    -- Buang spasi dan ubah huruf menjadi lowercase.
    input = tostring(input or ""):lower():gsub("%s+", "")

    -- Mendukung:
    -- 111,11,11
    -- x111,y11,z11
    -- x=111,y=11,z=11
    local x, y, z

    if input:match("^x") or input:match("^[xyz]=") then
        x = input:match("^x=?([%+%-]?[%d%.]+)")
        y = input:match("[,;]y=?([%+%-]?[%d%.]+)")
        z = input:match("[,;]z=?([%+%-]?[%d%.]+)")
    else
        local values = {}
        for value in input:gmatch("[%+%-]?[%d%.]+") do
            table.insert(values, value)
        end

        if #values == 3 then
            x, y, z = values[1], values[2], values[3]
        end
    end

    x, y, z = tonumber(x), tonumber(y), tonumber(z)

    if not x or not y or not z then
        return nil
    end

    return Vector3.new(x, y, z)
end

-- Dibungkus do-block agar tidak menambah variabel local tingkat atas
-- (batas Lua = 200 local per fungsi).
do
-- Teleport karakter ke sebuah posisi. Dipakai tombol Go utama (Custom TP)
-- dan tombol Go milik Free Cam.
local function zaqiTeleportCharacterTo(targetCFrame)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    -- Free Cam mengunci (Anchored) karakter secara lokal. Part yang Anchored
    -- tidak direplikasi ke server, jadi lepas dulu saat teleport lalu kunci lagi.
    local wasLockedByFreeCam = freeCamEnabled and freeCamLockedRoot == root
    if wasLockedByFreeCam and freeCamCoordGui then
        freeCamCoordGui:SetAttribute("Teleporting", true)
    end

    root.Anchored = false
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    character:PivotTo(targetCFrame)

    if wasLockedByFreeCam then
        task.delay(0.35, function()
            if freeCamCoordGui then
                freeCamCoordGui:SetAttribute("Teleporting", nil)
            end
            if freeCamEnabled and root.Parent then
                root.AssemblyLinearVelocity = Vector3.zero
                root.Anchored = true
            end
        end)
    end

    return true
end

-- GO di Free Cam: teleport ke koordinat kamera SAAT INI (tanpa lewat kolom teks).
freeCamCustomTeleportToCoordinates = function()
    local camera = workspace.CurrentCamera
    local camPos = freeCamPosition or (camera and camera.CFrame.Position)

    if not camPos then return end

    -- Hadapkan karakter ke arah yang sedang dilihat kamera.
    local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
    local flat = Vector3.new(look.X, 0, look.Z)
    local target
    if flat.Magnitude > 0.001 then
        target = CFrame.lookAt(camPos, camPos + flat.Unit)
    else
        target = CFrame.new(camPos)
    end

    if not zaqiTeleportCharacterTo(target) then
        if customTpBox then
            customTpBox.PlaceholderText = "Character belum siap"
            task.delay(1.5, function()
                if customTpBox and customTpBox.Parent then
                    customTpBox.PlaceholderText = "Custom Tp"
                end
            end)
        end
    end
end

-- GO utama: teleport ke koordinat yang diketik di kolom Custom TP.
local function customTeleportToCoordinates()
    local position = parseCustomCoordinates(customTpBox.Text)

    if not position then
        customTpBox.Text = ""
        customTpBox.PlaceholderText = "Format: 111,11,11"
        task.delay(1.8, function()
            if customTpBox and customTpBox.Parent then
                customTpBox.PlaceholderText = "Custom Tp"
            end
        end)
        return
    end

    if not zaqiTeleportCharacterTo(CFrame.new(position)) then
        customTpBox.PlaceholderText = "Character belum siap"
        task.delay(1.5, function()
            if customTpBox and customTpBox.Parent then
                customTpBox.PlaceholderText = "Custom Tp"
            end
        end)
        return
    end

    customTpBox.Text = ""
end

customTpGoButton.MouseButton1Click:Connect(customTeleportToCoordinates)

customTpBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        customTeleportToCoordinates()
    end
end)
end

--==================================================
-- BOOMBOX - NEXT 4
--==================================================
-- Boombox dibuat sebagai halaman terpisah.
-- Saat halaman Boombox dibuka, menu utama disembunyikan.
-- Sound diputar secara lokal pada client, sehingga tidak mengubah
-- sistem musik server/game. Audio tetap tunduk pada izin Roblox.

local boomboxButton = makeButton("🎵 Musik") -- dipindah ke Tools

local boomboxPage = Instance.new("ScrollingFrame")
boomboxPage.Name = "ZaqiBoomboxPage"
boomboxPage.Size = UDim2.new(1,-20,1,-55)
boomboxPage.Position = UDim2.fromOffset(10,45)
boomboxPage.BackgroundColor3 = Color3.fromRGB(35,35,35)
boomboxPage.BorderSizePixel = 0
boomboxPage.Visible = false
boomboxPage.ZIndex = 20
boomboxPage.CanvasSize = UDim2.new(0,0,0,585)
boomboxPage.ScrollBarThickness = 5
boomboxPage.ScrollingDirection = Enum.ScrollingDirection.Y
boomboxPage.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
boomboxPage.Parent = menu

Instance.new("UICorner",boomboxPage).CornerRadius = UDim.new(0,8)

-- Seluruh isi halaman Boombox dibungkus fungsi sendiri supaya puluhan
-- variabel local-nya tidak menghabiskan jatah 200 local di tingkat atas.
-- Hanya boomboxBackButton yang dipakai di luar, jadi dideklarasikan di sini.
local boomboxBackButton

;(function()
local boomboxTitle = Instance.new("TextLabel")
boomboxTitle.Size = UDim2.new(1,-20,0,34)
boomboxTitle.Position = UDim2.fromOffset(10,8)
boomboxTitle.BackgroundTransparency = 1
boomboxTitle.Text = "🎵 MUSIK"
boomboxTitle.TextColor3 = Color3.new(1,1,1)
boomboxTitle.TextSize = 16
boomboxTitle.Font = Enum.Font.GothamBold
boomboxTitle.ZIndex = 21
boomboxTitle.Parent = boomboxPage

local boomboxSound = Instance.new("Sound")
boomboxSound.Name = "ZaqiBoomboxSound"
boomboxSound.Volume = 0.5
boomboxSound.Looped = false
boomboxSound.Parent = workspace

local boomboxPlaylist = {
    "127882927724797", -- Curi Curi Pandang
    "130103433457465", -- OBH Batuk Berdahak
    "79902843921518",  -- Selamat Tinggal
    "82127918956839",  -- Surat Cinta Untuk Starla
    "122084395776372", -- Sesi Potret
    "140175591559306", -- Harry Styles - As It Was
    "82746224492420",  -- Dam Dam Di Di Di Di
    "74428516454430",  -- Fireflies
    "74585504240155",  -- Evanescence
    "1846853445",       -- Tambahan 1
    "9043216005",       -- Tambahan 2
    "9048645169",       -- Tambahan 3
    "9048644488",       -- Tambahan 4

    "110919391228823", -- low cortisol
    "136298946425465", -- kicau mania dj
    "773106418",       -- armada asal kau bahagia
    "93798530650478",  -- cupid
    "5622599744",      -- BLACKPINK - ICE CREAM (ft.Selena Gomez) full
    "5622515984",      -- [FULL] Ice cream - BLACKPINK Ft. Selena Gomez
    "1192919342",      -- Selena Gomez & Marshmello - Wolves (Live at AMA's)
    "1677664675",      -- Kygo & Selena Gomez - It Ain't Me (Codeko Remix)
    "717267820",       -- KYLE - iSpy ft. Lil Yachty
    "2698148141",      -- Hey Julie - KYLE ft Lil Yachty
    "5155785611",      -- Marikit - Juan, Kyle
    "220147025",       -- KYLE - Don't Wanna Fall in Love
    "697292735",       -- KYLE - ISPY (Instrumental)
    "610345103",       -- KYLE - Doubt It
    "2813415453",      -- gianni & kyle - do u even miss me at all?
    "601899512",       -- KYLE - Doubt It
    "908730003",       -- Heathers - Seventeen
    "5083780513",      -- Stevie Nxicks - Edge of Seventeen
    "3905941170",      -- SEVENTEEN - FEAR (KPOP)
    "6609559561",      -- Seventeen - Left & Right
    "501006456",       -- Seventeen Nice (Very Nice)
    "2757167819",      -- SEVENTEEN (Getting Closer)
    "7801214841",      -- rock with you | seventeen
    "3612667699",      -- Seventeen - Hit
}
local boomboxSongNames = {
    ["127882927724797"] = "Curi Curi Pandang",
    ["130103433457465"] = "OBH Batuk Berdahak",
    ["79902843921518"] = "Selamat Tinggal",
    ["82127918956839"] = "Surat Cinta Untuk Starla",
    ["122084395776372"] = "Sesi Potret",
    ["140175591559306"] = "Harry Styles - As It Was",
    ["82746224492420"] = "Dam Dam Di Di Di Di",
    ["74428516454430"] = "Fireflies",
    ["74585504240155"] = "Evanescence",
    ["1846853445"] = "Sound 1846853445",
    ["9043216005"] = "Sound 9043216005",
    ["9048645169"] = "Sound 9048645169",
    ["9048644488"] = "Sound 9048644488",

    ["110919391228823"] = "low cortisol",
    ["136298946425465"] = "kicau mania dj",
    ["773106418"] = "armada asal kau bahagia",
    ["93798530650478"] = "cupid",
    ["5622599744"] = "BLACKPINK - ICE CREAM (ft.Selena Gomez) full",
    ["5622515984"] = "[FULL] Ice cream - BLACKPINK Ft. Selena Gomez",
    ["1192919342"] = "Selena Gomez & Marshmello - Wolves (Live at AMA's)",
    ["1677664675"] = "Kygo & Selena Gomez - It Ain't Me (Codeko Remix)",
    ["717267820"] = "KYLE - iSpy ft. Lil Yachty",
    ["2698148141"] = "Hey Julie - KYLE ft Lil Yachty",
    ["5155785611"] = "Marikit - Juan, Kyle",
    ["220147025"] = "KYLE - Don't Wanna Fall in Love",
    ["697292735"] = "KYLE - ISPY (Instrumental)",
    ["610345103"] = "KYLE - Doubt It",
    ["2813415453"] = "gianni & kyle - do u even miss me at all?",
    ["601899512"] = "KYLE - Doubt It",
    ["908730003"] = "Heathers - Seventeen",
    ["5083780513"] = "Stevie Nxicks - Edge of Seventeen",
    ["3905941170"] = "SEVENTEEN - FEAR (KPOP)",
    ["6609559561"] = "Seventeen - Left & Right",
    ["501006456"] = "Seventeen Nice (Very Nice)",
    ["2757167819"] = "SEVENTEEN (Getting Closer)",
    ["7801214841"] = "rock with you | seventeen",
    ["3612667699"] = "Seventeen - Hit",
}
local boomboxIndex = 0
local boomboxShuffle = false
local boomboxRepeat = false
local boomboxMuted = false
local boomboxVolume = 0.5
local boomboxPreviousVolume = 0.5

local function boomboxMakeButton(text, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-20,0,34)
    b.Position = UDim2.fromOffset(10,y)
    b.BackgroundColor3 = BUTTON_DEFAULT_COLOR
    b.TextColor3 = Color3.new(1,1,1)
    b.Text = text
    b.TextSize = 13
    b.Font = Enum.Font.Gotham
    b.ZIndex = 21
    b.Parent = boomboxPage
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
    return b
end

local soundIdBox = Instance.new("TextBox")
soundIdBox.Size = UDim2.new(1,-20,0,34)
soundIdBox.Position = UDim2.fromOffset(10,48)
soundIdBox.BackgroundColor3 = Color3.fromRGB(50,50,50)
soundIdBox.TextColor3 = Color3.new(1,1,1)
soundIdBox.PlaceholderColor3 = Color3.fromRGB(170,170,170)
soundIdBox.PlaceholderText = "Masukkan Sound ID..."
soundIdBox.Text = ""
soundIdBox.TextSize = 13
soundIdBox.Font = Enum.Font.Gotham
soundIdBox.ClearTextOnFocus = false
soundIdBox.ZIndex = 21
soundIdBox.Parent = boomboxPage
Instance.new("UICorner",soundIdBox).CornerRadius = UDim.new(0,6)

local addSongButton = boomboxMakeButton("➕ Tambah Lagu",88)

local boomboxStatusLabel = Instance.new("TextLabel")
boomboxStatusLabel.Size = UDim2.new(1,-20,0,26)
boomboxStatusLabel.Position = UDim2.fromOffset(10,160)
boomboxStatusLabel.BackgroundTransparency = 1
boomboxStatusLabel.Text = "🟡 Status: Menunggu"
boomboxStatusLabel.TextColor3 = Color3.fromRGB(220,220,220)
boomboxStatusLabel.TextSize = 11
boomboxStatusLabel.Font = Enum.Font.Gotham
boomboxStatusLabel.ZIndex = 21
boomboxStatusLabel.Parent = boomboxPage

local nowPlayingLabel = Instance.new("TextLabel")
nowPlayingLabel.Size = UDim2.new(1,-20,0,30)
nowPlayingLabel.Position = UDim2.fromOffset(10,129)
nowPlayingLabel.BackgroundTransparency = 1
nowPlayingLabel.Text = "🎶 Belum ada lagu"
nowPlayingLabel.TextColor3 = Color3.fromRGB(220,220,220)
nowPlayingLabel.TextSize = 12
nowPlayingLabel.Font = Enum.Font.Gotham
nowPlayingLabel.ZIndex = 21
nowPlayingLabel.Parent = boomboxPage

local playPauseButton = boomboxMakeButton("▶️ Play",190)
local previousButton = boomboxMakeButton("⏮️ Previous",231)
local nextSongButton = boomboxMakeButton("⏭️ Next",272)
local volumeButton = boomboxMakeButton("🔊 Volume: 50%",313)
local muteButton = boomboxMakeButton("🔇 Mute: OFF",354)
local shuffleButton = boomboxMakeButton("🔀 Shuffle: OFF",395)
local repeatButton = boomboxMakeButton("🔁 Repeat: OFF",436)
local stopMusicButton = boomboxMakeButton("🛑 Stop Music",477)
boomboxBackButton = boomboxMakeButton("↩️ Back",518)

-- Ruang bawah agar tombol terakhir dapat digeser sepenuhnya ke atas.
local boomboxBottomPadding = Instance.new("Frame")
boomboxBottomPadding.Name = "BottomPadding"
boomboxBottomPadding.Size = UDim2.new(1,0,0,20)
boomboxBottomPadding.Position = UDim2.fromOffset(0,558)
boomboxBottomPadding.BackgroundTransparency = 1
boomboxBottomPadding.BorderSizePixel = 0
boomboxBottomPadding.ZIndex = 20
boomboxBottomPadding.Parent = boomboxPage

;(function()
-- Catatan: status internal disimpan sebagai Attribute pada boomboxSound
-- (ZaqiToken, ZaqiStopped) agar tidak menambah variabel local baru
-- (script ini sudah mendekati batas 200 local milik Lua).
boomboxSound:SetAttribute("ZaqiToken",0)
boomboxSound:SetAttribute("ZaqiStopped",false)

local function boomboxSetVolume()
    if boomboxMuted then
        boomboxSound.Volume = 0
    else
        boomboxSound.Volume = boomboxVolume
    end
end

local function boomboxUpdateNowPlaying()
    if boomboxIndex > 0 and boomboxPlaylist[boomboxIndex] then
        nowPlayingLabel.Text = string.format(
            "🎶 Lagu %d/%d • %s",
            boomboxIndex,
            #boomboxPlaylist,
            boomboxSongNames[boomboxPlaylist[boomboxIndex]] or boomboxPlaylist[boomboxIndex]
        )
    else
        nowPlayingLabel.Text = "🎶 Belum ada lagu"
    end
end

-- step: arah lompat jika lagu gagal dimuat (1 = maju, -1 = mundur).
-- attempts: jumlah lagu yang sudah dicoba (mencegah loop tanpa akhir).
local function boomboxPlayIndex(index, attempts, step)
    attempts = attempts or 0
    step = step or 1

    if #boomboxPlaylist == 0 then
        nowPlayingLabel.Text = "🎶 Tambahkan Sound ID terlebih dahulu"
        boomboxStatusLabel.Text = "🟡 Status: Playlist kosong"
        return false
    end

    if attempts >= #boomboxPlaylist then
        boomboxSound:Stop()
        playPauseButton.Text = "▶️ Play"
        boomboxStatusLabel.Text = "🔴 Status: Semua lagu tidak tersedia"
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification",{
                Title = "🔴 Musik",
                Text = "Semua lagu di playlist tidak bisa diputar.",
                Duration = 6,
            })
        end)
        return false
    end

    if index < 1 then
        index = #boomboxPlaylist
    elseif index > #boomboxPlaylist then
        index = 1
    end

    -- Token: jika tombol ditekan lagi saat memuat, proses lama dibatalkan.
    local token = (boomboxSound:GetAttribute("ZaqiToken") or 0) + 1
    boomboxSound:SetAttribute("ZaqiToken",token)
    boomboxSound:SetAttribute("ZaqiStopped",false)

    boomboxIndex = index
    local soundId = boomboxPlaylist[boomboxIndex]

    boomboxUpdateNowPlaying()
    boomboxStatusLabel.Text = "🟡 Status: Memuat..."
    playPauseButton.Text = "▶️ Play"

    boomboxSound:Stop()
    boomboxSound.SoundId = "rbxassetid://" .. soundId
    boomboxSound.Looped = boomboxRepeat
    boomboxSetVolume()

    -- Tunggu sampai ter-load (maks 8 detik). Tidak memakai Loaded:Wait()
    -- karena event itu tidak pernah menyala jika lagu sudah ter-load
    -- (mis. Repeat / lagu sama) atau jika lagu gagal dimuat.
    local startTime = os.clock()
    while not boomboxSound.IsLoaded
        and os.clock() - startTime < 8
        and boomboxSound:GetAttribute("ZaqiToken") == token do
        task.wait(0.1)
    end

    -- Dibatalkan oleh aksi lain (tombol lain / Stop).
    if boomboxSound:GetAttribute("ZaqiToken") ~= token then
        return false
    end

    if boomboxSound.IsLoaded then
        boomboxSound.TimePosition = 0
        local played = pcall(function()
            boomboxSound:Play()
        end)

        if played then
            playPauseButton.Text = "⏸️ Pause"
            boomboxStatusLabel.Text = "🟢 Status: Ready • Sedang diputar"
            return true
        end
    end

    boomboxStatusLabel.Text = "🔴 Status: Tidak tersedia • Melewati lagu..."

    -- Notifikasi: lagu rusak / tidak bisa dimuat.
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",{
            Title = "⚠️ Lagu rusak",
            Text = string.format(
                "Lagu %d (%s) tidak bisa diputar, dilewati.",
                boomboxIndex,
                boomboxSongNames[soundId] or soundId
            ),
            Duration = 5,
        })
    end)

    task.wait(0.25)

    if boomboxSound:GetAttribute("ZaqiToken") ~= token then
        return false
    end

    return boomboxPlayIndex(boomboxIndex + step, attempts + 1, step)
end

local function boomboxNextIndex()
    if boomboxShuffle and #boomboxPlaylist > 1 then
        local newIndex = boomboxIndex
        repeat
            newIndex = math.random(1,#boomboxPlaylist)
        until newIndex ~= boomboxIndex
        return newIndex
    end
    return boomboxIndex + 1
end

local function boomboxRefreshVolumeLabels()
    volumeButton.Text = "🔊 Volume: " .. math.floor(boomboxVolume * 100 + 0.5) .. "%"
    muteButton.Text = boomboxMuted and "🔇 Mute: ON" or "🔇 Mute: OFF"
    setButtonState(muteButton,boomboxMuted)
end

addSongButton.MouseButton1Click:Connect(function()
    local raw = tostring(soundIdBox.Text or "")
    local id = raw:match("%d+")

    if not id then
        nowPlayingLabel.Text = "⚠️ Sound ID tidak valid"
        return
    end

    table.insert(boomboxPlaylist,id)
    soundIdBox.Text = ""

    -- Langsung diputar agar terlihat apakah ID tersebut valid.
    boomboxPlayIndex(#boomboxPlaylist)
end)

playPauseButton.MouseButton1Click:Connect(function()
    if boomboxSound.IsPlaying then
        boomboxSound:Pause()
        playPauseButton.Text = "▶️ Play"
        boomboxStatusLabel.Text = "🟡 Status: Dijeda"
        return
    end

    if #boomboxPlaylist == 0 then
        nowPlayingLabel.Text = "🎶 Tambahkan Sound ID terlebih dahulu"
        return
    end

    -- Belum ada lagu, atau lagu belum ter-load / habis: muat dari awal.
    if boomboxIndex < 1
        or boomboxSound.SoundId == ""
        or not boomboxSound.IsLoaded then
        boomboxPlayIndex(boomboxIndex > 0 and boomboxIndex or 1)
    else
        boomboxSound:SetAttribute("ZaqiStopped",false)
        boomboxSetVolume()
        boomboxSound:Resume()
        if not boomboxSound.IsPlaying then
            boomboxSound:Play()
        end
        playPauseButton.Text = "⏸️ Pause"
        boomboxStatusLabel.Text = "🟢 Status: Ready • Sedang diputar"
    end
end)

previousButton.MouseButton1Click:Connect(function()
    if #boomboxPlaylist == 0 then return end
    boomboxPlayIndex((boomboxIndex > 0 and boomboxIndex or 1) - 1, 0, -1)
end)

nextSongButton.MouseButton1Click:Connect(function()
    if #boomboxPlaylist == 0 then return end
    boomboxPlayIndex(boomboxNextIndex())
end)

volumeButton.MouseButton1Click:Connect(function()
    local levels = {0,0.25,0.5,0.75,1}
    local current = 1

    for i,v in ipairs(levels) do
        if math.abs(v - boomboxVolume) < 0.01 then
            current = i
            break
        end
    end

    current += 1
    if current > #levels then current = 1 end

    boomboxVolume = levels[current]
    if boomboxVolume > 0 then
        boomboxPreviousVolume = boomboxVolume
    end

    -- Mengubah volume otomatis membatalkan Mute.
    boomboxMuted = false

    boomboxSetVolume()
    boomboxRefreshVolumeLabels()
end)

muteButton.MouseButton1Click:Connect(function()
    boomboxMuted = not boomboxMuted

    if boomboxMuted then
        if boomboxVolume > 0 then
            boomboxPreviousVolume = boomboxVolume
        end
    else
        if boomboxVolume <= 0 then
            boomboxVolume = boomboxPreviousVolume > 0 and boomboxPreviousVolume or 0.5
        end
    end

    boomboxSetVolume()
    boomboxRefreshVolumeLabels()
end)

shuffleButton.MouseButton1Click:Connect(function()
    boomboxShuffle = not boomboxShuffle
    shuffleButton.Text = boomboxShuffle and "🔀 Shuffle: ON" or "🔀 Shuffle: OFF"
    setButtonState(shuffleButton,boomboxShuffle)
end)

repeatButton.MouseButton1Click:Connect(function()
    boomboxRepeat = not boomboxRepeat
    repeatButton.Text = boomboxRepeat and "🔁 Repeat: ON" or "🔁 Repeat: OFF"
    setButtonState(repeatButton,boomboxRepeat)

    -- Repeat = ulangi lagu yang sedang diputar (Looped bawaan Roblox).
    boomboxSound.Looped = boomboxRepeat
end)

stopMusicButton.MouseButton1Click:Connect(function()
    -- Batalkan proses memuat yang masih berjalan, lalu hentikan.
    boomboxSound:SetAttribute("ZaqiToken",(boomboxSound:GetAttribute("ZaqiToken") or 0) + 1)
    boomboxSound:SetAttribute("ZaqiStopped",true)
    boomboxSound:Stop()
    playPauseButton.Text = "▶️ Play"
    boomboxStatusLabel.Text = "⚪ Status: Stopped"
end)

boomboxSound.Ended:Connect(function()
    -- Abaikan jika berhenti karena tombol Stop.
    if boomboxSound:GetAttribute("ZaqiStopped") then
        return
    end

    if #boomboxPlaylist == 0 then
        playPauseButton.Text = "▶️ Play"
        return
    end

    if boomboxRepeat then
        boomboxPlayIndex(boomboxIndex > 0 and boomboxIndex or 1)
    elseif boomboxShuffle and #boomboxPlaylist > 1 then
        boomboxPlayIndex(boomboxNextIndex())
    else
        if boomboxIndex < #boomboxPlaylist then
            boomboxPlayIndex(boomboxIndex + 1)
        else
            boomboxSound:Stop()
            playPauseButton.Text = "▶️ Play"
            boomboxStatusLabel.Text = "⚪ Status: Playlist selesai"
        end
    end
end)

end)()

end)()

-- Tombol Musik & tombol Back-nya sekarang ditangani di dalam halaman Tools
-- (lihat bagian TOOLS): Tools -> Musik, Back kembali ke Tools.

--==================================================
-- PARTICLE AURA
--==================================================
-- Aura partikel lokal (client-only) yang menempel pada karakter.
-- Halaman terpisah seperti Boombox: tombol di menu utama membuka
-- halaman pengaturan (ON/OFF, efek, warna, ukuran, intensitas, kecepatan).
-- Seluruh logika dibungkus fungsi sendiri agar tidak memakan jatah
-- variabel local di tingkat atas script (hanya tombolnya yang di luar,
-- karena dipakai oleh daftar folder menu).

local particleAuraButton = makeButton("✨ Particle Aura: OFF")

;(function()
    local PA_NAME = "ZaqiParticleAura"
    local TEX_SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
    local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
    local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"

    -- HP (layar sentuh tanpa keyboard) memakai batas partikel lebih rendah.
    local isMobile = UserInputService.TouchEnabled
        and not UserInputService.KeyboardEnabled
    local MAX_PARTICLES = isMobile and 45 or 140

    local EFFECT_ORDER = {"Magic","Neon","Stars","Fire"}
    local EFFECT_LABELS = {
        Magic = "🔮 Magic",
        Neon = "💠 Neon",
        Stars = "⭐ Stars",
        Fire = "🔥 Fire",
    }

    -- life/speed = {min,max}; size dalam studs; tr = transparansi tengah.
    local EFFECTS = {
        Magic = {
            {tex = TEX_SPARKLE, c1 = Color3.fromRGB(190,100,255), c2 = Color3.fromRGB(80,200,255),
             rate = 12, life = {1.2,2.0}, speed = {0.5,2}, size = 0.55, tr = 0.1,
             light = 1, accel = Vector3.new(0,1.2,0), spread = 180, rot = true},
            {tex = TEX_SMOKE, c1 = Color3.fromRGB(150,80,255), c2 = Color3.fromRGB(60,40,160),
             rate = 3, life = {1.2,1.8}, speed = {0.2,0.8}, size = 2.2, tr = 0.75,
             light = 0.8, accel = Vector3.new(0,0.8,0), spread = 180, rot = false},
        },
        Neon = {
            {tex = TEX_SMOKE, c1 = Color3.fromRGB(0,255,230), c2 = Color3.fromRGB(255,0,200),
             rate = 10, life = {0.9,1.4}, speed = {0.5,1.5}, size = 1.0, tr = 0.45,
             light = 1, accel = Vector3.new(0,3,0), spread = 40, rot = false},
            {tex = TEX_SPARKLE, c1 = Color3.fromRGB(255,0,200), c2 = Color3.fromRGB(0,255,230),
             rate = 6, life = {0.8,1.2}, speed = {1,3}, size = 0.35, tr = 0,
             light = 1, accel = Vector3.new(0,2,0), spread = 60, rot = true},
        },
        Stars = {
            {tex = TEX_SPARKLE, c1 = Color3.fromRGB(255,240,150), c2 = Color3.fromRGB(255,190,40),
             rate = 8, life = {1.6,2.6}, speed = {0.3,1.2}, size = 0.9, tr = 0,
             light = 1, accel = Vector3.new(0,-0.5,0), spread = 180, rot = true},
        },
        Fire = {
            {tex = TEX_FIRE, c1 = Color3.fromRGB(255,210,60), c2 = Color3.fromRGB(255,50,0),
             rate = 16, life = {0.6,1.0}, speed = {1,3}, size = 1.6, tr = 0.15,
             light = 0.6, accel = Vector3.new(0,5,0), spread = 25, rot = false},
        },
    }

    local SIZE_LEVELS = {0.5,0.75,1,1.5,2,3}
    local INTENSITY_LEVELS = {10,25,50,75,100}   -- persen (50 = bawaan)
    local SPEED_LEVELS = {0.25,0.5,1,1.5,2,3}

    local SWATCHES = {
        Color3.fromRGB(255,60,60), Color3.fromRGB(255,150,0),
        Color3.fromRGB(255,230,0), Color3.fromRGB(0,230,100),
        Color3.fromRGB(0,200,255), Color3.fromRGB(60,100,255),
        Color3.fromRGB(180,80,255), Color3.fromRGB(255,255,255),
    }

    local state = {
        enabled = false,
        effect = "Magic",
        color = nil,         -- nil = warna bawaan tiap efek
        sizeIdx = 4,         -- ×1.5
        intensityIdx = 5,    -- 100%
        speedIdx = 3,
        token = 0,
        charConn = nil,      -- koneksi ChildAdded karakter
        playerConn = nil,    -- koneksi CharacterAdded
        pending = false,
    }

    --------------------------------------------------
    -- Membuat / membersihkan efek
    --------------------------------------------------
    local function clearAura()
        -- Sapu karakter sekarang (dan tidak hanya yang tercatat),
        -- sehingga partikel tidak pernah menumpuk.
        local character = player.Character
        if character then
            for _, object in ipairs(character:GetDescendants()) do
                if object:IsA("ParticleEmitter") and object.Name == PA_NAME then
                    object:Destroy()
                end
            end
        end
    end

    local function getAnchorPart(character)
        -- R6 & R15 sama-sama punya HumanoidRootPart.
        return character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
    end

    local function buildAura(character)
        clearAura()

        local anchor = character and getAnchorPart(character)
        local defs = EFFECTS[state.effect]
        if not anchor or not defs then return end

        local sizeMul = SIZE_LEVELS[state.sizeIdx]
        local intensityMul = INTENSITY_LEVELS[state.intensityIdx] / 50
        local speedMul = SPEED_LEVELS[state.speedIdx]

        -- Hitung perkiraan jumlah partikel agar tidak melebihi batas
        -- (penting untuk performa di HP).
        local rates = {}
        local estimate = 0
        for i, def in ipairs(defs) do
            local rate = def.rate * intensityMul
            local life = ((def.life[1] + def.life[2]) / 2) / speedMul
            rates[i] = rate
            estimate = estimate + rate * life
        end
        local scale = estimate > MAX_PARTICLES and (MAX_PARTICLES / estimate) or 1

        for i, def in ipairs(defs) do
            local c1, c2 = def.c1, def.c2
            if state.color then
                c1 = state.color:Lerp(Color3.new(1,1,1), 0.3)
                c2 = state.color
            end

            local emitter = Instance.new("ParticleEmitter")
            emitter.Name = PA_NAME
            emitter.Texture = def.tex
            emitter.Color = ColorSequence.new(c1, c2)
            emitter.LightEmission = def.light
            emitter.LightInfluence = 0
            emitter.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.25, def.size * sizeMul),
                NumberSequenceKeypoint.new(1, 0),
            })
            emitter.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.2, def.tr),
                NumberSequenceKeypoint.new(1, 1),
            })
            emitter.Lifetime = NumberRange.new(
                def.life[1] / speedMul,
                def.life[2] / speedMul
            )
            emitter.Speed = NumberRange.new(
                def.speed[1] * speedMul,
                def.speed[2] * speedMul
            )
            emitter.Rate = math.max(1, math.floor(rates[i] * scale + 0.5))
            emitter.SpreadAngle = Vector2.new(def.spread, def.spread)
            emitter.EmissionDirection = Enum.NormalId.Top
            emitter.Acceleration = def.accel
            emitter.Drag = 1
            emitter.LockedToPart = false
            emitter.Rotation = NumberRange.new(0, 360)
            emitter.RotSpeed = def.rot
                and NumberRange.new(-60 * speedMul, 60 * speedMul)
                or NumberRange.new(0, 0)

            -- Properti bentuk emisi tidak ada di semua versi; aman dengan pcall.
            pcall(function()
                emitter.Shape = Enum.ParticleEmitterShape.Cylinder
                emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
            end)

            emitter.Parent = anchor
        end
    end

    -- Karakter baru (respawn) / bagian tubuh diganti.
    local function setupCharacter(character)
        if state.charConn then
            state.charConn:Disconnect()
            state.charConn = nil
        end

        state.token += 1
        local myToken = state.token

        task.spawn(function()
            local anchor = character:WaitForChild("HumanoidRootPart", 10)
            if not state.enabled or myToken ~= state.token
                or not anchor or not anchor.Parent then
                return
            end

            pcall(buildAura, character)

            -- Jika HumanoidRootPart diganti oleh game, pasang ulang.
            state.charConn = character.ChildAdded:Connect(function(child)
                if state.enabled and child.Name == "HumanoidRootPart" then
                    task.defer(function()
                        if state.enabled and character.Parent then
                            pcall(buildAura, character)
                        end
                    end)
                end
            end)
        end)
    end

    local function stopAura()
        state.enabled = false
        state.token += 1

        if state.playerConn then
            state.playerConn:Disconnect()
            state.playerConn = nil
        end
        if state.charConn then
            state.charConn:Disconnect()
            state.charConn = nil
        end

        pcall(clearAura)
    end

    local function startAura()
        stopAura() -- pastikan tidak ada koneksi/efek lama (anti menumpuk)
        state.enabled = true

        state.playerConn = player.CharacterAdded:Connect(setupCharacter)

        if player.Character then
            setupCharacter(player.Character)
        end
    end

    -- Perubahan pengaturan: bangun ulang sekali per frame (digabung).
    local function refreshAura()
        if not state.enabled or state.pending then return end
        state.pending = true
        task.defer(function()
            state.pending = false
            if state.enabled and player.Character then
                pcall(buildAura, player.Character)
            end
        end)
    end

    --------------------------------------------------
    -- Halaman UI
    --------------------------------------------------
    local page = Instance.new("ScrollingFrame")
    page.Name = "ZaqiParticleAuraPage"
    page.Size = UDim2.new(1,-20,1,-55)
    page.Position = UDim2.fromOffset(10,45)
    page.BackgroundColor3 = Color3.fromRGB(35,35,35)
    page.BorderSizePixel = 0
    page.Visible = false
    page.ZIndex = 20
    page.CanvasSize = UDim2.new(0,0,0,0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 5
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
    page.Parent = menu
    Instance.new("UICorner",page).CornerRadius = UDim.new(0,8)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0,8)
    pad.PaddingBottom = UDim.new(0,12)
    pad.PaddingLeft = UDim.new(0,8)
    pad.PaddingRight = UDim.new(0,8)
    pad.Parent = page

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0,6)
    list.Parent = page

    local order = 0
    local function nextOrder()
        order += 1
        return order
    end

    local function makeLabel(text, size, bold)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1,0,0,size + 8)
        label.LayoutOrder = nextOrder()
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.new(1,1,1)
        label.TextSize = size
        label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 21
        label.Parent = page
        return label
    end

    local function makeBtn(text, height)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1,0,0,height or 32)
        b.LayoutOrder = nextOrder()
        b.BackgroundColor3 = BUTTON_DEFAULT_COLOR
        b.TextColor3 = Color3.new(1,1,1)
        b.Text = text
        b.TextSize = 13
        b.Font = Enum.Font.Gotham
        b.ZIndex = 21
        b.Parent = page
        Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
        return b
    end

    makeLabel("✨ PARTICLE AURA", 16, true)

    local toggleButton = makeBtn("✨ Aura: OFF")

    -- Efek -------------------------------------------------
    makeLabel("Efek", 13, true)

    local effectGrid = Instance.new("Frame")
    effectGrid.Size = UDim2.new(1,0,0,68)
    effectGrid.LayoutOrder = nextOrder()
    effectGrid.BackgroundTransparency = 1
    effectGrid.ZIndex = 21
    effectGrid.Parent = page

    local effectLayout = Instance.new("UIGridLayout")
    effectLayout.CellSize = UDim2.new(0.5,-3,0,31)
    effectLayout.CellPadding = UDim2.fromOffset(6,6)
    effectLayout.SortOrder = Enum.SortOrder.LayoutOrder
    effectLayout.Parent = effectGrid

    local effectButtons = {}

    local function updateEffectButtons()
        for name, button in pairs(effectButtons) do
            setButtonState(button, state.effect == name)
        end
    end

    for index, name in ipairs(EFFECT_ORDER) do
        local b = Instance.new("TextButton")
        b.LayoutOrder = index
        b.BackgroundColor3 = BUTTON_DEFAULT_COLOR
        b.TextColor3 = Color3.new(1,1,1)
        b.Text = EFFECT_LABELS[name]
        b.TextSize = 13
        b.Font = Enum.Font.Gotham
        b.ZIndex = 22
        b.Parent = effectGrid
        Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
        effectButtons[name] = b

        b.MouseButton1Click:Connect(function()
            state.effect = name
            updateEffectButtons()
            refreshAura()
        end)
    end

    -- Warna ------------------------------------------------
    makeLabel("Warna", 13, true)

    local swatchGrid = Instance.new("Frame")
    swatchGrid.Size = UDim2.new(1,0,0,62)
    swatchGrid.LayoutOrder = nextOrder()
    swatchGrid.BackgroundTransparency = 1
    swatchGrid.ZIndex = 21
    swatchGrid.Parent = page

    local swatchLayout = Instance.new("UIGridLayout")
    swatchLayout.CellSize = UDim2.new(0.25,-5,0,28)
    swatchLayout.CellPadding = UDim2.fromOffset(6,6)
    swatchLayout.SortOrder = Enum.SortOrder.LayoutOrder
    swatchLayout.Parent = swatchGrid

    local hexBoxPA

    local function colorToHexPA(color)
        return string.format("%02X%02X%02X",
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5))
    end

    local function hexToColorPA(text)
        local hex = tostring(text or ""):gsub("[#%s]","")
        if #hex ~= 6 or hex:find("[^%x]") then return nil end
        local r = tonumber(hex:sub(1,2),16)
        local g = tonumber(hex:sub(3,4),16)
        local b = tonumber(hex:sub(5,6),16)
        if not (r and g and b) then return nil end
        return Color3.fromRGB(r,g,b)
    end

    local swatchButtons = {}

    local function updateColorUI()
        for _, entry in ipairs(swatchButtons) do
            local selected = state.color ~= nil
                and colorToHexPA(entry.color) == colorToHexPA(state.color)
            entry.button.Text = selected and "✓" or ""
        end
        if hexBoxPA then
            hexBoxPA.Text = state.color and ("#" .. colorToHexPA(state.color)) or ""
        end
    end

    for index, color in ipairs(SWATCHES) do
        local b = Instance.new("TextButton")
        b.LayoutOrder = index
        b.BackgroundColor3 = color
        b.TextColor3 = Color3.fromRGB(20,20,20)
        b.Text = ""
        b.TextSize = 15
        b.Font = Enum.Font.GothamBold
        b.ZIndex = 22
        b.Parent = swatchGrid
        Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
        table.insert(swatchButtons,{button = b, color = color})

        b.MouseButton1Click:Connect(function()
            state.color = color
            updateColorUI()
            refreshAura()
        end)
    end

    hexBoxPA = Instance.new("TextBox")
    hexBoxPA.Size = UDim2.new(1,0,0,30)
    hexBoxPA.LayoutOrder = nextOrder()
    hexBoxPA.BackgroundColor3 = Color3.fromRGB(50,50,50)
    hexBoxPA.TextColor3 = Color3.new(1,1,1)
    hexBoxPA.PlaceholderColor3 = Color3.fromRGB(170,170,170)
    hexBoxPA.PlaceholderText = "#RRGGBB (kosong = bawaan efek)"
    hexBoxPA.Text = ""
    hexBoxPA.TextSize = 12
    hexBoxPA.Font = Enum.Font.Gotham
    hexBoxPA.ClearTextOnFocus = false
    hexBoxPA.ZIndex = 21
    hexBoxPA.Parent = page
    Instance.new("UICorner",hexBoxPA).CornerRadius = UDim.new(0,6)

    hexBoxPA.FocusLost:Connect(function()
        local color = hexToColorPA(hexBoxPA.Text)
        if color then
            state.color = color
            refreshAura()
        elseif tostring(hexBoxPA.Text):gsub("%s","") == "" then
            state.color = nil
            refreshAura()
        end
        updateColorUI()
    end)

    local defaultColorButton = makeBtn("↺ Warna Bawaan Efek", 28)
    defaultColorButton.MouseButton1Click:Connect(function()
        state.color = nil
        updateColorUI()
        refreshAura()
    end)

    -- Stepper (− nilai +) ------------------------------------
    local function makeStepper(title, levels, key, formatter)
        makeLabel(title, 13, true)

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,30)
        row.LayoutOrder = nextOrder()
        row.BackgroundTransparency = 1
        row.ZIndex = 21
        row.Parent = page

        local function cell(text, position, size)
            local b = Instance.new("TextButton")
            b.Position = position
            b.Size = size
            b.BackgroundColor3 = BUTTON_DEFAULT_COLOR
            b.TextColor3 = Color3.new(1,1,1)
            b.Text = text
            b.TextSize = 16
            b.Font = Enum.Font.GothamBold
            b.ZIndex = 22
            b.Parent = row
            Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
            return b
        end

        local minus = cell("−", UDim2.fromOffset(0,0), UDim2.new(0,44,1,0))
        local plus = cell("+", UDim2.new(1,-44,0,0), UDim2.new(0,44,1,0))

        local value = Instance.new("TextLabel")
        value.Position = UDim2.fromOffset(48,0)
        value.Size = UDim2.new(1,-96,1,0)
        value.BackgroundTransparency = 1
        value.TextColor3 = Color3.new(1,1,1)
        value.TextSize = 13
        value.Font = Enum.Font.Gotham
        value.ZIndex = 22
        value.Parent = row

        local function refreshValue()
            value.Text = formatter(levels[state[key]])
        end

        local function change(delta)
            state[key] = math.clamp(state[key] + delta, 1, #levels)
            refreshValue()
            refreshAura()
        end

        minus.MouseButton1Click:Connect(function() change(-1) end)
        plus.MouseButton1Click:Connect(function() change(1) end)

        refreshValue()
    end

    makeStepper("Ukuran partikel", SIZE_LEVELS, "sizeIdx", function(v)
        return "×" .. tostring(v)
    end)
    makeStepper("Intensitas", INTENSITY_LEVELS, "intensityIdx", function(v)
        return v .. "%"
    end)
    makeStepper("Kecepatan animasi", SPEED_LEVELS, "speedIdx", function(v)
        return "×" .. tostring(v)
    end)

    local randomButton = makeBtn("🎲 Acak Efek & Warna")

    local backButtonPA = makeBtn("↩️ Back")

    --------------------------------------------------
    -- Aksi tombol
    --------------------------------------------------
    local function refreshToggleUI()
        toggleButton.Text = state.enabled and "✨ Aura: ON" or "✨ Aura: OFF"
        particleAuraButton.Text = state.enabled
            and "✨ Particle Aura: ON" or "✨ Particle Aura: OFF"
        setButtonState(toggleButton, state.enabled)
        setButtonState(particleAuraButton, state.enabled)
    end

    toggleButton.MouseButton1Click:Connect(function()
        if state.enabled then
            stopAura()
        else
            startAura()
        end
        refreshToggleUI()
    end)

    particleAuraButton.MouseButton1Click:Connect(function()
        scroll.Visible = false
        page.Visible = true
    end)

    backButtonPA.MouseButton1Click:Connect(function()
        page.Visible = false
        scroll.Visible = true
    end)

    -- Menutup menu: tutup halaman aura juga (aura tetap berjalan).
    close.MouseButton1Click:Connect(function()
        if page.Visible then
            page.Visible = false
            scroll.Visible = true
        end
    end)

    -- Panel pengaturan (⚙️) dibuat belakangan; jika dibuka, halaman
    -- aura disembunyikan agar tidak menutupinya.
    local function watchSettingsPanel(child)
        if child.Name == "ZaqiSettingsPanel" and child:IsA("GuiObject") then
            child:GetPropertyChangedSignal("Visible"):Connect(function()
                if child.Visible then
                    page.Visible = false
                end
            end)
        end
    end
    for _, child in ipairs(menu:GetChildren()) do
        watchSettingsPanel(child)
    end
    menu.ChildAdded:Connect(watchSettingsPanel)

    -- Efek + warna acak (dipakai saat awal dan tombol Acak).
    local function randomizeAura()
        state.effect = EFFECT_ORDER[math.random(1,#EFFECT_ORDER)]
        state.color = Color3.fromHSV(math.random(), 0.85, 1)
        updateEffectButtons()
        updateColorUI()
        refreshAura()
    end

    randomButton.MouseButton1Click:Connect(randomizeAura)

    -- Posisi awal: Particle Aura langsung ON dengan efek & warna acak.
    state.effect = EFFECT_ORDER[math.random(1,#EFFECT_ORDER)]
    state.color = Color3.fromHSV(math.random(), 0.85, 1)

    updateEffectButtons()
    updateColorUI()
    startAura()
    refreshToggleUI()
end)()

--==================================================
-- INFORMASI (PEMAIN + FPS + PING)
--==================================================

local showStats = true -- posisi awal: ON
local fpsValue = 0
local fpsFrames = 0
local fpsElapsed = 0

-- Tombol hanya menjadi sakelar. Nilai FPS/Ping ditampilkan
-- pada panel terpisah di kiri bawah layar.
local statsButton = makeButton(showStats and "📊 Informasi: ON" or "📊 Informasi: OFF")
setButtonState(statsButton, showStats)

local statsConnection

statsButton.MouseButton1Click:Connect(function()
    showStats = not showStats
    statsButton.Text = showStats and "📊 Informasi: ON" or "📊 Informasi: OFF"
    setButtonState(statsButton, showStats)

    -- Tampilkan/sembunyikan panel FPS + Ping di kiri bawah.
    setFpsPingOverlayEnabled(showStats)
end)

-- Posisi awal Informasi = ON, dengan pilihan ✓ / ✗ tepat di atas panel
-- (kiri bawah layar):
--   ✓ = biarkan Informasi tetap ON (tombol ✓ ✗ hilang)
--   ✗ = matikan Informasi (panel hilang, tombol di menu jadi OFF)
-- Dibungkus fungsi agar tidak menambah variabel local tingkat atas.
;(function()
    setFpsPingOverlayEnabled(true)

    local overlayGui = fpsPingOverlay
    if not overlayGui then return end

    local choice = Instance.new("Frame")
    choice.Name = "InfoChoice"
    choice.Position = UDim2.new(0, 10, 1, -88 - 30) -- tepat di atas panel (panel: y = 1,-88)
    choice.Size = UDim2.fromOffset(150, 26)
    choice.BackgroundTransparency = 1
    choice.Parent = overlayGui

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = choice

    local function makeChoiceButton(text, color, order)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(40, 26)
        b.LayoutOrder = order
        b.BackgroundColor3 = color
        b.BackgroundTransparency = 0.1
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.TextSize = 18
        b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = true
        b.Parent = choice
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end

    local keepButton = makeChoiceButton("✓", Color3.fromRGB(0, 170, 80), 1)
    local offButton = makeChoiceButton("✗", Color3.fromRGB(200, 50, 50), 2)

    keepButton.Activated:Connect(function()
        -- Biarkan ON: cukup sembunyikan pilihan.
        choice:Destroy()
    end)

    offButton.Activated:Connect(function()
        -- Matikan Informasi lewat jalur yang sama dengan tombol di menu.
        choice:Destroy()
        showStats = false
        statsButton.Text = "📊 Informasi: OFF"
        setButtonState(statsButton, false)
        setFpsPingOverlayEnabled(false)
    end)
end)()

statsConnection = RunService.RenderStepped:Connect(function(dt)
    fpsFrames += 1
    fpsElapsed += dt

    if fpsElapsed >= 0.5 then
        fpsValue = math.floor((fpsFrames / fpsElapsed) + 0.5)
        fpsFrames = 0
        fpsElapsed = 0
    end
end)

--==================================================
-- ANTI AFK
--==================================================

local antiAFK = false
local antiAFKConnection
local antiAFKWatchdogConnection
local antiAFKVirtualUser = game:GetService("VirtualUser")
local antiAFKElapsed = 0
local antiAFKInterval = 30

local antiAFKButton =
    makeButton("🛡️ Anti AFK: OFF")

local function antiAFKActivity()
    if not antiAFK then
        return
    end

    -- Aktivitas virtual tanpa menggerakkan karakter.
    pcall(function()
        antiAFKVirtualUser:CaptureController()
        antiAFKVirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end

local function stopAntiAFK()
    if antiAFKConnection then
        antiAFKConnection:Disconnect()
        antiAFKConnection = nil
    end

    if antiAFKWatchdogConnection then
        antiAFKWatchdogConnection:Disconnect()
        antiAFKWatchdogConnection = nil
    end

    antiAFKElapsed = 0
end

antiAFKButton.MouseButton1Click:Connect(function()
    antiAFK = not antiAFK

    stopAntiAFK()

    if antiAFK then
        antiAFKButton.Text = "🛡️ Anti AFK: ON"

        -- Tetap merespons event Idled sebagai pengaman.
        antiAFKConnection = player.Idled:Connect(function()
            antiAFKActivity()
        end)

        -- Watchdog berkala sebagai pengaman tambahan.
        -- Tidak mengubah posisi atau WalkSpeed karakter.
        antiAFKWatchdogConnection = RunService.Heartbeat:Connect(function(dt)
            if not antiAFK then
                return
            end

            antiAFKElapsed += dt

            if antiAFKElapsed >= antiAFKInterval then
                antiAFKElapsed = 0
                antiAFKActivity()
            end
        end)

        -- Aktivitas awal supaya mode langsung aktif.
        antiAFKActivity()
    else
        antiAFKButton.Text = "🛡️ Anti AFK: OFF"
    end

    setButtonState(antiAFKButton, antiAFK)
end)

--==================================================
-- TELEPORT SPAWN
--==================================================

-- Menyimpan posisi sebelum Teleport Spawn agar bisa kembali.
local previousTeleportCFrame = nil

local teleportButton =
    makeButton("📍 Teleport Spawn")

teleportButton.MouseButton1Click:Connect(function()

    local character = player.Character
    if not character then return end

    local root =
        character:FindFirstChild("HumanoidRootPart")

    if not root then return end

    local spawnLocation =
        workspace:FindFirstChildWhichIsA(
            "SpawnLocation",
            true
        )

    if spawnLocation then

        -- Simpan posisi saat ini sebelum teleport.
        previousTeleportCFrame = root.CFrame

        -- Tandai teleport agar Cinematic Orbit langsung memindahkan
        -- kamera ke orbit baru tanpa menariknya dari posisi lama.
        cinematicOrbitSnapNextFrame = true

        root.CFrame =
            spawnLocation.CFrame +
            Vector3.new(0,5,0)

    end
end)

-- Kembali ke posisi sebelum Teleport Spawn.
local teleportBackButton =
    makeButton("↩️ Teleport Back")

teleportBackButton.MouseButton1Click:Connect(function()

    local character = player.Character
    if not character then return end

    local root =
        character:FindFirstChild("HumanoidRootPart")

    if not root then return end

    if previousTeleportCFrame then
        -- Simpan posisi sekarang agar bisa bolak-balik.
        local currentCFrame = root.CFrame

        cinematicOrbitSnapNextFrame = true
        root.CFrame = previousTeleportCFrame

        previousTeleportCFrame = currentCFrame
    end
end)


--==================================================
-- RESET
--==================================================

local resetButton =
	makeButton("🔄 Reset Character")

resetButton.MouseButton1Click:Connect(function()

	local character = player.Character

	if character then

		local humanoid =
			character:FindFirstChildOfClass("Humanoid")

		if humanoid then
			humanoid.Health = 0
		end
	end
end)

--==================================================
-- HOTBAR 8 SLOT + TAS (BACKPACK) + TOMBOL E
-- (dipindahkan dari script Abad Pertengahan)
--==================================================
-- Dibungkus function sendiri supaya tidak menambah jumlah variabel
-- local di scope utama script (batas Lua: 200 local).
;(function()
    local StarterGui = game:GetService("StarterGui")
    local ContextActionService = game:GetService("ContextActionService")

    local Player = player
    local ScreenGui = gui

    -- Hapus hotbar lama jika script dijalankan ulang tanpa rejoin.
    pcall(function()
        local old = ScreenGui:FindFirstChild("CustomHotbar")
        if old then old:Destroy() end
        local oldPicker = ScreenGui:FindFirstChild("HotbarItemPicker")
        if oldPicker then oldPicker:Destroy() end
    end)

    --------------------------------------------------
    -- TAS (BACKPACK BAWAAN ROBLOX)
    --------------------------------------------------
    local robloxBackpackVisible = true

    local function applyRobloxBackpack()
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, robloxBackpackVisible)
        end)
    end

    applyRobloxBackpack()

    -- Terapkan ulang setelah respawn supaya pilihan ON/OFF tidak berubah sendiri.
    Player.CharacterAdded:Connect(function()
        task.wait(0.5)
        applyRobloxBackpack()
    end)

    --------------------------------------------------
    -- HOTBAR
    --------------------------------------------------
    local Hotbar = Instance.new("Frame")
    Hotbar.Name = "CustomHotbar"
    local hotbarVisible = false -- posisi awal: OFF
    Hotbar.AnchorPoint = Vector2.new(0.5, 1)
    Hotbar.Position = UDim2.new(0.5, 0, 1, -6)
    Hotbar.Size = UDim2.new(0, 300, 0, 42)
    Hotbar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    Hotbar.BackgroundTransparency = 0
    Hotbar.BorderSizePixel = 0
    Hotbar.ZIndex = 5
    Hotbar.Visible = hotbarVisible
    Hotbar.Parent = ScreenGui

    local HotbarCorner = Instance.new("UICorner")
    HotbarCorner.CornerRadius = UDim.new(0, 4)
    HotbarCorner.Parent = Hotbar

    local HotbarPadding = Instance.new("UIPadding")
    HotbarPadding.PaddingLeft = UDim.new(0, 3)
    HotbarPadding.PaddingRight = UDim.new(0, 3)
    HotbarPadding.PaddingTop = UDim.new(0, 3)
    HotbarPadding.PaddingBottom = UDim.new(0, 3)
    HotbarPadding.Parent = Hotbar

    local HotbarLayout = Instance.new("UIListLayout")
    HotbarLayout.FillDirection = Enum.FillDirection.Horizontal
    HotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    HotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    HotbarLayout.Padding = UDim.new(0, 2)
    HotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    HotbarLayout.Parent = Hotbar

    local HotbarSlots = {}
    local EquippedTool = nil
    local LONG_PRESS_SECONDS = 2
    local showSlotItemPicker
    local updateHotbar -- forward declaration (dipakai sebelum didefinisikan)

    -- Urutan slot hotbar. Item di luar slot 1-8 tetap berada di Inventory Roblox.
    local hotbarOrder = {}
    local MAX_HOTBAR_SLOTS = 8

    local function getAllTools()
        local tools = {}
        local backpack = Player:FindFirstChildOfClass("Backpack")

        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") then
                    table.insert(tools, item)
                end
            end
        end

        if Player.Character then
            for _, item in ipairs(Player.Character:GetChildren()) do
                if item:IsA("Tool") then
                    local found = false
                    for _, existing in ipairs(tools) do
                        if existing == item then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(tools, item)
                    end
                end
            end
        end

        return tools
    end

    local function findToolByName(name)
        if not name then return nil end
        for _, tool in ipairs(getAllTools()) do
            if tool.Name == name then
                return tool
            end
        end
        return nil
    end

    local function ensureHotbarOrder()
        local available = {}
        for _, tool in ipairs(getAllTools()) do
            available[tool.Name] = true
        end

        -- Posisi item dipertahankan; slot yang kehilangan item menjadi
        -- kosong sementara dan hanya diisi oleh Tool baru.
        for i = 1, MAX_HOTBAR_SLOTS do
            local name = hotbarOrder[i]
            if type(name) == "string" and not available[name] then
                hotbarOrder[i] = false
            end
        end

        -- Isi hotbar awal saja jika belum pernah ada susunan yang dibuat.
        if next(hotbarOrder) == nil then
            for _, tool in ipairs(getAllTools()) do
                local emptySlot
                for i = 1, MAX_HOTBAR_SLOTS do
                    if hotbarOrder[i] == nil then
                        emptySlot = i
                        break
                    end
                end
                if not emptySlot then break end
                hotbarOrder[emptySlot] = tool.Name
            end
        end
    end

    local function fillClearedSlotWithNewTool(tool)
        if not tool or not tool:IsA("Tool") then return end

        -- Jangan memasukkan ulang item yang sudah terdaftar di slot lain.
        for i = 1, MAX_HOTBAR_SLOTS do
            if hotbarOrder[i] == tool.Name then
                return
            end
        end

        -- Slot false/nil = kosong. Isi hanya saat ada Tool baru masuk.
        for i = 1, MAX_HOTBAR_SLOTS do
            if hotbarOrder[i] == false or hotbarOrder[i] == nil then
                hotbarOrder[i] = tool.Name
                return
            end
        end
    end

    local function getHotbarTools()
        ensureHotbarOrder()
        local result = {}
        for i = 1, MAX_HOTBAR_SLOTS do
            result[i] = findToolByName(hotbarOrder[i])
        end
        return result
    end

    local function assignToolToSlot(toolName, targetSlot)
        if not toolName or targetSlot < 1 or targetSlot > MAX_HOTBAR_SLOTS then
            return
        end

        local oldSlot
        for i = 1, MAX_HOTBAR_SLOTS do
            if hotbarOrder[i] == toolName then
                oldSlot = i
                break
            end
        end

        local targetTool = hotbarOrder[targetSlot]

        if oldSlot and oldSlot ~= targetSlot then
            hotbarOrder[oldSlot] = targetTool
        end

        hotbarOrder[targetSlot] = toolName
    end

    --------------------------------------------------
    -- AUTO RE-EQUIP (item yang sama otomatis dipegang lagi)
    --------------------------------------------------
    local autoReequipName = nil
    local autoReequipTool = nil
    local autoReequipBusy = false

    local function findSameToolInBackpack(name)
        if not name then return nil end

        local backpack = Player:FindFirstChildOfClass("Backpack")
        if not backpack then return nil end

        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and item.Name == name then
                return item
            end
        end

        return nil
    end

    local function autoReequipSameTool()
        if autoReequipBusy or not autoReequipName then
            return
        end

        local character = Player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not character or not humanoid then
            return
        end

        -- Jangan mengganggu jika pemain sudah memegang Tool lain.
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") then
                return
            end
        end

        local sameTool = findSameToolInBackpack(autoReequipName)
        if not sameTool then
            return
        end

        autoReequipBusy = true

        task.defer(function()
            if sameTool.Parent == Player:FindFirstChildOfClass("Backpack")
                and Player.Character == character then
                pcall(function()
                    humanoid:EquipTool(sameTool)
                end)
            end

            task.wait(0.05)
            autoReequipBusy = false
            updateHotbar()
        end)
    end

    local function rememberTool(tool)
        if tool and tool:IsA("Tool") then
            autoReequipName = tool.Name
            autoReequipTool = tool
        end
    end

    local function watchEquippedTool(tool)
        if not tool or not tool:IsA("Tool") then
            return
        end

        rememberTool(tool)

        -- Hanya pantau Tool yang sedang dipakai.
        tool.AncestryChanged:Connect(function()
            if autoReequipTool ~= tool then
                return
            end

            if not tool:IsDescendantOf(game) then
                task.delay(0.08, autoReequipSameTool)
            end
        end)
    end

    local function equipTool(tool)
        if not tool or not tool.Parent then return end

        rememberTool(tool)
        watchEquippedTool(tool)

        local character = Player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        if EquippedTool == tool and tool.Parent == character then
            humanoid:UnequipTools()
            EquippedTool = nil
        else
            humanoid:EquipTool(tool)
            EquippedTool = tool
        end
    end

    updateHotbar = function()
        local tools = getHotbarTools()
        EquippedTool = nil

        if Player.Character then
            for _, item in ipairs(Player.Character:GetChildren()) do
                if item:IsA("Tool") then
                    EquippedTool = item
                    break
                end
            end
        end

        for i = 1, 8 do
            local slot = HotbarSlots[i]
            local tool = tools[i]
            slot.Tool = tool
            slot.NameLabel.Text = tool and tool.Name or ""
            slot.KeyLabel.Text = tostring(i)

            if tool and tool == EquippedTool then
                slot.Button.BackgroundColor3 = Color3.fromRGB(55, 65, 70)
                slot.UIStroke.Color = Color3.fromRGB(0, 235, 255)
                slot.UIStroke.Thickness = 2
                slot.UIStroke.Transparency = 0
                slot.UIStroke.Enabled = true
            else
                slot.Button.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
                slot.UIStroke.Thickness = 2
                slot.UIStroke.Transparency = 1
                slot.UIStroke.Enabled = false
            end
        end
    end

    for i = 1, 8 do
        local slot = Instance.new("TextButton")
        slot.Name = "Slot" .. i
        slot.Size = UDim2.new(0, 34, 0, 34)
        slot.LayoutOrder = i
        slot.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        slot.BorderSizePixel = 0
        slot.Text = ""
        slot.AutoButtonColor = true
        slot.ZIndex = 6
        slot.Parent = Hotbar

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 3)
        corner.Parent = slot

        local stroke = Instance.new("UIStroke")
        stroke.Name = "UIStroke"
        stroke.Thickness = 1
        stroke.Color = Color3.fromRGB(0, 235, 255)
        stroke.Transparency = 1
        stroke.Enabled = false
        stroke.Parent = slot

        local key = Instance.new("TextLabel")
        key.Name = "Key"
        key.Size = UDim2.new(0, 12, 0, 12)
        key.Position = UDim2.new(0, 2, 0, 1)
        key.BackgroundTransparency = 1
        key.TextColor3 = Color3.fromRGB(210, 210, 210)
        key.TextSize = 9
        key.Font = Enum.Font.GothamBold
        key.Text = tostring(i)
        key.ZIndex = 7
        key.Parent = slot

        local name = Instance.new("TextLabel")
        name.Name = "ToolName"
        name.Size = UDim2.new(1, -4, 0, 14)
        name.Position = UDim2.new(0, 2, 1, -15)
        name.BackgroundTransparency = 1
        name.TextColor3 = Color3.fromRGB(255, 255, 255)
        name.TextSize = 7
        name.Font = Enum.Font.GothamBold
        name.TextWrapped = false
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.ZIndex = 7
        name.Parent = slot

        HotbarSlots[i] = {
            Button = slot,
            KeyLabel = key,
            NameLabel = name,
            UIStroke = stroke,
            Tool = nil
        }

        local pressToken = 0
        local longPressFired = false

        slot.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end

            pressToken = pressToken + 1
            local thisToken = pressToken
            longPressFired = false

            task.delay(LONG_PRESS_SECONDS, function()
                if pressToken ~= thisToken or not slot.Parent then return end
                longPressFired = true
                if showSlotItemPicker then
                    showSlotItemPicker(i)
                end
            end)
        end)

        slot.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                pressToken = pressToken + 1
            end
        end)

        slot.MouseButton1Click:Connect(function()
            if longPressFired then
                longPressFired = false
                return
            end
            equipTool(HotbarSlots[i].Tool)
            task.defer(updateHotbar)
        end)
    end

    -- Tombol angka 1-8 di keyboard
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or UserInputService:GetFocusedTextBox() then return end
        local keyMap = {
            [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2,
            [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4,
            [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
            [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8,
        }
        local index = keyMap[input.KeyCode]
        if index then
            equipTool(HotbarSlots[index].Tool)
            task.defer(updateHotbar)
        end
    end)

    local function connectBackpack(backpack)
        if not backpack then return end
        backpack.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                -- Tunggu parent/karakter selesai diperbarui agar item baru
                -- tidak terlewat saat berpindah dari Character ke Backpack.
                task.defer(function()
                    if child.Parent == backpack then
                        fillClearedSlotWithNewTool(child)
                    end
                    updateHotbar()
                end)
            else
                updateHotbar()
            end
        end)
        backpack.ChildRemoved:Connect(updateHotbar)
    end

    connectBackpack(Player:FindFirstChildOfClass("Backpack"))
    Player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            connectBackpack(child)
        end
    end)

    local function hookCharacter(character)
        character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                task.defer(function()
                    if child.Parent == character then
                        fillClearedSlotWithNewTool(child)
                        rememberTool(child)
                        watchEquippedTool(child)
                    end
                    updateHotbar()
                end)
            else
                updateHotbar()
            end
        end)

        character.ChildRemoved:Connect(function()
            updateHotbar()
        end)
    end

    Player.CharacterAdded:Connect(function(character)
        hookCharacter(character)
        task.wait(0.2)
        updateHotbar()
    end)

    if Player.Character then
        hookCharacter(Player.Character)
    end

    updateHotbar()

    -- Sinkronisasi ringan: menangkap perubahan Equip/Unequip yang tidak
    -- selalu memicu ChildAdded/ChildRemoved.
    task.spawn(function()
        while ScreenGui and ScreenGui.Parent do
            updateHotbar()
            task.wait(0.15)
        end
    end)

    --------------------------------------------------
    -- ATUR SLOT HOTBAR (tahan slot 2 detik -> pilih item)
    --------------------------------------------------
    showSlotItemPicker = function(targetSlot)
        local oldPicker = ScreenGui:FindFirstChild("HotbarItemPicker")
        if oldPicker then oldPicker:Destroy() end

        local picker = Instance.new("Frame")
        picker.Name = "HotbarItemPicker"
        picker.AnchorPoint = Vector2.new(0.5, 0.5)
        picker.Position = UDim2.new(0.5, 0, 0.5, 0)
        picker.Size = UDim2.new(0, 250, 0, 300)
        picker.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        picker.BorderSizePixel = 0
        picker.ZIndex = 30
        picker.Parent = ScreenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = picker

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -12, 0, 36)
        title.Position = UDim2.new(0, 6, 0, 4)
        title.BackgroundTransparency = 1
        title.Text = "Pilih item untuk Slot " .. targetSlot
        title.TextColor3 = Color3.new(1, 1, 1)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.ZIndex = 31
        title.Parent = picker

        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0, 28, 0, 28)
        close.Position = UDim2.new(1, -32, 0, 5)
        close.BackgroundColor3 = Color3.fromRGB(150, 55, 55)
        close.Text = "X"
        close.TextColor3 = Color3.new(1, 1, 1)
        close.Font = Enum.Font.GothamBold
        close.TextSize = 14
        close.ZIndex = 32
        close.Parent = picker
        close.MouseButton1Click:Connect(function() picker:Destroy() end)

        local list = Instance.new("ScrollingFrame")
        list.Position = UDim2.new(0, 8, 0, 82)
        list.Size = UDim2.new(1, -16, 1, -90)
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.ScrollBarThickness = 5
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.ZIndex = 31
        list.Parent = picker

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 5)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = list

        local clearButton = Instance.new("TextButton")
        clearButton.Size = UDim2.new(1, -4, 0, 34)
        clearButton.LayoutOrder = 0
        clearButton.BackgroundColor3 = Color3.fromRGB(150, 65, 45)
        clearButton.BorderSizePixel = 0
        clearButton.Text = "🗑 Kosongkan Slot"
        clearButton.TextColor3 = Color3.new(1, 1, 1)
        clearButton.TextSize = 13
        clearButton.Font = Enum.Font.GothamBold
        clearButton.ZIndex = 32
        clearButton.Parent = list
        clearButton.MouseButton1Click:Connect(function()
            hotbarOrder[targetSlot] = false -- false = sengaja dikosongkan
            updateHotbar()
            picker:Destroy()
        end)

        local tools = getAllTools()
        if #tools == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 0, 36)
            empty.BackgroundTransparency = 1
            empty.Text = "Inventory kosong"
            empty.TextColor3 = Color3.new(1, 1, 1)
            empty.TextSize = 13
            empty.ZIndex = 32
            empty.Parent = list
        end

        for index, tool in ipairs(tools) do
            local itemButton = Instance.new("TextButton")
            itemButton.Size = UDim2.new(1, -4, 0, 34)
            itemButton.LayoutOrder = index
            itemButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
            itemButton.BorderSizePixel = 0
            itemButton.Text = "📦 " .. tool.Name
            itemButton.TextColor3 = Color3.new(1, 1, 1)
            itemButton.TextSize = 13
            itemButton.Font = Enum.Font.Gotham
            itemButton.ZIndex = 32
            itemButton.Parent = list
            itemButton.MouseButton1Click:Connect(function()
                if tool.Parent and (tool.Parent == Player:FindFirstChildOfClass("Backpack") or tool.Parent == Player.Character) then
                    assignToolToSlot(tool.Name, targetSlot)
                    updateHotbar()
                end
                picker:Destroy()
            end)
        end
    end

    --------------------------------------------------
    -- VIRTUAL E BUTTON (ANDROID / MOBILE)
    --------------------------------------------------
    local eButtonVisible = true
    local E_ACTION_NAME = "Zaqi_VirtualE"

    -- Cari ProximityPrompt terdekat supaya tombol E berperilaku
    -- seperti tombol interaksi PC.
    local function getNearestProximityPrompt()
        local Character = Player.Character
        if not Character then
            return nil
        end

        local Root = Character:FindFirstChild("HumanoidRootPart")
        if not Root then
            return nil
        end

        local nearest = nil
        local nearestDistance = math.huge

        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local parent = obj.Parent
                local part = nil

                if parent and parent:IsA("Attachment") then
                    part = parent.Parent
                elseif parent and parent:IsA("BasePart") then
                    part = parent
                end

                if part and part:IsA("BasePart") then
                    local distance = (Root.Position - part.Position).Magnitude
                    local maxDistance = obj.MaxActivationDistance or 10

                    if distance <= maxDistance and distance < nearestDistance then
                        nearest = obj
                        nearestDistance = distance
                    end
                end
            end
        end

        return nearest
    end

    local function virtualEAction(_, inputState)
        if inputState ~= Enum.UserInputState.Begin then
            return Enum.ContextActionResult.Pass
        end

        local prompt = getNearestProximityPrompt()

        if prompt then
            pcall(function()
                prompt:InputHoldBegin()
                task.defer(function()
                    if prompt and prompt.Parent then
                        prompt:InputHoldEnd()
                    end
                end)
            end)

            return Enum.ContextActionResult.Sink
        end

        return Enum.ContextActionResult.Pass
    end

    local function updateVirtualEButton()
        pcall(function()
            ContextActionService:UnbindAction(E_ACTION_NAME)
        end)

        if eButtonVisible and UserInputService.TouchEnabled then
            ContextActionService:BindAction(
                E_ACTION_NAME,
                virtualEAction,
                true,
                Enum.KeyCode.E
            )

            ContextActionService:SetTitle(E_ACTION_NAME, "E")

            -- Kanan bawah, di atas tombol Jump.
            ContextActionService:SetPosition(
                E_ACTION_NAME,
                UDim2.new(1, -115, 1, -190)
            )
        end
    end

    updateVirtualEButton()

    --------------------------------------------------
    -- POSISI HOTBAR | TAS (sampingan)
    --------------------------------------------------
    -- Susunan: |hotbar|tas|. Hotbar Zaqi berada di KIRI hotbar/tas bawaan
    -- Roblox (yang selalu di tengah bawah layar). Posisi tas diukur langsung
    -- dari CoreGui jika bisa; jika tidak bisa, dipakai perkiraan.
    -- Saat Tas OFF, hotbar Zaqi kembali ke tengah bawah.
    local HOTBAR_GAP = 8
    local HOTBAR_FULL_WIDTH = 300

    local function getRobloxHotbarFrame()
        local ok, frame = pcall(function()
            local coreGui = game:GetService("CoreGui")
            local robloxGui = coreGui:FindFirstChild("RobloxGui")
            local backpackGui = robloxGui and robloxGui:FindFirstChild("Backpack")
            return backpackGui and backpackGui:FindFirstChild("Hotbar")
        end)
        if ok and frame and frame:IsA("GuiObject") then
            return frame
        end
        return nil
    end

    local function layoutHotbar()
        if not Hotbar.Parent then return end

        local viewportX = ScreenGui.AbsoluteSize.X
        if viewportX <= 0 then return end

        local bottomOffset = 6
        local rightEdge -- tepi KANAN hotbar Zaqi (koordinat layar); nil = tengah

        if robloxBackpackVisible then
            local leftEdgeOfTas
            local tasFrame = getRobloxHotbarFrame()

            if tasFrame and tasFrame.Visible and tasFrame.AbsoluteSize.X > 20 then
                leftEdgeOfTas = tasFrame.AbsolutePosition.X

                -- Sejajarkan batas bawah dengan hotbar/tas bawaan Roblox.
                local ourBottom = ScreenGui.AbsolutePosition.Y + ScreenGui.AbsoluteSize.Y
                local tasBottom = tasFrame.AbsolutePosition.Y + tasFrame.AbsoluteSize.Y
                bottomOffset = math.clamp(ourBottom - tasBottom, 2, 60)
            else
                -- Perkiraan: layar sentuh kecil = hotbar bawaan sempit.
                local halfTas = UserInputService.TouchEnabled and 110 or 300
                leftEdgeOfTas = viewportX / 2 - halfTas
            end

            rightEdge = leftEdgeOfTas - HOTBAR_GAP
        end

        local width = HOTBAR_FULL_WIDTH
        if rightEdge then
            width = math.clamp(rightEdge - 4, 190, HOTBAR_FULL_WIDTH)
        end

        -- Kecilkan slot bila ruang di kiri tas sempit.
        local slotSize = math.clamp(math.floor((width - 6 - 7 * 2) / 8), 22, 34)
        for i = 1, 8 do
            HotbarSlots[i].Button.Size = UDim2.new(0, slotSize, 0, slotSize)
        end

        Hotbar.Size = UDim2.new(0, width, 0, slotSize + 8)

        if rightEdge then
            -- Jangan sampai keluar dari tepi kiri layar.
            local rightClamped = math.max(rightEdge, width)
            Hotbar.AnchorPoint = Vector2.new(1, 1)
            Hotbar.Position = UDim2.new(0, rightClamped, 1, -bottomOffset)
        else
            Hotbar.AnchorPoint = Vector2.new(0.5, 1)
            Hotbar.Position = UDim2.new(0.5, 0, 1, -bottomOffset)
        end
    end

    layoutHotbar()

    -- Ukur ulang berkala: ukuran hotbar bawaan Roblox berubah mengikuti
    -- jumlah slot / ukuran layar / rotasi perangkat.
    task.spawn(function()
        while Hotbar.Parent do
            task.wait(0.3)
            if Hotbar.Visible then
                pcall(layoutHotbar)
            end
        end
    end)

    --------------------------------------------------
    -- TOMBOL DI MENU ZAQI
    --------------------------------------------------
    local hotbarButton = makeButton(hotbarVisible and "🎒 Hotbar: ON" or "🎒 Hotbar: OFF")
    setButtonState(hotbarButton, hotbarVisible)

    hotbarButton.MouseButton1Click:Connect(function()
        hotbarVisible = not hotbarVisible
        Hotbar.Visible = hotbarVisible
        if hotbarVisible then layoutHotbar() end
        hotbarButton.Text = hotbarVisible and "🎒 Hotbar: ON" or "🎒 Hotbar: OFF"
        setButtonState(hotbarButton, hotbarVisible)
    end)

    local backpackButton = makeButton(robloxBackpackVisible and "👜 Tas: ON" or "👜 Tas: OFF")
    setButtonState(backpackButton, robloxBackpackVisible)

    backpackButton.MouseButton1Click:Connect(function()
        robloxBackpackVisible = not robloxBackpackVisible
        applyRobloxBackpack()
        task.defer(layoutHotbar)
        backpackButton.Text = robloxBackpackVisible and "👜 Tas: ON" or "👜 Tas: OFF"
        setButtonState(backpackButton, robloxBackpackVisible)
    end)

    local eButton = makeButton(eButtonVisible and "E: SHOW" or "E: HIDE")
    setButtonState(eButton, eButtonVisible)

    eButton.MouseButton1Click:Connect(function()
        eButtonVisible = not eButtonVisible
        updateVirtualEButton()
        eButton.Text = eButtonVisible and "E: SHOW" or "E: HIDE"
        setButtonState(eButton, eButtonVisible)
    end)

    --------------------------------------------------
    -- SERVER (folder paling bawah)
    -- Server Hop, Rejoin, Sepi, Ramai, Teman, New, Rekomendasi
    --------------------------------------------------
    local serverButton = makeButton("🌐 Server")
    serverButton.TextColor3 = Color3.fromRGB(255, 230, 0)
    serverButton.Font = Enum.Font.GothamBold

    ;(function()
        local TeleportService = game:GetService("TeleportService")
        local HttpService = game:GetService("HttpService")
        local localPlayer = Players.LocalPlayer

        local YELLOW = "#FFE600"
        local WHITE = "#FFFFFF"
        local busy = false
        local statusLabel
        local pageOrder = 0

        ----------------------------------------------
        -- Halaman Server (sama seperti halaman Boombox)
        ----------------------------------------------
        local serverPage = Instance.new("ScrollingFrame")
        serverPage.Name = "ZaqiServerPage"
        serverPage.Size = UDim2.new(1, -20, 1, -55)
        serverPage.Position = UDim2.fromOffset(10, 45)
        serverPage.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        serverPage.BorderSizePixel = 0
        serverPage.Visible = false
        serverPage.ZIndex = 20
        serverPage.CanvasSize = UDim2.new(0, 0, 0, 0)
        serverPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
        serverPage.ScrollBarThickness = 5
        serverPage.ScrollingDirection = Enum.ScrollingDirection.Y
        serverPage.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
        serverPage.Parent = menu
        Instance.new("UICorner", serverPage).CornerRadius = UDim.new(0, 8)

        local pageLayout = Instance.new("UIListLayout")
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        pageLayout.Padding = UDim.new(0, 7)
        pageLayout.Parent = serverPage

        local pagePad = Instance.new("UIPadding", serverPage)
        pagePad.PaddingTop = UDim.new(0, 8)
        pagePad.PaddingBottom = UDim.new(0, 10)
        pagePad.PaddingLeft = UDim.new(0, 8)
        pagePad.PaddingRight = UDim.new(0, 8)

        pageOrder = pageOrder + 1
        local pageTitle = Instance.new("TextLabel")
        pageTitle.Size = UDim2.new(1, 0, 0, 30)
        pageTitle.LayoutOrder = pageOrder
        pageTitle.BackgroundTransparency = 1
        pageTitle.Text = "🌐 SERVER"
        pageTitle.TextColor3 = Color3.fromRGB(255, 230, 0)
        pageTitle.TextSize = 16
        pageTitle.Font = Enum.Font.GothamBold
        pageTitle.ZIndex = 21
        pageTitle.Parent = serverPage

        local function setStatus(text)
            if statusLabel then
                statusLabel.Text = "📡 " .. text
            end
        end

        ----------------------------------------------
        -- Tombol: nama server KUNING, penjelasan PUTIH
        ----------------------------------------------
        local function makeServerButton(name, desc)
            pageOrder = pageOrder + 1

            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 40)
            b.AutomaticSize = Enum.AutomaticSize.Y
            b.LayoutOrder = pageOrder
            b.BackgroundColor3 = BUTTON_DEFAULT_COLOR
            b.TextColor3 = Color3.new(1, 1, 1)
            b.RichText = true
            b.TextWrapped = true
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.TextYAlignment = Enum.TextYAlignment.Center
            b.TextSize = 12
            b.Font = Enum.Font.Gotham
            b.ZIndex = 21
            b.Text = string.format(
                '<font color="%s"><b>%s</b></font>\n<font color="%s">%s</font>',
                YELLOW, name, WHITE, desc
            )
            b.Parent = serverPage

            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

            local pad = Instance.new("UIPadding", b)
            pad.PaddingLeft = UDim.new(0, 8)
            pad.PaddingRight = UDim.new(0, 8)
            pad.PaddingTop = UDim.new(0, 6)
            pad.PaddingBottom = UDim.new(0, 6)

            return b
        end

        ----------------------------------------------
        -- Ambil daftar server publik (API Roblox)
        ----------------------------------------------
        local function httpGet(url)
            local requestFn
            pcall(function()
                requestFn = (syn and syn.request) or http_request or request
                    or (http and http.request) or (fluxus and fluxus.request)
            end)

            if requestFn then
                local ok, res = pcall(requestFn, {Url = url, Method = "GET"})
                if ok and type(res) == "table" and res.Body
                    and (res.StatusCode == nil or res.StatusCode == 200) then
                    return res.Body
                end
            end

            local ok, res = pcall(function() return game:HttpGet(url) end)
            if ok and type(res) == "string" then
                return res
            end
            return nil
        end

        -- sortOrder: "Asc" (pemain paling sedikit dulu) / "Desc" (paling banyak dulu)
        local function fetchServers(sortOrder, maxPages)
            local list, cursor = {}, nil

            for _ = 1, maxPages do
                local url = string.format(
                    "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100",
                    game.PlaceId, sortOrder
                )
                if cursor then
                    url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
                end

                local body = httpGet(url)
                if not body then break end

                local ok, data = pcall(function()
                    return HttpService:JSONDecode(body)
                end)
                if not ok or type(data) ~= "table" or type(data.data) ~= "table" then
                    break
                end

                for _, s in ipairs(data.data) do
                    if s.id ~= game.JobId
                        and type(s.playing) == "number"
                        and type(s.maxPlayers) == "number"
                        and s.playing < s.maxPlayers then
                        table.insert(list, s)
                    end
                end

                cursor = data.nextPageCursor
                if not cursor then break end
            end

            return list
        end

        ----------------------------------------------
        -- Teleport
        ----------------------------------------------
        local function joinServer(server, label)
            setStatus("Bergabung: " .. label)
            local ok, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, localPlayer)
            end)
            if not ok then
                setStatus("Gagal teleport: " .. tostring(err))
                return false
            end
            return true
        end

        pcall(function()
            TeleportService.TeleportInitFailed:Connect(function(_, result, message)
                setStatus("Gagal: " .. tostring(message ~= "" and message or result))
                busy = false
            end)
        end)

        -- Jalankan aksi di thread sendiri + cegah klik berulang.
        -- Aksi mengembalikan true jika teleport sudah dimulai.
        local function runAction(fn)
            if busy then return end
            busy = true
            task.spawn(function()
                local ok, started = pcall(fn)
                if not ok then
                    setStatus("Error: " .. tostring(started))
                    busy = false
                elseif started then
                    -- Teleport berjalan; buka kunci kalau ternyata macet.
                    task.delay(15, function() busy = false end)
                else
                    busy = false
                end
            end)
        end

        ----------------------------------------------
        -- 1. Server Hop
        ----------------------------------------------
        makeServerButton("Server Hop",
            "Pindah ke server publik lain secara acak."
        ).MouseButton1Click:Connect(function()
            runAction(function()
                setStatus("Mencari server...")
                local list = fetchServers("Desc", 2)
                if #list == 0 then
                    setStatus("Tidak ada server lain yang tersedia.")
                    return false
                end
                return joinServer(list[math.random(1, #list)], "server acak")
            end)
        end)

        ----------------------------------------------
        -- 2. Rejoin Server
        ----------------------------------------------
        makeServerButton("Rejoin Server",
            "Masuk ulang ke server yang sama saat ini."
        ).MouseButton1Click:Connect(function()
            runAction(function()
                if #Players:GetPlayers() <= 1 then
                    -- Server kosong ditinggal = server hilang, jadi masuk ke server baru.
                    setStatus("Kamu sendirian, masuk ulang ke game...")
                    local ok, err = pcall(function()
                        TeleportService:Teleport(game.PlaceId, localPlayer)
                    end)
                    if not ok then
                        setStatus("Gagal: " .. tostring(err))
                        return false
                    end
                    return true
                end

                setStatus("Masuk ulang ke server ini...")
                local ok, err = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
                end)
                if not ok then
                    setStatus("Gagal: " .. tostring(err))
                    return false
                end
                return true
            end)
        end)

        ----------------------------------------------
        -- 3. Server Sepi
        ----------------------------------------------
        makeServerButton("Server Sepi",
            "Pindah ke server dengan pemain paling sedikit."
        ).MouseButton1Click:Connect(function()
            runAction(function()
                setStatus("Mencari server sepi...")
                local list = fetchServers("Asc", 1)
                local quiet = {}
                for _, s in ipairs(list) do
                    if s.playing >= 1 then
                        table.insert(quiet, s)
                        if #quiet >= 5 then break end
                    end
                end
                if #quiet == 0 then
                    setStatus("Server sepi tidak ditemukan.")
                    return false
                end
                local pick = quiet[math.random(1, #quiet)]
                return joinServer(pick, "sepi (" .. pick.playing .. "/" .. pick.maxPlayers .. ")")
            end)
        end)

        ----------------------------------------------
        -- 4. Server Ramai
        ----------------------------------------------
        makeServerButton("Server Ramai",
            "Pindah ke server dengan pemain paling banyak."
        ).MouseButton1Click:Connect(function()
            runAction(function()
                setStatus("Mencari server ramai...")
                local list = fetchServers("Desc", 1)
                if #list == 0 then
                    setStatus("Server ramai tidak ditemukan.")
                    return false
                end
                -- Sisakan 1 slot supaya tidak gagal karena server keburu penuh.
                local best
                for _, s in ipairs(list) do
                    if s.playing < s.maxPlayers - 1 and (not best or s.playing > best.playing) then
                        best = s
                    end
                end
                best = best or list[1]
                return joinServer(best, "ramai (" .. best.playing .. "/" .. best.maxPlayers .. ")")
            end)
        end)

        ----------------------------------------------
        -- 5. Server Teman
        ----------------------------------------------
        makeServerButton("Server Teman",
            "Bergabung ke server tempat temanmu sedang bermain."
        ).MouseButton1Click:Connect(function()
            runAction(function()
                setStatus("Mencari teman online...")
                local ok, friends = pcall(function()
                    return localPlayer:GetFriendsOnline(200)
                end)
                if not ok or type(friends) ~= "table" then
                    setStatus("Gagal membaca daftar teman.")
                    return false
                end

                local found
                for _, f in ipairs(friends) do
                    local sameGame = f.PlaceId == game.PlaceId
                        or (f.UniverseId ~= nil and f.UniverseId == game.GameId)
                    if sameGame and f.GameId and f.GameId ~= "" and f.GameId ~= game.JobId then
                        found = f
                        break
                    end
                end

                if not found then
                    setStatus("Tidak ada teman di server lain pada game ini.")
                    return false
                end

                local name = found.DisplayName or found.UserName or "teman"
                setStatus("Bergabung ke server " .. name .. "...")
                local okTp, err = pcall(function()
                    TeleportService:TeleportToPlaceInstance(
                        found.PlaceId or game.PlaceId, found.GameId, localPlayer
                    )
                end)
                if not okTp then
                    setStatus("Gagal teleport: " .. tostring(err))
                    return false
                end
                return true
            end)
        end)

        ----------------------------------------------
        -- 6. New Server
        ----------------------------------------------
        -- Roblox tidak memberi info umur server, jadi "baru" didekati dengan
        -- server yang baru berisi 1-2 pemain. Jika tidak ada, buat lewat Teleport.
        makeServerButton("New Server",
            "Masuk ke server baru yang masih sangat sedikit pemainnya."
        ).MouseButton1Click:Connect(function()
            runAction(function()
                setStatus("Mencari server baru...")
                local list = fetchServers("Asc", 1)
                local newest
                for _, s in ipairs(list) do
                    if s.playing >= 1 and s.playing <= 2 then
                        newest = s
                        break
                    end
                end

                if newest then
                    return joinServer(newest, "baru (" .. newest.playing .. "/" .. newest.maxPlayers .. ")")
                end

                setStatus("Membuat server baru...")
                local ok, err = pcall(function()
                    TeleportService:Teleport(game.PlaceId, localPlayer)
                end)
                if not ok then
                    setStatus("Gagal: " .. tostring(err))
                    return false
                end
                return true
            end)
        end)

        ----------------------------------------------
        -- 7. Rekomendasi Server
        ----------------------------------------------
        makeServerButton("Rekomendasi Server",
            "Pilih server paling stabil (ping rendah, FPS tinggi)."
        ).MouseButton1Click:Connect(function()
            runAction(function()
                setStatus("Menganalisis server...")
                local list = fetchServers("Asc", 2)
                local best, bestScore
                for _, s in ipairs(list) do
                    if s.playing >= 1 and type(s.fps) == "number" and type(s.ping) == "number" then
                        local score = s.fps - s.ping * 0.5
                        -- Hindari server hampir penuh (rawan lag/penuh mendadak).
                        if s.playing >= s.maxPlayers * 0.9 then
                            score = score - 20
                        end
                        if not bestScore or score > bestScore then
                            best, bestScore = s, score
                        end
                    end
                end

                if not best then
                    setStatus("Tidak ada data server yang cukup.")
                    return false
                end
                return joinServer(best, string.format(
                    "stabil (ping %d, FPS %d)", best.ping, math.floor(best.fps)
                ))
            end)
        end)

        ----------------------------------------------
        -- Status + tombol Back
        ----------------------------------------------
        pageOrder = pageOrder + 1
        statusLabel = Instance.new("TextLabel")
        statusLabel.Name = "ServerStatus"
        statusLabel.Size = UDim2.new(1, 0, 0, 24)
        statusLabel.AutomaticSize = Enum.AutomaticSize.Y
        statusLabel.LayoutOrder = pageOrder
        statusLabel.BackgroundTransparency = 1
        statusLabel.TextColor3 = Color3.new(1, 1, 1)
        statusLabel.TextWrapped = true
        statusLabel.TextSize = 11
        statusLabel.Font = Enum.Font.Gotham
        statusLabel.Text = "📡 Siap"
        statusLabel.ZIndex = 21
        statusLabel.Parent = serverPage

        pageOrder = pageOrder + 1
        local backBtn = Instance.new("TextButton")
        backBtn.Size = UDim2.new(1, 0, 0, 34)
        backBtn.LayoutOrder = pageOrder
        backBtn.BackgroundColor3 = BUTTON_DEFAULT_COLOR
        backBtn.TextColor3 = Color3.new(1, 1, 1)
        backBtn.Text = "↩️ Back"
        backBtn.TextSize = 13
        backBtn.Font = Enum.Font.Gotham
        backBtn.ZIndex = 21
        backBtn.Parent = serverPage
        Instance.new("UICorner", backBtn).CornerRadius = UDim.new(0, 6)

        ----------------------------------------------
        -- Buka / tutup halaman
        ----------------------------------------------
        serverButton.MouseButton1Click:Connect(function()
            scroll.Visible = false
            serverPage.Visible = true
        end)

        backBtn.MouseButton1Click:Connect(function()
            serverPage.Visible = false
            scroll.Visible = true
        end)

        -- Menutup menu dengan "x" TIDAK menutup halaman Server:
        -- saat menu dibuka lagi, tetap di halaman Server.

        -- Jika panel pengaturan (⚙️) dibuka, sembunyikan halaman Server.
        local function watchSettingsPanel(child)
            if child.Name == "ZaqiSettingsPanel" and child:IsA("GuiObject") then
                child:GetPropertyChangedSignal("Visible"):Connect(function()
                    if child.Visible then
                        serverPage.Visible = false
                    end
                end)
            end
        end
        for _, child in ipairs(menu:GetChildren()) do
            watchSettingsPanel(child)
        end
        menu.ChildAdded:Connect(watchSettingsPanel)
    end)()

    --------------------------------------------------
    -- TOOLS (kumpulan aplikasi kecil: Kalkulator, Musik, Catatan, Wheel Spin, Dice Roller)
    -- Tombol "Tools" di menu utama -> halaman daftar aplikasi
    -- -> klik Kalkulator -> halaman kalkulator.
    -- Dibungkus fungsi sendiri agar tidak menambah variabel local.
    -- Tombol dibuat setelah tombol Server, jadi tampil tepat di bawahnya.
    --------------------------------------------------
    ;(function()
        local toolsButton = makeButton("🧰 Tools")
        toolsButton.TextColor3 = Color3.fromRGB(255, 230, 0)
        toolsButton.Font = Enum.Font.GothamBold

        local PAGE_BG = Color3.fromRGB(35, 35, 35)

        local function newPage(name, scrolling)
            local p = Instance.new(scrolling and "ScrollingFrame" or "Frame")
            p.Name = name
            p.Size = UDim2.new(1, -20, 1, -55)
            p.Position = UDim2.fromOffset(10, 45)
            p.BackgroundColor3 = PAGE_BG
            p.BorderSizePixel = 0
            p.Visible = false
            p.ZIndex = 20
            p.Parent = menu
            Instance.new("UICorner", p).CornerRadius = UDim.new(0, 8)
            if scrolling then
                p.CanvasSize = UDim2.new(0, 0, 0, 0)
                p.AutomaticCanvasSize = Enum.AutomaticSize.Y
                p.ScrollBarThickness = 5
                p.ScrollingDirection = Enum.ScrollingDirection.Y
                p.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
            end
            return p
        end

        local function styleButton(b, text, color, size)
            b.BackgroundColor3 = color
            b.TextColor3 = Color3.new(1, 1, 1)
            b.Text = text
            b.TextSize = size or 13
            b.Font = Enum.Font.GothamBold
            b.AutoButtonColor = true
            b.ZIndex = 21
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        end

        ----------------------------------------------
        -- Halaman daftar aplikasi
        ----------------------------------------------
        local toolsPage = newPage("ZaqiToolsPage", true)

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 12)
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingRight = UDim.new(0, 8)
        pad.Parent = toolsPage

        local list = Instance.new("UIListLayout")
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Padding = UDim.new(0, 6)
        list.Parent = toolsPage

        local toolsTitle = Instance.new("TextLabel")
        toolsTitle.Size = UDim2.new(1, 0, 0, 24)
        toolsTitle.LayoutOrder = 1
        toolsTitle.BackgroundTransparency = 1
        toolsTitle.Text = "🧰 TOOLS"
        toolsTitle.TextColor3 = Color3.fromRGB(255, 230, 0)
        toolsTitle.TextSize = 16
        toolsTitle.Font = Enum.Font.GothamBold
        toolsTitle.TextXAlignment = Enum.TextXAlignment.Left
        toolsTitle.ZIndex = 21
        toolsTitle.Parent = toolsPage

        local toolsBack = Instance.new("TextButton")
        toolsBack.Size = UDim2.new(1, 0, 0, 32)
        toolsBack.LayoutOrder = 2
        toolsBack.Parent = toolsPage
        styleButton(toolsBack, "⬅️ Kembali ke Menu", Color3.fromRGB(70, 70, 70))

        -- Daftar aplikasi. Tambah aplikasi baru cukup dengan menambah
        -- tombol di sini (LayoutOrder dimulai dari 10).
        local calcOpenButton = Instance.new("TextButton")
        calcOpenButton.Size = UDim2.new(1, 0, 0, 35)
        calcOpenButton.LayoutOrder = 10
        calcOpenButton.Parent = toolsPage
        styleButton(calcOpenButton, "🧮 Kalkulator", Color3.fromRGB(55, 55, 55))

        ----------------------------------------------
        -- Mesin hitung (tanpa loadstring: parser sendiri, aman)
        -- Operator: + - * /  dan % (artinya dibagi 100).
        -- Urutan operasi benar (kali/bagi lebih dulu).
        ----------------------------------------------
        local MAX_LEN = 40
        local MAX_DIGITS = 15
        local OPS = { ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true }

        local function evaluate(text)
            local pos = 1
            local len = #text

            local function peek()
                return text:sub(pos, pos)
            end

            local parseExpr

            local function parseUnary()
                local c = peek()
                if c == "-" then
                    pos = pos + 1
                    return -parseUnary()
                elseif c == "+" then
                    pos = pos + 1
                    return parseUnary()
                end

                local s = text:match("^%d*%.?%d*", pos)
                if s == nil or s == "" or s == "." then
                    error("angka")
                end
                pos = pos + #s
                local v = tonumber(s)
                if v == nil then error("angka") end

                while peek() == "%" do
                    pos = pos + 1
                    v = v / 100
                end
                return v
            end

            local function parseTerm()
                local v = parseUnary()
                while true do
                    local c = peek()
                    if c == "*" then
                        pos = pos + 1
                        v = v * parseUnary()
                    elseif c == "/" then
                        pos = pos + 1
                        local d = parseUnary()
                        if d == 0 then error("bagi nol") end
                        v = v / d
                    else
                        break
                    end
                end
                return v
            end

            parseExpr = function()
                local v = parseTerm()
                while true do
                    local c = peek()
                    if c == "+" then
                        pos = pos + 1
                        v = v + parseTerm()
                    elseif c == "-" then
                        pos = pos + 1
                        v = v - parseTerm()
                    else
                        break
                    end
                end
                return v
            end

            local ok, result = pcall(function()
                local v = parseExpr()
                if pos <= len then error("sintaks") end
                return v
            end)

            if not ok or type(result) ~= "number" then return nil end
            if result ~= result or result == math.huge or result == -math.huge then
                return nil
            end
            return result
        end

        -- Angka -> teks tanpa notasi ilmiah (supaya bisa dilanjutkan).
        local function formatNumber(n)
            if n == 0 then return "0" end
            if math.abs(n) >= 1e15 then return nil end

            local s = string.format("%.12g", n)
            if s:find("e") then
                if math.abs(n) >= 1 then
                    s = string.format("%.0f", n)
                else
                    s = string.format("%.10f", n)
                    s = s:gsub("0+$", "")
                    s = s:gsub("%.$", "")
                end
            end
            if s == "-0" or s == "" or s == "-" then s = "0" end
            return s
        end

        ----------------------------------------------
        -- Halaman kalkulator (muat di menu 220x300)
        ----------------------------------------------
        local calcPage = newPage("ZaqiCalculatorPage", false)

        local calcBack = Instance.new("TextButton")
        calcBack.Size = UDim2.fromOffset(78, 24)
        calcBack.Position = UDim2.fromOffset(6, 5)
        calcBack.Parent = calcPage
        styleButton(calcBack, "⬅️ Kembali", Color3.fromRGB(70, 70, 70), 12)

        local calcTitle = Instance.new("TextLabel")
        calcTitle.Size = UDim2.fromOffset(104, 24)
        calcTitle.Position = UDim2.fromOffset(90, 5)
        calcTitle.BackgroundTransparency = 1
        calcTitle.Text = "🧮 Kalkulator"
        calcTitle.TextColor3 = Color3.fromRGB(255, 230, 0)
        calcTitle.TextSize = 13
        calcTitle.Font = Enum.Font.GothamBold
        calcTitle.TextXAlignment = Enum.TextXAlignment.Left
        calcTitle.ZIndex = 21
        calcTitle.Parent = calcPage

        local displayFrame = Instance.new("Frame")
        displayFrame.Size = UDim2.fromOffset(188, 44)
        displayFrame.Position = UDim2.fromOffset(6, 33)
        displayFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
        displayFrame.BorderSizePixel = 0
        displayFrame.ZIndex = 21
        displayFrame.Parent = calcPage
        Instance.new("UICorner", displayFrame).CornerRadius = UDim.new(0, 6)

        local historyLabel = Instance.new("TextLabel")
        historyLabel.Size = UDim2.new(1, -10, 0, 14)
        historyLabel.Position = UDim2.fromOffset(5, 2)
        historyLabel.BackgroundTransparency = 1
        historyLabel.Text = ""
        historyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        historyLabel.TextSize = 11
        historyLabel.Font = Enum.Font.Gotham
        historyLabel.TextXAlignment = Enum.TextXAlignment.Right
        historyLabel.ZIndex = 22
        historyLabel.Parent = displayFrame

        local mainLabel = Instance.new("TextLabel")
        mainLabel.Size = UDim2.new(1, -10, 0, 26)
        mainLabel.Position = UDim2.fromOffset(5, 16)
        mainLabel.BackgroundTransparency = 1
        mainLabel.Text = "0"
        mainLabel.TextColor3 = Color3.new(1, 1, 1)
        mainLabel.TextSize = 22
        mainLabel.TextScaled = true
        mainLabel.Font = Enum.Font.GothamBold
        mainLabel.TextXAlignment = Enum.TextXAlignment.Right
        mainLabel.ZIndex = 22
        mainLabel.Parent = displayFrame

        local sizeLimit = Instance.new("UITextSizeConstraint")
        sizeLimit.MaxTextSize = 22
        sizeLimit.MinTextSize = 9
        sizeLimit.Parent = mainLabel

        -- Keadaan kalkulator
        local expr = ""
        local historyText = ""
        local justEvaluated = false
        local errorShown = false

        local function toDisplay(s)
            s = s:gsub("%*", "×")
            s = s:gsub("/", "÷")
            return s
        end

        local function refreshDisplay()
            if errorShown then
                mainLabel.Text = "Error"
            elseif expr == "" then
                mainLabel.Text = "0"
            else
                local shown = expr
                if #shown > 24 then
                    shown = ".." .. shown:sub(-22)
                end
                mainLabel.Text = toDisplay(shown)
            end
            historyLabel.Text = historyText
        end

        local function clearAll()
            expr = ""
            historyText = ""
            justEvaluated = false
            errorShown = false
        end

        -- Mulai ketikan angka baru setelah "=" atau Error.
        local function beginTyping()
            if errorShown or justEvaluated then
                clearAll()
            end
        end

        local function lastToken()
            return expr:match("[%d%.]*$")
        end

        local function pressDigit(d)
            beginTyping()
            if #expr >= MAX_LEN then return end
            if expr:sub(-1) == "%" then return end

            local tok = lastToken()
            if tok == "0" then
                expr = expr:sub(1, -2)       -- hindari 007
            elseif #tok >= MAX_DIGITS then
                return
            end
            expr = expr .. d
        end

        local function pressDot()
            beginTyping()
            if #expr >= MAX_LEN then return end
            if expr:sub(-1) == "%" then return end

            local tok = lastToken()
            if tok:find("%.") then return end
            if tok == "" then
                expr = expr .. "0."
            else
                expr = expr .. "."
            end
        end

        local function pressOperator(op)
            if errorShown then return end
            if justEvaluated then
                justEvaluated = false
                historyText = ""
            end

            -- Buang titik/operator di ujung (ganti operator lama).
            if expr:sub(-1) == "." then
                expr = expr:sub(1, -2)
            end
            expr = expr:gsub("[%+%-%*/]+$", "")

            if expr == "" then
                if op == "-" then expr = "-" end   -- angka negatif di awal
                return
            end
            if #expr >= MAX_LEN then return end
            expr = expr .. op
        end

        local function pressPercent()
            if errorShown then return end
            if not (expr:match("%d$") or expr:match("%%$")) then return end
            if #expr >= MAX_LEN then return end
            if justEvaluated then
                justEvaluated = false
                historyText = ""
            end
            expr = expr .. "%"
        end

        local function pressSign()
            if errorShown then return end
            local s = expr:find("[%d%.]+%%*$")
            if not s then return end

            local before = expr:sub(s - 1, s - 1)
            local before2 = expr:sub(s - 2, s - 2)

            if before == "-" and (s - 1 == 1 or OPS[before2]) then
                expr = expr:sub(1, s - 2) .. expr:sub(s)             -- -5 -> 5
            elseif before == "-" then
                expr = expr:sub(1, s - 2) .. "+" .. expr:sub(s)      -- 5-3 -> 5+3
            elseif before == "+" then
                expr = expr:sub(1, s - 2) .. "-" .. expr:sub(s)      -- 5+3 -> 5-3
            else
                expr = expr:sub(1, s - 1) .. "-" .. expr:sub(s)      -- 5 -> -5
            end
        end

        local function pressBackspace()
            if errorShown then
                clearAll()
                return
            end
            if justEvaluated then
                justEvaluated = false
                historyText = ""
            end
            expr = expr:sub(1, -2)
        end

        local function pressEquals()
            if errorShown or justEvaluated or expr == "" then return end

            local e = expr:gsub("[%+%-%*/%.]+$", "")
            if e == "" then return end

            local value = evaluate(e)
            local text = value ~= nil and formatNumber(value) or nil

            historyText = toDisplay(e) .. " ="
            if #historyText > 26 then
                historyText = ".." .. historyText:sub(-24)
            end

            if text == nil then
                expr = ""
                errorShown = true
            else
                expr = text
                justEvaluated = true
            end
        end

        -- Susunan tombol (4 kolom x 5 baris)
        local rows = {
            { "C",  "DEL", "%", "÷" },
            { "7",  "8",   "9", "×" },
            { "4",  "5",   "6", "-" },
            { "1",  "2",   "3", "+" },
            { "±",  "0",   ".", "=" },
        }

        local function press(label)
            if label == "C" then
                clearAll()
            elseif label == "DEL" then
                pressBackspace()
            elseif label == "%" then
                pressPercent()
            elseif label == "÷" then
                pressOperator("/")
            elseif label == "×" then
                pressOperator("*")
            elseif label == "-" or label == "+" then
                pressOperator(label)
            elseif label == "=" then
                pressEquals()
            elseif label == "±" then
                pressSign()
            elseif label == "." then
                pressDot()
            else
                pressDigit(label)
            end
            refreshDisplay()
        end

        local BTN_W, BTN_H, GAP = 44, 28, 3
        local GRID_X, GRID_Y = 6, 82

        for r, row in ipairs(rows) do
            for c, label in ipairs(row) do
                local color = Color3.fromRGB(62, 62, 62)
                if label == "C" then
                    color = Color3.fromRGB(190, 60, 60)
                elseif label == "=" then
                    color = Color3.fromRGB(0, 150, 75)
                elseif label == "÷" or label == "×" or label == "-" or label == "+" then
                    color = Color3.fromRGB(215, 130, 0)
                elseif label == "DEL" or label == "%" or label == "±" then
                    color = Color3.fromRGB(85, 85, 95)
                end

                local b = Instance.new("TextButton")
                b.Name = "Calc_" .. label
                b.Size = UDim2.fromOffset(BTN_W, BTN_H)
                b.Position = UDim2.fromOffset(
                    GRID_X + (c - 1) * (BTN_W + 4),
                    GRID_Y + (r - 1) * (BTN_H + GAP)
                )
                b.Parent = calcPage
                styleButton(b, label, color, (label == "DEL") and 11 or 15)

                b.MouseButton1Click:Connect(function()
                    press(label)
                end)
            end
        end

        refreshDisplay()

        ----------------------------------------------
        -- MUSIK (dulu tombol "Boombox" di menu utama)
        -- Tombol dipindah ke daftar Tools; halamannya tetap sama.
        ----------------------------------------------
        boomboxButton.Parent = toolsPage
        boomboxButton.LayoutOrder = 11
        boomboxButton.Text = "🎵 Musik"
        boomboxButton.TextSize = 13
        boomboxButton.Font = Enum.Font.GothamBold
        boomboxButton.ZIndex = 21

        ----------------------------------------------
        -- CATATAN (gaya aplikasi catatan Android)
        -- Daftar kartu + cari + tombol "+" ; ketuk kartu untuk edit.
        -- Tersimpan otomatis ke file ZaqiNotes.json (writefile) dan
        -- cadangan di getgenv, jadi tetap ada setelah menu ditutup /
        -- script dijalankan ulang.
        ----------------------------------------------
        local notesOpenButton = Instance.new("TextButton")
        notesOpenButton.Size = UDim2.new(1, 0, 0, 35)
        notesOpenButton.LayoutOrder = 12
        notesOpenButton.Parent = toolsPage
        styleButton(notesOpenButton, "📝 Catatan", Color3.fromRGB(55, 55, 55))

        local HttpService = game:GetService("HttpService")
        local NOTES_FILE = "ZaqiNotes.json"
        local NOTE_CARD = Color3.fromRGB(52, 52, 58)
        local NOTE_CARD_PIN = Color3.fromRGB(70, 62, 36)
        local NOTE_FIELD = Color3.fromRGB(45, 45, 50)
        local NOTE_ACCENT = Color3.fromRGB(255, 200, 0)
        local NOTE_GRAY = Color3.fromRGB(70, 70, 70)

        local notes = {}
        local nextNoteId = 1

        local function saveNotes()
            local out = {}
            for _, n in ipairs(notes) do
                table.insert(out, {
                    title = n.title, body = n.body,
                    time = n.time, pinned = n.pinned,
                })
            end
            local okJson, json = pcall(function()
                return HttpService:JSONEncode(out)
            end)
            if not okJson then return false end

            local savedToFile = false
            pcall(function()
                if writefile then
                    writefile(NOTES_FILE, json)
                    savedToFile = true
                end
            end)
            pcall(function()
                local env = getgenv and getgenv()
                if env then env.ZaqiNotesCache = json end
            end)
            return savedToFile
        end

        do
            local raw
            pcall(function()
                if isfile and readfile and isfile(NOTES_FILE) then
                    raw = readfile(NOTES_FILE)
                end
            end)
            if not raw then
                pcall(function()
                    local env = getgenv and getgenv()
                    if env and type(env.ZaqiNotesCache) == "string" then
                        raw = env.ZaqiNotesCache
                    end
                end)
            end
            if raw then
                local ok, data = pcall(function()
                    return HttpService:JSONDecode(raw)
                end)
                if ok and type(data) == "table" then
                    for _, n in ipairs(data) do
                        if type(n) == "table" then
                            local t = tostring(n.title or "")
                            local b = tostring(n.body or "")
                            if t ~= "" or b ~= "" then
                                table.insert(notes, {
                                    id = nextNoteId,
                                    title = t, body = b,
                                    time = tonumber(n.time) or os.time(),
                                    pinned = n.pinned == true,
                                })
                                nextNoteId = nextNoteId + 1
                            end
                        end
                    end
                end
            end
        end

        local function fmtDate(t)
            local ok, s = pcall(os.date, "%d/%m %H:%M", t)
            return ok and s or ""
        end

        local function newLabel(parent, props)
            local l = Instance.new("TextLabel")
            l.BackgroundTransparency = 1
            l.ZIndex = 22
            l.Font = Enum.Font.Gotham
            l.TextColor3 = Color3.new(1, 1, 1)
            l.TextXAlignment = Enum.TextXAlignment.Left
            for k, v in pairs(props) do l[k] = v end
            l.Parent = parent
            return l
        end

        local function newTopButton(parent, x, w, text)
            local b = Instance.new("TextButton")
            b.Position = UDim2.fromOffset(x, 5)
            b.Size = UDim2.fromOffset(w, 24)
            b.Parent = parent
            styleButton(b, text, NOTE_GRAY, 14)
            return b
        end

        ----------------------------------------------
        -- Halaman daftar catatan
        ----------------------------------------------
        local notesPage = newPage("ZaqiNotesPage", false)

        local notesBack = newTopButton(notesPage, 6, 34, "←")
        newLabel(notesPage, {
            Position = UDim2.fromOffset(46, 5), Size = UDim2.fromOffset(100, 24),
            Text = "📝 Catatan", TextColor3 = Color3.fromRGB(255, 230, 0),
            TextSize = 14, Font = Enum.Font.GothamBold,
        })
        local countLabel = newLabel(notesPage, {
            Position = UDim2.fromOffset(146, 5), Size = UDim2.fromOffset(48, 24),
            Text = "0", TextColor3 = Color3.fromRGB(150, 150, 150),
            TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right,
        })

        local searchBox = Instance.new("TextBox")
        searchBox.Position = UDim2.fromOffset(6, 34)
        searchBox.Size = UDim2.fromOffset(188, 26)
        searchBox.BackgroundColor3 = NOTE_FIELD
        searchBox.TextColor3 = Color3.new(1, 1, 1)
        searchBox.PlaceholderText = "🔍 Cari catatan..."
        searchBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
        searchBox.Text = ""
        searchBox.TextSize = 12
        searchBox.Font = Enum.Font.Gotham
        searchBox.TextXAlignment = Enum.TextXAlignment.Left
        searchBox.ClearTextOnFocus = false
        searchBox.ZIndex = 21
        searchBox.Parent = notesPage
        Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 13)
        local searchPad = Instance.new("UIPadding", searchBox)
        searchPad.PaddingLeft = UDim.new(0, 10)
        searchPad.PaddingRight = UDim.new(0, 10)

        local listFrame = Instance.new("ScrollingFrame")
        listFrame.Position = UDim2.fromOffset(6, 66)
        listFrame.Size = UDim2.new(1, -12, 1, -70)
        listFrame.BackgroundTransparency = 1
        listFrame.BorderSizePixel = 0
        listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        listFrame.ScrollBarThickness = 3
        listFrame.ScrollingDirection = Enum.ScrollingDirection.Y
        listFrame.ZIndex = 21
        listFrame.Parent = notesPage
        local listLayoutN = Instance.new("UIListLayout", listFrame)
        listLayoutN.SortOrder = Enum.SortOrder.LayoutOrder
        listLayoutN.Padding = UDim.new(0, 5)
        local listPadN = Instance.new("UIPadding", listFrame)
        listPadN.PaddingBottom = UDim.new(0, 52) -- ruang untuk tombol +
        listPadN.PaddingRight = UDim.new(0, 4)

        local emptyLabel = newLabel(notesPage, {
            Position = UDim2.fromOffset(10, 95), Size = UDim2.new(1, -20, 0, 60),
            Text = "", TextSize = 12, TextWrapped = true,
            TextColor3 = Color3.fromRGB(150, 150, 150),
            TextXAlignment = Enum.TextXAlignment.Center,
        })

        local fab = Instance.new("TextButton")
        fab.Size = UDim2.fromOffset(40, 40)
        fab.Position = UDim2.new(1, -50, 1, -50)
        fab.BackgroundColor3 = NOTE_ACCENT
        fab.TextColor3 = Color3.fromRGB(20, 20, 20)
        fab.Text = "+"
        fab.TextSize = 26
        fab.Font = Enum.Font.GothamBold
        fab.ZIndex = 25
        fab.Parent = notesPage
        Instance.new("UICorner", fab).CornerRadius = UDim.new(1, 0)

        -- Snackbar "Catatan dihapus • URUNGKAN" (seperti Android)
        local snack = Instance.new("Frame")
        snack.Position = UDim2.new(0, 6, 1, -44)
        snack.Size = UDim2.fromOffset(134, 34)
        snack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        snack.BorderSizePixel = 0
        snack.Visible = false
        snack.ZIndex = 30
        snack.Parent = notesPage
        Instance.new("UICorner", snack).CornerRadius = UDim.new(0, 8)
        newLabel(snack, {
            Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(60, 34),
            Text = "Dihapus", TextSize = 11, ZIndex = 31,
        })
        local undoBtn = Instance.new("TextButton")
        undoBtn.Position = UDim2.fromOffset(64, 0)
        undoBtn.Size = UDim2.fromOffset(68, 34)
        undoBtn.BackgroundTransparency = 1
        undoBtn.Text = "URUNGKAN"
        undoBtn.TextColor3 = NOTE_ACCENT
        undoBtn.TextSize = 10
        undoBtn.Font = Enum.Font.GothamBold
        undoBtn.ZIndex = 31
        undoBtn.Parent = snack

        ----------------------------------------------
        -- Halaman editor
        ----------------------------------------------
        local noteEditor = newPage("ZaqiNoteEditorPage", false)

        local edBack = newTopButton(noteEditor, 6, 34, "←")
        local edStatus = newLabel(noteEditor, {
            Position = UDim2.fromOffset(44, 5), Size = UDim2.fromOffset(74, 24),
            Text = "", TextSize = 10, TextColor3 = Color3.fromRGB(150, 150, 150),
        })
        local edPin = newTopButton(noteEditor, 120, 34, "📌")
        local edDelete = newTopButton(noteEditor, 160, 34, "🗑️")

        local edTitle = Instance.new("TextBox")
        edTitle.Position = UDim2.fromOffset(6, 34)
        edTitle.Size = UDim2.fromOffset(188, 28)
        edTitle.BackgroundColor3 = NOTE_FIELD
        edTitle.TextColor3 = Color3.new(1, 1, 1)
        edTitle.PlaceholderText = "Judul"
        edTitle.PlaceholderColor3 = Color3.fromRGB(130, 130, 130)
        edTitle.Text = ""
        edTitle.TextSize = 15
        edTitle.Font = Enum.Font.GothamBold
        edTitle.TextXAlignment = Enum.TextXAlignment.Left
        edTitle.ClearTextOnFocus = false
        edTitle.ZIndex = 21
        edTitle.Parent = noteEditor
        Instance.new("UICorner", edTitle).CornerRadius = UDim.new(0, 6)
        local edTitlePad = Instance.new("UIPadding", edTitle)
        edTitlePad.PaddingLeft = UDim.new(0, 8)
        edTitlePad.PaddingRight = UDim.new(0, 8)

        local edScroll = Instance.new("ScrollingFrame")
        edScroll.Position = UDim2.fromOffset(6, 66)
        edScroll.Size = UDim2.new(1, -12, 1, -72)
        edScroll.BackgroundColor3 = NOTE_FIELD
        edScroll.BorderSizePixel = 0
        edScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        edScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        edScroll.ScrollBarThickness = 3
        edScroll.ScrollingDirection = Enum.ScrollingDirection.Y
        edScroll.ZIndex = 21
        edScroll.Parent = noteEditor
        Instance.new("UICorner", edScroll).CornerRadius = UDim.new(0, 6)

        local edBody = Instance.new("TextBox")
        edBody.Size = UDim2.new(1, 0, 0, 166)
        edBody.AutomaticSize = Enum.AutomaticSize.Y
        edBody.BackgroundTransparency = 1
        edBody.TextColor3 = Color3.new(1, 1, 1)
        edBody.PlaceholderText = "Tulis catatan..."
        edBody.PlaceholderColor3 = Color3.fromRGB(130, 130, 130)
        edBody.Text = ""
        edBody.TextSize = 13
        edBody.Font = Enum.Font.Gotham
        edBody.TextXAlignment = Enum.TextXAlignment.Left
        edBody.TextYAlignment = Enum.TextYAlignment.Top
        edBody.TextWrapped = true
        edBody.MultiLine = true
        edBody.ClearTextOnFocus = false
        edBody.ZIndex = 22
        edBody.Parent = edScroll
        local edBodyPad = Instance.new("UIPadding", edBody)
        edBodyPad.PaddingTop = UDim.new(0, 6)
        edBodyPad.PaddingBottom = UDim.new(0, 6)
        edBodyPad.PaddingLeft = UDim.new(0, 8)
        edBodyPad.PaddingRight = UDim.new(0, 8)

        ----------------------------------------------
        -- Logika catatan
        ----------------------------------------------
        local current = nil      -- catatan yang sedang diedit
        local saveToken = 0
        local snackNote, snackToken = nil, 0
        local refreshList

        local function sortedNotes(filter)
            local list = {}
            for _, n in ipairs(notes) do
                if filter == "" or (n.title .. "\n" .. n.body):lower():find(filter, 1, true) then
                    table.insert(list, n)
                end
            end
            table.sort(list, function(a, b)
                if a.pinned ~= b.pinned then return a.pinned end
                if a.time ~= b.time then return a.time > b.time end
                return a.id > b.id
            end)
            return list
        end

        local function setPinLook()
            edPin.BackgroundColor3 = (current and current.pinned) and Color3.fromRGB(150, 115, 0) or NOTE_GRAY
        end

        local function commit()
            if not current then return end
            local t, b = edTitle.Text, edBody.Text
            if t ~= current.title or b ~= current.body then
                current.title, current.body = t, b
                current.time = os.time()
            end
            edStatus.Text = saveNotes() and "✓ Tersimpan" or "⚠️ Sementara"
        end

        local function scheduleSave()
            if not current then return end
            if edTitle.Text == current.title and edBody.Text == current.body then return end
            edStatus.Text = "…"
            saveToken = saveToken + 1
            local my = saveToken
            task.delay(0.7, function()
                if my == saveToken and current then commit() end
            end)
        end
        edTitle:GetPropertyChangedSignal("Text"):Connect(scheduleSave)
        edBody:GetPropertyChangedSignal("Text"):Connect(function()
            scheduleSave()
            -- Ikuti kursor saat mengetik di baris paling bawah.
            if edBody:IsFocused() and edBody.CursorPosition > #edBody.Text then
                task.defer(function()
                    local maxY = math.max(0, edScroll.AbsoluteCanvasSize.Y - edScroll.AbsoluteWindowSize.Y)
                    edScroll.CanvasPosition = Vector2.new(0, maxY)
                end)
            end
        end)
        edTitle.FocusLost:Connect(function(enter)
            if enter then edBody:CaptureFocus() end
        end)

        -- Selesaikan editor: simpan, atau buang jika catatan kosong.
        local function finalizeEditor()
            if not current then return end
            saveToken = saveToken + 1
            if edTitle.Text == "" and edBody.Text == "" then
                local idx = table.find(notes, current)
                if idx then table.remove(notes, idx) end
                saveNotes()
            else
                commit()
            end
            current = nil
        end

        local function openEditor(n)
            current = n
            edTitle.Text = n.title
            edBody.Text = n.body
            edStatus.Text = ""
            edScroll.CanvasPosition = Vector2.new(0, 0)
            setPinLook()
            notesPage.Visible = false
            noteEditor.Visible = true
        end

        local function showSnack(n)
            snackNote = n
            snackToken = snackToken + 1
            local my = snackToken
            snack.Visible = true
            task.delay(4, function()
                if my == snackToken then
                    snack.Visible = false
                    snackNote = nil
                end
            end)
        end

        refreshList = function()
            for _, c in ipairs(listFrame:GetChildren()) do
                if c:IsA("GuiButton") then c:Destroy() end
            end
            local items = sortedNotes(searchBox.Text:lower())
            for i, n in ipairs(items) do
                local card = Instance.new("TextButton")
                card.Size = UDim2.new(1, 0, 0, 62)
                card.LayoutOrder = i
                card.BackgroundColor3 = n.pinned and NOTE_CARD_PIN or NOTE_CARD
                card.AutoButtonColor = true
                card.Text = ""
                card.ZIndex = 21
                card.Parent = listFrame
                Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

                newLabel(card, {
                    Position = UDim2.fromOffset(8, 5), Size = UDim2.new(1, -30, 0, 16),
                    Text = n.title ~= "" and n.title or "Tanpa judul",
                    TextSize = 12, Font = Enum.Font.GothamBold,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                })
                newLabel(card, {
                    Position = UDim2.fromOffset(8, 21), Size = UDim2.new(1, -16, 0, 26),
                    Text = (n.body:gsub("%s+", " ")),
                    TextSize = 10, TextColor3 = Color3.fromRGB(170, 170, 170),
                    TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                })
                newLabel(card, {
                    Position = UDim2.fromOffset(8, 47), Size = UDim2.new(1, -16, 0, 12),
                    Text = fmtDate(n.time), TextSize = 9,
                    TextColor3 = Color3.fromRGB(120, 120, 120),
                })
                if n.pinned then
                    newLabel(card, {
                        Position = UDim2.new(1, -22, 0, 4), Size = UDim2.fromOffset(18, 16),
                        Text = "📌", TextSize = 11,
                    })
                end

                card.MouseButton1Click:Connect(function()
                    openEditor(n)
                end)
            end
            countLabel.Text = tostring(#notes)
            emptyLabel.Visible = #items == 0
            emptyLabel.Text = #notes == 0
                and "Belum ada catatan\nKetuk tombol + untuk membuat"
                or "Tidak ditemukan"
        end

        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            refreshList()
        end)

        fab.MouseButton1Click:Connect(function()
            local n = {
                id = nextNoteId, title = "", body = "",
                time = os.time(), pinned = false,
            }
            nextNoteId = nextNoteId + 1
            table.insert(notes, n)
            snack.Visible = false
            openEditor(n)
            task.defer(function()
                if current == n then edTitle:CaptureFocus() end
            end)
        end)

        edBack.MouseButton1Click:Connect(function()
            finalizeEditor()
            noteEditor.Visible = false
            notesPage.Visible = true
            refreshList()
        end)

        edPin.MouseButton1Click:Connect(function()
            if not current then return end
            current.pinned = not current.pinned
            setPinLook()
            commit()
        end)

        edDelete.MouseButton1Click:Connect(function()
            if not current then return end
            local n = current
            saveToken = saveToken + 1
            current = nil
            local idx = table.find(notes, n)
            if idx then table.remove(notes, idx) end
            saveNotes()
            noteEditor.Visible = false
            notesPage.Visible = true
            refreshList()
            if n.title ~= "" or n.body ~= "" then showSnack(n) end
        end)

        undoBtn.MouseButton1Click:Connect(function()
            if snackNote then
                table.insert(notes, snackNote)
                snackNote = nil
                snackToken = snackToken + 1
                snack.Visible = false
                saveNotes()
                refreshList()
            end
        end)

        refreshList()

        ----------------------------------------------
        -- WHEEL SPIN & DICE ROLLER
        -- Dua aplikasi baru di daftar Tools.
        -- Dibungkus fungsi sendiri agar tidak menambah variabel local
        -- di fungsi Tools. Mengembalikan fungsi untuk menyembunyikan
        -- kedua halaman (dipakai oleh hideAllToolPages).
        ----------------------------------------------
        local hideLuckTools = (function()
            local TweenService = game:GetService("TweenService")
            local rng = Random.new()

            local GRAY_BTN = Color3.fromRGB(70, 70, 70)
            local GREEN_BTN = Color3.fromRGB(0, 150, 75)
            local GOLD = Color3.fromRGB(255, 230, 0)

            local function newBtn(parent, x, y, w, h, text, color, size)
                local b = Instance.new("TextButton")
                b.Position = UDim2.fromOffset(x, y)
                b.Size = UDim2.fromOffset(w, h)
                b.Parent = parent
                styleButton(b, text, color, size or 13)
                return b
            end

            local function newOpenButton(order, text)
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, 0, 0, 35)
                b.LayoutOrder = order
                b.Parent = toolsPage
                styleButton(b, text, Color3.fromRGB(55, 55, 55))
                return b
            end

            local wheelOpenButton = newOpenButton(13, "🎡 Wheel Spin")
            local diceOpenButton = newOpenButton(14, "🎲 Dice Roller")

            --------------------------------------------
            -- WHEEL SPIN
            -- Roda dibuat dari "jari-jari" tipis berwarna (satu juring
            -- = banyak jari-jari), lalu seluruh roda diputar dengan Tween.
            -- Pilihan pemenang ditentukan acak lebih dulu, lalu roda
            -- diputar sampai juring itu tepat di bawah panah (atas).
            --------------------------------------------
            local WHEEL_R = 64
            local WHEEL_MAX = 12
            local WHEEL_COLORS = {
                Color3.fromRGB(46, 160, 90),   -- hijau
                Color3.fromRGB(205, 65, 65),   -- merah
                Color3.fromRGB(60, 120, 215),  -- biru
                Color3.fromRGB(230, 170, 30),  -- kuning
                Color3.fromRGB(150, 80, 200),  -- ungu
                Color3.fromRGB(235, 120, 40),  -- oranye
                Color3.fromRGB(40, 170, 185),  -- toska
                Color3.fromRGB(215, 90, 150),  -- pink
                Color3.fromRGB(110, 170, 50),  -- lime
                Color3.fromRGB(125, 95, 70),   -- cokelat
                Color3.fromRGB(80, 90, 200),   -- indigo
                Color3.fromRGB(150, 150, 160), -- abu
            }

            local DEFAULT_OPTIONS = { "Yes", "No" }
            local options = { table.unpack(DEFAULT_OPTIONS) }

            local function clipText(s, n)
                local len = utf8.len(s)
                if len and len > n then
                    return s:sub(1, utf8.offset(s, n + 1) - 1) .. "…"
                end
                return s
            end

            local wheelPage = newPage("ZaqiWheelPage", false)

            -- Dua tampilan: roda (utama) dan editor pilihan.
            local wheelView = Instance.new("Frame")
            wheelView.Position = UDim2.fromOffset(0, 34)
            wheelView.Size = UDim2.new(1, 0, 1, -34)
            wheelView.BackgroundTransparency = 1
            wheelView.ZIndex = 21
            wheelView.Parent = wheelPage

            local editView = Instance.new("Frame")
            editView.Position = UDim2.fromOffset(0, 34)
            editView.Size = UDim2.new(1, 0, 1, -34)
            editView.BackgroundTransparency = 1
            editView.ZIndex = 21
            editView.Visible = false
            editView.Parent = wheelPage

            local wheelBack = newBtn(wheelPage, 6, 5, 78, 24, "⬅️ Kembali", GRAY_BTN, 12)
            newLabel(wheelPage, {
                Position = UDim2.fromOffset(90, 5), Size = UDim2.fromOffset(104, 24),
                Text = "🎡 Wheel Spin", TextColor3 = GOLD,
                TextSize = 13, Font = Enum.Font.GothamBold,
            })

            -- Roda (berputar)
            local wheel = Instance.new("Frame")
            wheel.Name = "Wheel"
            wheel.AnchorPoint = Vector2.new(0.5, 0.5)
            wheel.Position = UDim2.fromOffset(100, 86)
            wheel.Size = UDim2.fromOffset(WHEEL_R * 2, WHEEL_R * 2)
            wheel.BackgroundTransparency = 1
            wheel.ZIndex = 21
            wheel.Parent = wheelView

            -- Bingkai luar (diam)
            local rim = Instance.new("Frame")
            rim.AnchorPoint = Vector2.new(0.5, 0.5)
            rim.Position = UDim2.fromOffset(100, 86)
            rim.Size = UDim2.fromOffset(WHEEL_R * 2 + 4, WHEEL_R * 2 + 4)
            rim.BackgroundTransparency = 1
            rim.ZIndex = 25
            rim.Parent = wheelView
            Instance.new("UICorner", rim).CornerRadius = UDim.new(0.5, 0)
            local rimStroke = Instance.new("UIStroke")
            rimStroke.Thickness = 3
            rimStroke.Color = Color3.fromRGB(240, 240, 240)
            rimStroke.Parent = rim

            -- Poros tengah (diam)
            local hub = Instance.new("Frame")
            hub.AnchorPoint = Vector2.new(0.5, 0.5)
            hub.Position = UDim2.fromOffset(100, 86)
            hub.Size = UDim2.fromOffset(16, 16)
            hub.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            hub.BorderSizePixel = 0
            hub.ZIndex = 26
            hub.Parent = wheelView
            Instance.new("UICorner", hub).CornerRadius = UDim.new(0.5, 0)
            local hubStroke = Instance.new("UIStroke")
            hubStroke.Thickness = 2
            hubStroke.Color = Color3.fromRGB(240, 240, 240)
            hubStroke.Parent = hub

            -- Panah penunjuk (di atas roda)
            newLabel(wheelView, {
                Position = UDim2.fromOffset(88, 1), Size = UDim2.fromOffset(24, 22),
                Text = "▼", TextColor3 = Color3.fromRGB(255, 70, 70),
                TextSize = 20, Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextStrokeTransparency = 0.3, ZIndex = 27,
            })

            local function placeSpoke(parent, angleDeg, length, thick, color, z)
                local r = math.rad(angleDeg)
                local half = length / 2
                local spoke = Instance.new("Frame")
                spoke.AnchorPoint = Vector2.new(0.5, 0.5)
                spoke.Size = UDim2.fromOffset(length, thick)
                spoke.Position = UDim2.fromOffset(
                    WHEEL_R + half * math.sin(r),
                    WHEEL_R - half * math.cos(r)
                )
                spoke.Rotation = angleDeg - 90
                spoke.BackgroundColor3 = color
                spoke.BorderSizePixel = 0
                spoke.ZIndex = z
                spoke.Parent = parent
                return spoke
            end

            local function buildWheel()
                wheel:ClearAllChildren()
                wheel.Rotation = 0

                local n = #options
                local sweep = 360 / n

                for i = 1, n do
                    local color = WHEEL_COLORS[(i - 1) % #WHEEL_COLORS + 1]
                    local steps = math.max(1, math.ceil(sweep / 2))
                    local stepDeg = sweep / steps
                    local thick = WHEEL_R * math.rad(stepDeg) + 2
                    for k = 0, steps - 1 do
                        local a = (i - 1) * sweep + (k + 0.5) * stepDeg
                        placeSpoke(wheel, a, WHEEL_R, thick, color, 22)
                    end
                end

                -- Garis pemisah antar juring
                for i = 1, n do
                    placeSpoke(wheel, (i - 1) * sweep, WHEEL_R, 1.5,
                        Color3.fromRGB(25, 25, 25), 23)
                end

                -- Tulisan tiap juring (searah jari-jari)
                for i = 1, n do
                    local mid = (i - 0.5) * sweep
                    local r = math.rad(mid)
                    local dist = WHEEL_R * 0.6
                    local arc = 2 * math.pi * dist * (sweep / 360)

                    local lbl = Instance.new("TextLabel")
                    lbl.AnchorPoint = Vector2.new(0.5, 0.5)
                    lbl.Size = UDim2.fromOffset(WHEEL_R * 0.66, math.clamp(arc * 0.8, 9, 16))
                    lbl.Position = UDim2.fromOffset(
                        WHEEL_R + dist * math.sin(r),
                        WHEEL_R - dist * math.cos(r)
                    )
                    lbl.Rotation = (mid <= 180) and (mid - 90) or (mid - 270)
                    lbl.BackgroundTransparency = 1
                    lbl.Text = clipText(options[i], 12)
                    lbl.TextColor3 = Color3.new(1, 1, 1)
                    lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
                    lbl.TextStrokeTransparency = 0.4
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextScaled = true
                    lbl.ZIndex = 24
                    lbl.Parent = wheel
                    local cons = Instance.new("UITextSizeConstraint")
                    cons.MaxTextSize = 13
                    cons.MinTextSize = 5
                    cons.Parent = lbl
                end
            end

            local wheelResult = newLabel(wheelView, {
                Position = UDim2.fromOffset(6, 153), Size = UDim2.fromOffset(188, 20),
                Text = "Tekan PUTAR!", TextColor3 = Color3.fromRGB(200, 200, 200),
                TextSize = 13, Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })

            local spinButton = newBtn(wheelView, 6, 177, 118, 28, "🎡 PUTAR", GREEN_BTN, 14)
            local editButton = newBtn(wheelView, 130, 177, 64, 28, "✏️ Edit", GRAY_BTN, 12)

            local spinning = false

            spinButton.MouseButton1Click:Connect(function()
                if spinning then return end
                local n = #options
                if n < 2 then return end

                spinning = true
                spinButton.Text = "⏳ Berputar..."
                spinButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
                wheelResult.Text = "..."
                wheelResult.TextColor3 = Color3.fromRGB(200, 200, 200)

                local sweep = 360 / n
                local winner = rng:NextInteger(1, n)
                local winnerName = options[winner]
                -- titik acak di dalam juring pemenang (hindari garis tepi)
                local point = (winner - 1) * sweep + sweep * (0.12 + 0.76 * rng:NextNumber())

                local cur = wheel.Rotation % 360
                wheel.Rotation = cur
                local finalMod = (360 - point) % 360
                local delta = (finalMod - cur) % 360
                local target = cur + delta + 360 * rng:NextInteger(5, 7)

                local finished = false
                local function finish()
                    if finished then return end
                    finished = true
                    wheelResult.Text = "🎯 " .. winnerName
                    wheelResult.TextColor3 = GOLD
                    spinButton.Text = "🎡 PUTAR"
                    spinButton.BackgroundColor3 = GREEN_BTN
                    spinning = false
                end

                local tween = TweenService:Create(
                    wheel,
                    TweenInfo.new(4.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                    { Rotation = target }
                )
                tween.Completed:Connect(finish)
                tween:Play()
                task.delay(5.5, finish) -- pengaman jika Completed tidak terpanggil
            end)

            -- Editor pilihan
            newLabel(editView, {
                Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(188, 26),
                Text = "Tulis pilihan: 1 per baris (atau pisahkan dengan koma). Maks " .. WHEEL_MAX .. ".",
                TextColor3 = Color3.fromRGB(170, 170, 170), TextSize = 10,
                TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
            })

            local edScroll = Instance.new("ScrollingFrame")
            edScroll.Position = UDim2.fromOffset(6, 28)
            edScroll.Size = UDim2.fromOffset(188, 116)
            edScroll.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
            edScroll.BorderSizePixel = 0
            edScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
            edScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
            edScroll.ScrollBarThickness = 3
            edScroll.ScrollingDirection = Enum.ScrollingDirection.Y
            edScroll.ZIndex = 21
            edScroll.Parent = editView
            Instance.new("UICorner", edScroll).CornerRadius = UDim.new(0, 6)

            local edBox = Instance.new("TextBox")
            edBox.Size = UDim2.new(1, 0, 0, 114)
            edBox.AutomaticSize = Enum.AutomaticSize.Y
            edBox.BackgroundTransparency = 1
            edBox.TextColor3 = Color3.new(1, 1, 1)
            edBox.PlaceholderText = "Yes\nNo"
            edBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 130)
            edBox.Text = ""
            edBox.TextSize = 13
            edBox.Font = Enum.Font.Gotham
            edBox.TextXAlignment = Enum.TextXAlignment.Left
            edBox.TextYAlignment = Enum.TextYAlignment.Top
            edBox.TextWrapped = true
            edBox.MultiLine = true
            edBox.ClearTextOnFocus = false
            edBox.ZIndex = 22
            edBox.Parent = edScroll
            local edPad = Instance.new("UIPadding", edBox)
            edPad.PaddingTop = UDim.new(0, 6)
            edPad.PaddingBottom = UDim.new(0, 6)
            edPad.PaddingLeft = UDim.new(0, 8)
            edPad.PaddingRight = UDim.new(0, 8)

            local edStatus = newLabel(editView, {
                Position = UDim2.fromOffset(6, 148), Size = UDim2.fromOffset(188, 16),
                Text = "", TextSize = 10, TextColor3 = Color3.fromRGB(255, 110, 110),
            })

            local edCancel = newBtn(editView, 6, 168, 56, 28, "✖ Batal", GRAY_BTN, 11)
            local edReset = newBtn(editView, 66, 168, 62, 28, "↩️ Reset", Color3.fromRGB(190, 110, 30), 11)
            local edSave = newBtn(editView, 132, 168, 62, 28, "✅ Simpan", GREEN_BTN, 11)

            local function showWheelView()
                editView.Visible = false
                wheelView.Visible = true
            end

            local function parseOptions(text)
                text = text:gsub("\r", ""):gsub("[,;]", "\n")
                local list = {}
                for line in (text .. "\n"):gmatch("([^\n]*)\n") do
                    local s = line:match("^%s*(.-)%s*$")
                    if s ~= "" then
                        table.insert(list, clipText(s, 40))
                    end
                end
                return list
            end

            local function applyOptions(list)
                options = list
                buildWheel()
                wheelResult.Text = "Tekan PUTAR!"
                wheelResult.TextColor3 = Color3.fromRGB(200, 200, 200)
            end

            editButton.MouseButton1Click:Connect(function()
                if spinning then return end
                edBox.Text = table.concat(options, "\n")
                edStatus.Text = ""
                wheelView.Visible = false
                editView.Visible = true
            end)

            edCancel.MouseButton1Click:Connect(showWheelView)

            edReset.MouseButton1Click:Connect(function()
                applyOptions({ table.unpack(DEFAULT_OPTIONS) })
                showWheelView()
            end)

            edSave.MouseButton1Click:Connect(function()
                local list = parseOptions(edBox.Text)
                if #list < 2 then
                    edStatus.Text = "⚠️ Minimal 2 pilihan."
                    return
                end
                while #list > WHEEL_MAX do
                    table.remove(list)
                end
                applyOptions(list)
                showWheelView()
            end)

            buildWheel()

            --------------------------------------------
            -- DICE ROLLER (satu dadu, angka 1-6)
            --------------------------------------------
            local dicePage = newPage("ZaqiDicePage", false)

            local diceBack = newBtn(dicePage, 6, 5, 78, 24, "⬅️ Kembali", GRAY_BTN, 12)
            newLabel(dicePage, {
                Position = UDim2.fromOffset(90, 5), Size = UDim2.fromOffset(104, 24),
                Text = "🎲 Dice Roller", TextColor3 = GOLD,
                TextSize = 13, Font = Enum.Font.GothamBold,
            })

            local die = Instance.new("Frame")
            die.Name = "Die"
            die.AnchorPoint = Vector2.new(0.5, 0.5)
            die.Position = UDim2.fromOffset(100, 90)
            die.Size = UDim2.fromOffset(90, 90)
            die.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
            die.BorderSizePixel = 0
            die.ZIndex = 21
            die.Parent = dicePage
            Instance.new("UICorner", die).CornerRadius = UDim.new(0, 14)
            local dieStroke = Instance.new("UIStroke")
            dieStroke.Thickness = 2
            dieStroke.Color = Color3.fromRGB(150, 150, 150)
            dieStroke.Parent = die

            local pips = {}
            for idx = 1, 9 do
                local row = math.floor((idx - 1) / 3)
                local col = (idx - 1) % 3
                local pip = Instance.new("Frame")
                pip.AnchorPoint = Vector2.new(0.5, 0.5)
                pip.Size = UDim2.fromOffset(16, 16)
                pip.Position = UDim2.new(0.22 + 0.28 * col, 0, 0.22 + 0.28 * row, 0)
                pip.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                pip.BorderSizePixel = 0
                pip.ZIndex = 22
                pip.Visible = false
                pip.Parent = die
                Instance.new("UICorner", pip).CornerRadius = UDim.new(0.5, 0)
                pips[idx] = pip
            end

            local dieQuestion = newLabel(die, {
                Size = UDim2.new(1, 0, 1, 0), Text = "?",
                TextColor3 = Color3.fromRGB(120, 120, 120),
                TextSize = 44, Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 22,
            })

            -- Posisi titik (1-9, kiri-ke-kanan, atas-ke-bawah) tiap angka
            local FACES = {
                [1] = { 5 },
                [2] = { 1, 9 },
                [3] = { 1, 5, 9 },
                [4] = { 1, 3, 7, 9 },
                [5] = { 1, 3, 5, 7, 9 },
                [6] = { 1, 3, 4, 6, 7, 9 },
            }

            local function showFace(v)
                for i = 1, 9 do
                    pips[i].Visible = false
                end
                for _, idx in ipairs(FACES[v]) do
                    pips[idx].Visible = true
                end
            end

            local diceResult = newLabel(dicePage, {
                Position = UDim2.fromOffset(6, 142), Size = UDim2.fromOffset(188, 26),
                Text = "Hasil: -", TextColor3 = GOLD,
                TextSize = 18, Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Center,
            })

            local diceHistory = newLabel(dicePage, {
                Position = UDim2.fromOffset(6, 170), Size = UDim2.fromOffset(188, 16),
                Text = "Riwayat: -", TextColor3 = Color3.fromRGB(150, 150, 150),
                TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })

            local rollButton = newBtn(dicePage, 6, 194, 188, 32, "🎲 LEMPAR DADU", GREEN_BTN, 14)

            local rolling = false
            local history = {}

            rollButton.MouseButton1Click:Connect(function()
                if rolling then return end
                rolling = true
                rollButton.Text = "🎲 Mengocok..."
                rollButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
                dieQuestion.Visible = false
                diceResult.Text = "Hasil: ..."

                local final = rng:NextInteger(1, 6)

                task.spawn(function()
                    pcall(function()
                        local last = 0
                        for i = 1, 14 do
                            local v
                            repeat
                                v = rng:NextInteger(1, 6)
                            until v ~= last
                            last = v
                            showFace(v)
                            die.Rotation = rng:NextInteger(-14, 14)
                            task.wait(0.03 + 0.014 * i) -- makin lama makin pelan
                        end

                        showFace(final)
                        die.Rotation = 0
                        local pop = TweenService:Create(
                            die,
                            TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                            { Size = UDim2.fromOffset(100, 100) }
                        )
                        pop:Play()
                        pop.Completed:Wait()
                        TweenService:Create(
                            die,
                            TweenInfo.new(0.12),
                            { Size = UDim2.fromOffset(90, 90) }
                        ):Play()
                    end)

                    -- Selalu selesai dengan hasil yang benar, walau animasi gagal.
                    showFace(final)
                    die.Rotation = 0
                    die.Size = UDim2.fromOffset(90, 90)
                    diceResult.Text = "Hasil: " .. final

                    table.insert(history, 1, final)
                    while #history > 8 do
                        table.remove(history)
                    end
                    local parts = {}
                    for _, v in ipairs(history) do
                        table.insert(parts, tostring(v))
                    end
                    diceHistory.Text = "Riwayat: " .. table.concat(parts, " • ")

                    rollButton.Text = "🎲 LEMPAR DADU"
                    rollButton.BackgroundColor3 = GREEN_BTN
                    rolling = false
                end)
            end)

            --------------------------------------------
            -- Navigasi kedua halaman
            --------------------------------------------
            wheelOpenButton.MouseButton1Click:Connect(function()
                toolsPage.Visible = false
                wheelPage.Visible = true
            end)

            wheelBack.MouseButton1Click:Connect(function()
                showWheelView()
                wheelPage.Visible = false
                toolsPage.Visible = true
            end)

            diceOpenButton.MouseButton1Click:Connect(function()
                toolsPage.Visible = false
                dicePage.Visible = true
            end)

            diceBack.MouseButton1Click:Connect(function()
                dicePage.Visible = false
                toolsPage.Visible = true
            end)

            return function()
                wheelPage.Visible = false
                dicePage.Visible = false
            end
        end)()

        ----------------------------------------------
        -- Navigasi halaman
        -- Menutup menu dengan "x" TIDAK mereset halaman: saat dibuka
        -- lagi, tetap di halaman terakhir (kalkulator, musik, catatan, wheel, dice).
        ----------------------------------------------
        local function hideAllToolPages()
            finalizeEditor()
            toolsPage.Visible = false
            calcPage.Visible = false
            boomboxPage.Visible = false
            notesPage.Visible = false
            noteEditor.Visible = false
            hideLuckTools()
        end

        local function showMain()
            hideAllToolPages()
            scroll.Visible = true
        end

        toolsButton.MouseButton1Click:Connect(function()
            hideAllToolPages()
            scroll.Visible = false
            toolsPage.Visible = true
        end)

        toolsBack.MouseButton1Click:Connect(showMain)

        calcOpenButton.MouseButton1Click:Connect(function()
            toolsPage.Visible = false
            calcPage.Visible = true
        end)

        calcBack.MouseButton1Click:Connect(function()
            calcPage.Visible = false
            toolsPage.Visible = true
        end)

        boomboxButton.MouseButton1Click:Connect(function()
            toolsPage.Visible = false
            boomboxPage.Visible = true
        end)

        boomboxBackButton.MouseButton1Click:Connect(function()
            boomboxPage.Visible = false
            toolsPage.Visible = true
        end)

        notesOpenButton.MouseButton1Click:Connect(function()
            toolsPage.Visible = false
            refreshList()
            notesPage.Visible = true
        end)

        notesBack.MouseButton1Click:Connect(function()
            notesPage.Visible = false
            toolsPage.Visible = true
        end)

        -- Jika panel pengaturan (⚙️) dibuka, sembunyikan halaman Tools.
        local function watchSettingsPanel(child)
            if child.Name == "ZaqiSettingsPanel" and child:IsA("GuiObject") then
                child:GetPropertyChangedSignal("Visible"):Connect(function()
                    if child.Visible then
                        hideAllToolPages()
                    end
                end)
            end
        end
        for _, child in ipairs(menu:GetChildren()) do
            watchSettingsPanel(child)
        end
        menu.ChildAdded:Connect(watchSettingsPanel)
    end)()

    --------------------------------------------------
    -- MENU FOLDER (klik judul untuk buka/tutup isinya)
    --------------------------------------------------
    local folders = {
        { "Gerak", {
            speedButton, gameSpeedButton, noclipButton, jumpButton,
            flightButton, next10Button,
        } },
        { "Teleport", {
            customTpFrame, teleportButton, teleportBackButton,
        } },
        { "Kamera", {
            next3Button, next1Button, next2Button, next7Button,
            next9Button, next11Button, next12Button,
        } },
        { "Inventori", {
            hotbarButton, backpackButton, eButton,
        } },
        { "Lain-lain", {
            content:WaitForChild("LabelEspMode"), content:WaitForChild("EspModePanel"),
            content:WaitForChild("LabelSudutPandang"), content:WaitForChild("SudutPandangPanel"),
            content:WaitForChild("LabelAutoEmot"), next8Frame, particleAuraButton, statsButton, antiAFKButton, resetButton,
        } },
    }

    -- Simpan urutan asli (tampilan Klasik) sebelum diubah oleh folder.
    local origOrder = {}
    for _, child in ipairs(content:GetChildren()) do
        if child:IsA("GuiObject") then
            origOrder[child] = child.LayoutOrder
        end
    end
    -- Tampilan Klasik: ESP ditaruh tepat di atas Sudut Pandang.
    do
        local sudutOrder = origOrder[content:WaitForChild("LabelSudutPandang")]
        local espLabel = content:WaitForChild("LabelEspMode")
        local espPanel = content:WaitForChild("EspModePanel")
        for child, order in pairs(origOrder) do
            if order >= sudutOrder and child ~= espLabel and child ~= espPanel then
                origOrder[child] = order + 2
            end
        end
        origOrder[espLabel] = sudutOrder
        origOrder[espPanel] = sudutOrder + 1
    end
    local folderEntries = {}

    local folderOrder = 0
    local folderPlaced = {}

    for _, folder in ipairs(folders) do
        local title = folder[1]
        local items = folder[2]

        folderOrder = folderOrder + 1

        local header = Instance.new("TextButton")
        header.Name = "Folder_" .. title
        header.Size = UDim2.new(1, 0, 0, 35)
        header.LayoutOrder = folderOrder
        header.BackgroundColor3 = Color3.fromRGB(45, 55, 85)
        header.TextColor3 = Color3.new(1, 1, 1)
        header.TextSize = 14
        header.Font = Enum.Font.GothamBold
        header.Parent = content
        Instance.new("UICorner", header).CornerRadius = UDim.new(0, 6)
        folderPlaced[header] = true

        for _, item in ipairs(items) do
            folderOrder = folderOrder + 1
            item.LayoutOrder = folderOrder
            folderPlaced[item] = true
        end

        local isOpen = false
        local function refreshFolder()
            header.Text = (isOpen and "📂 " or "📁 ") .. title .. (isOpen and "  ▾" or "  ▸")
            for _, item in ipairs(items) do
                item.Visible = isOpen
            end
        end

        header.MouseButton1Click:Connect(function()
            isOpen = not isOpen
            refreshFolder()
        end)

        refreshFolder() -- awal: semua folder tertutup

        table.insert(folderEntries, {
            header = header,
            items = items,
            refresh = refreshFolder,
        })
    end

    -- Item menu lain yang belum masuk folder tetap tampil setelah folder.
    local leftovers = {}
    for _, child in ipairs(content:GetChildren()) do
        if child:IsA("GuiObject") and not folderPlaced[child] then
            table.insert(leftovers, child)
        end
    end
    table.sort(leftovers, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    for _, child in ipairs(leftovers) do
        folderOrder = folderOrder + 1
        child.LayoutOrder = folderOrder
    end

    -- Simpan urutan tampilan Ringkas (folder).
    local compactOrder = {}
    for _, child in ipairs(content:GetChildren()) do
        if child:IsA("GuiObject") then
            compactOrder[child] = child.LayoutOrder
        end
    end

    -- Tombol berikutnya (Lock Menu, Hide Menu) tetap di paling bawah.
    buttonOrder = folderOrder

    --------------------------------------------------
    -- PENGATURAN (tombol gir ⚙️ di sebelah tombol X)
    --------------------------------------------------
    local SETTINGS_FILE = "ZaqiAdmin_Pengaturan.txt"
    local DEFAULT_BG = Color3.fromRGB(30, 30, 30)

    local currentUiMode = "ringkas"   -- "klasik" atau "ringkas"
    local currentBg = DEFAULT_BG
    local panelLabels = {}            -- teks yang warnanya ikut background
    local swatchButtons = {}
    local modeButtons = {}
    local hexBox

    local function colorToHex(c)
        return string.format(
            "%02X%02X%02X",
            math.floor(c.R * 255 + 0.5),
            math.floor(c.G * 255 + 0.5),
            math.floor(c.B * 255 + 0.5)
        )
    end

    local function hexToColor(text)
        if type(text) ~= "string" then return nil end
        local hex = text:gsub("[#%s]", "")
        if #hex ~= 6 or hex:find("[^%x]") then return nil end
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        if not (r and g and b) then return nil end
        return Color3.fromRGB(r, g, b)
    end

    local function saveSettings()
        pcall(function()
            if writefile then
                writefile(SETTINGS_FILE, colorToHex(currentBg) .. "\n" .. currentUiMode)
            end
        end)
    end

    -- Panel pengaturan (menutupi area daftar tombol saat dibuka)
    local panel = Instance.new("ScrollingFrame")
    panel.Name = "ZaqiSettingsPanel"
    panel.Size = scroll.Size
    panel.Position = scroll.Position
    panel.BackgroundColor3 = scroll.BackgroundColor3
    panel.BorderSizePixel = 0
    panel.ScrollBarThickness = 4
    panel.ScrollingDirection = Enum.ScrollingDirection.Y
    panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
    panel.ZIndex = 5
    panel.Visible = false
    panel.Parent = menu
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

    local panelPad = Instance.new("UIPadding")
    panelPad.PaddingTop = UDim.new(0, 6)
    panelPad.PaddingBottom = UDim.new(0, 6)
    panelPad.PaddingLeft = UDim.new(0, 6)
    panelPad.PaddingRight = UDim.new(0, 6)
    panelPad.Parent = panel

    local panelList = Instance.new("UIListLayout")
    panelList.SortOrder = Enum.SortOrder.LayoutOrder
    panelList.Padding = UDim.new(0, 6)
    panelList.Parent = panel

    local panelOrder = 0
    local function nextPanelOrder()
        panelOrder = panelOrder + 1
        return panelOrder
    end

    local function makePanelLabel(text, size, bold)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, size + 8)
        label.LayoutOrder = nextPanelOrder()
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextSize = size
        label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 6
        label.Parent = panel
        table.insert(panelLabels, label)
        return label
    end

    local function makePanelButton(text)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 32)
        button.LayoutOrder = nextPanelOrder()
        button.BackgroundColor3 = BUTTON_DEFAULT_COLOR
        button.TextColor3 = Color3.new(1, 1, 1)
        button.Text = text
        button.TextSize = 12
        button.Font = Enum.Font.Gotham
        button.ZIndex = 6
        button.Parent = panel
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
        return button
    end

    -- Judul panel
    makePanelLabel("⚙️ Pengaturan", 15, true)

    ----------------------------------------------
    -- 1. WARNA BACKGROUND
    ----------------------------------------------
    makePanelLabel("🎨 Warna Background", 13, true)

    local presets = {
        { "Default", Color3.fromRGB(30, 30, 30) },
        { "Hitam",   Color3.fromRGB(0, 0, 0) },
        { "Biru",    Color3.fromRGB(20, 35, 75) },
        { "Ungu",    Color3.fromRGB(50, 25, 75) },
        { "Hijau",   Color3.fromRGB(20, 55, 35) },
        { "Merah",   Color3.fromRGB(80, 25, 25) },
        { "Oranye",  Color3.fromRGB(95, 55, 15) },
        { "Putih",   Color3.fromRGB(235, 235, 235) },
    }

    local swatchHolder = Instance.new("Frame")
    swatchHolder.Size = UDim2.new(1, 0, 0, 62)
    swatchHolder.LayoutOrder = nextPanelOrder()
    swatchHolder.BackgroundTransparency = 1
    swatchHolder.ZIndex = 6
    swatchHolder.Parent = panel

    local swatchGrid = Instance.new("UIGridLayout")
    swatchGrid.CellSize = UDim2.fromOffset(40, 28)
    swatchGrid.CellPadding = UDim2.fromOffset(6, 6)
    swatchGrid.SortOrder = Enum.SortOrder.LayoutOrder
    swatchGrid.Parent = swatchHolder

    local applyBackground -- dideklarasikan dulu, diisi di bawah

    for index, preset in ipairs(presets) do
        local swatch = Instance.new("TextButton")
        swatch.Name = "Swatch_" .. preset[1]
        swatch.LayoutOrder = index
        swatch.BackgroundColor3 = preset[2]
        swatch.Text = ""
        swatch.TextSize = 16
        swatch.Font = Enum.Font.GothamBold
        swatch.AutoButtonColor = true
        swatch.ZIndex = 6
        swatch.Parent = swatchHolder
        Instance.new("UICorner", swatch).CornerRadius = UDim.new(0, 6)

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(140, 140, 140)
        stroke.Thickness = 1
        stroke.Parent = swatch

        swatch.MouseButton1Click:Connect(function()
            applyBackground(preset[2])
            saveSettings()
        end)

        table.insert(swatchButtons, { button = swatch, color = preset[2] })
    end

    makePanelLabel("Kode warna (hex):", 12, false)

    hexBox = Instance.new("TextBox")
    hexBox.Size = UDim2.new(1, 0, 0, 30)
    hexBox.LayoutOrder = nextPanelOrder()
    hexBox.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    hexBox.TextColor3 = Color3.new(1, 1, 1)
    hexBox.PlaceholderText = "#RRGGBB"
    hexBox.PlaceholderColor3 = Color3.fromRGB(160, 160, 160)
    hexBox.Text = ""
    hexBox.TextSize = 13
    hexBox.Font = Enum.Font.Gotham
    hexBox.ClearTextOnFocus = false
    hexBox.ZIndex = 6
    hexBox.Parent = panel
    Instance.new("UICorner", hexBox).CornerRadius = UDim.new(0, 6)

    hexBox.FocusLost:Connect(function()
        local color = hexToColor(hexBox.Text)
        if color then
            applyBackground(color)
            saveSettings()
        else
            -- Input tidak valid: kembalikan ke warna yang sedang dipakai.
            hexBox.Text = "#" .. colorToHex(currentBg)
        end
    end)

    ----------------------------------------------
    -- 2. UI (KLASIK / RINGKAS)
    ----------------------------------------------
    makePanelLabel("🖥️ Tampilan UI", 13, true)

    modeButtons.klasik = makePanelButton("📋 Klasik (tanpa folder)")
    modeButtons.ringkas = makePanelButton("📁 Ringkas (pakai folder)")

    local function updateModeButtons()
        setButtonState(modeButtons.klasik, currentUiMode == "klasik")
        setButtonState(modeButtons.ringkas, currentUiMode == "ringkas")
    end

    local function applyUiMode(mode)
        if mode ~= "klasik" then
            mode = "ringkas"
        end
        currentUiMode = mode

        if mode == "klasik" then
            -- Tampilan lama: tanpa folder, semua tombol langsung terlihat,
            -- dengan urutan asli.
            for _, entry in ipairs(folderEntries) do
                entry.header.Visible = false
                for _, item in ipairs(entry.items) do
                    item.Visible = true
                end
            end
            for child, order in pairs(origOrder) do
                if child.Parent == content then
                    child.LayoutOrder = order
                end
            end
        else
            -- Tampilan folder: urutan folder dipulihkan, folder mengatur
            -- terlihat/tidaknya isinya.
            for child, order in pairs(compactOrder) do
                if child.Parent == content then
                    child.LayoutOrder = order
                end
            end
            for _, entry in ipairs(folderEntries) do
                entry.header.Visible = true
                entry.refresh()
            end
        end

        updateModeButtons()
        task.defer(updateCanvas)
    end

    modeButtons.klasik.MouseButton1Click:Connect(function()
        applyUiMode("klasik")
        saveSettings()
    end)

    modeButtons.ringkas.MouseButton1Click:Connect(function()
        applyUiMode("ringkas")
        saveSettings()
    end)

    ----------------------------------------------
    -- Tombol kembali
    ----------------------------------------------
    local backButton = makePanelButton("⬅️ Kembali ke Menu")

    ----------------------------------------------
    -- Tombol gir di sebelah tombol X
    ----------------------------------------------
    local gear = Instance.new("TextButton")
    gear.Name = "ZaqiSettingsButton"
    gear.Size = UDim2.fromOffset(30, 30)
    gear.Position = UDim2.new(1, -65, 0, 5)
    gear.BackgroundTransparency = 1
    gear.Text = "⚙️"
    gear.TextColor3 = Color3.new(1, 1, 1)
    gear.TextSize = 18
    gear.Font = Enum.Font.Gotham
    gear.Parent = menu

    -- Tombol gembok (Lock Menu) di sebelah gir: 🔒 terkunci, 🔓 terbuka.
    local lockIcon = Instance.new("TextButton")
    lockIcon.Name = "ZaqiLockMenuButton"
    lockIcon.Size = UDim2.fromOffset(30, 30)
    lockIcon.Position = UDim2.new(1, -95, 0, 5)
    lockIcon.BackgroundTransparency = 1
    lockIcon.Text = menuLocked and "🔒" or "🔓"
    lockIcon.TextColor3 = Color3.new(1, 1, 1)
    lockIcon.TextSize = 18
    lockIcon.Font = Enum.Font.Gotham
    lockIcon.Parent = menu

    lockIcon.MouseButton1Click:Connect(function()
        menuLocked = not menuLocked
        lockIcon.Text = menuLocked and "🔒" or "🔓"
        -- Jika dikunci saat tombol sedang diseret, hentikan drag.
        if menuLocked then
            openDragging = false
        end
    end)

    -- Beri ruang untuk tombol gir & gembok agar judul tidak menutupinya.
    title.Size = UDim2.new(1, -112, 0, 40)

    local function setSettingsOpen(open)
        panel.Visible = open
        scroll.Visible = not open
    end

    gear.MouseButton1Click:Connect(function()
        setSettingsOpen(not panel.Visible)
    end)

    backButton.MouseButton1Click:Connect(function()
        setSettingsOpen(false)
    end)

    -- Menutup menu juga menutup panel pengaturan.
    close.MouseButton1Click:Connect(function()
        setSettingsOpen(false)
    end)

    ----------------------------------------------
    -- Terapkan warna background
    ----------------------------------------------
    applyBackground = function(color)
        currentBg = color
        menu.BackgroundColor3 = color

        local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
        local inner
        if luminance < 0.5 then
            inner = color:Lerp(Color3.new(1, 1, 1), 0.07)
        else
            inner = color:Lerp(Color3.new(0, 0, 0), 0.07)
        end
        scroll.BackgroundColor3 = inner
        panel.BackgroundColor3 = inner

        -- Teks ikut menyesuaikan agar tetap terbaca di background terang.
        local textColor = luminance < 0.55
            and Color3.new(1, 1, 1)
            or Color3.fromRGB(20, 20, 20)
        for _, label in ipairs(panelLabels) do
            label.TextColor3 = textColor
        end
        close.TextColor3 = textColor
        gear.TextColor3 = textColor

        -- Tanda centang pada swatch yang sedang dipakai.
        local hex = colorToHex(color)
        for _, entry in ipairs(swatchButtons) do
            local selected = colorToHex(entry.color) == hex
            entry.button.Text = selected and "✓" or ""
            local entryLum = 0.299 * entry.color.R + 0.587 * entry.color.G + 0.114 * entry.color.B
            entry.button.TextColor3 = entryLum < 0.5
                and Color3.new(1, 1, 1)
                or Color3.fromRGB(20, 20, 20)
        end

        if hexBox then
            hexBox.Text = "#" .. hex
        end
    end

    ----------------------------------------------
    -- Muat pengaturan tersimpan (jika executor mendukung readfile)
    ----------------------------------------------
    local loadedBg, loadedMode = DEFAULT_BG, "ringkas"
    pcall(function()
        if isfile and readfile and isfile(SETTINGS_FILE) then
            local data = readfile(SETTINGS_FILE)
            local hexLine, modeLine = data:match("^%s*([^\r\n]+)[\r\n]+%s*([^\r\n]+)")
            local savedColor = hexLine and hexToColor(hexLine)
            if savedColor then
                loadedBg = savedColor
            end
            if modeLine and modeLine:match("klasik") then
                loadedMode = "klasik"
            end
        end
    end)

    applyBackground(loadedBg)
    applyUiMode(loadedMode)
end)()

--==================================================
-- HIDE
--==================================================

local hideButton =
	makeButton("❌ Hide Menu")

hideButton.MouseButton1Click:Connect(function()
	menu.Visible = false
end)

task.defer(updateCanvas)

print("ZAQI ADMIN BERHASIL DIMUAT")