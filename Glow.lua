-- Swiftmender Forever: glow styles for the target icon's overheal glow.
--
--   Glow  - the static action-button glow ring
--   Proc  - the ability activation ("proc") glow, the animated loop
--   Pixel - lines running around the border
--
-- Everything moving is an AnimationGroup, which the game plays by itself
-- once started, so no Lua runs per frame. That matters because in combat
-- the glow lives inside a native aura button (see Icon.lua). The pixel lines
-- are bars spinning about the icon's centre, seen through four clipping
-- strips around the border, so only the bits crossing the border show.

local ADDON, ns = ...

local Glow = {}
ns.Glow = Glow

Glow.STYLES = { "Glow", "Proc", "Pixel" }

function Glow.StyleName(v)
	for _, s in ipairs(Glow.STYLES) do
		if s == v then return v end
	end
	return "Glow"
end

local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local GLOW_SCALE = 1.75 -- the texture's ring sits inside a larger square
local PROC_ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook"
local PROC_ANTS = "Interface\\SpellActivationOverlay\\IconAlertAnts"
local PROC_SCALE = 1.4  -- what Blizzard uses for action buttons
local PIXEL_BARS = 4    -- spinning bars, each shows as two lines
local PIXEL_PERIOD = 4  -- seconds per lap
local PIXEL_THICKNESS = 2

local failed = {} -- styles this client can't build, reported once

local function Color(cfg)
	local c = ns.BORDER_COLORS[ns.ColorName(cfg.glowColor)]
	return c[1], c[2], c[3]
end

local function Loop(region)
	local group = region:CreateAnimationGroup()
	group:SetLooping("REPEAT")
	return group
end

--------------------------------------------------------------------------
-- styles
--------------------------------------------------------------------------

local function BuildStatic(g)
	local tex = g.host:CreateTexture(nil, "OVERLAY")
	tex:SetTexture(GLOW_TEXTURE)
	tex:SetBlendMode("ADD")
	tex:SetPoint("CENTER", g.anchor, "CENTER")
	g.static = tex
end

local function StyleStatic(g, cfg)
	g.static:SetSize(cfg.size * GLOW_SCALE, cfg.size * GLOW_SCALE)
	g.static:SetVertexColor(Color(cfg))
end

local function BuildProc(g)
	local f = CreateFrame("Frame", nil, g.host)
	f:SetPoint("CENTER", g.anchor, "CENTER")
	local tex = f:CreateTexture(nil, "OVERLAY")
	tex:SetAllPoints(f)
	local rows, cols, frames = 6, 5, 30
	local atlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(PROC_ATLAS)
	if atlas then
		tex:SetAtlas(PROC_ATLAS)
	else
		-- older art: 22 frames of 48px in a 256px texture
		tex:SetTexture(PROC_ANTS)
		tex:SetTexCoord(0, 240 / 256, 0, 240 / 256)
		rows, cols, frames = 5, 5, 22
	end
	local group = Loop(tex)
	local flip = group:CreateAnimation("FlipBook")
	flip:SetDuration(1)
	flip:SetFlipBookRows(rows)
	flip:SetFlipBookColumns(cols)
	flip:SetFlipBookFrames(frames)
	g.proc, g.procTex = f, tex
	g.groups.Proc = { group }
end

local function StyleProc(g, cfg)
	g.proc:SetSize(cfg.size * PROC_SCALE, cfg.size * PROC_SCALE)
	-- the art is gold; other colours tint a greyed copy
	if ns.ColorName(cfg.glowColor) == "Gold" then
		g.procTex:SetDesaturated(false)
		g.procTex:SetVertexColor(1, 1, 1)
	else
		g.procTex:SetDesaturated(true)
		g.procTex:SetVertexColor(Color(cfg))
	end
end

local STRIPS = { "top", "bottom", "left", "right" }

local function BuildPixel(g)
	g.strips, g.bars = {}, {}
	local groups = {}
	for _, side in ipairs(STRIPS) do
		local strip = CreateFrame("Frame", nil, g.host)
		strip:SetClipsChildren(true)
		g.strips[side] = strip
		for i = 1, PIXEL_BARS do
			local bar = strip:CreateTexture(nil, "OVERLAY")
			bar:SetPoint("CENTER", g.anchor, "CENTER")
			local group = Loop(bar)
			-- spread the bars evenly: an instant turn, then a full lap
			local offset = group:CreateAnimation("Rotation")
			offset:SetOrder(1)
			offset:SetDuration(0.001)
			offset:SetDegrees(-180 / PIXEL_BARS * (i - 1))
			local spin = group:CreateAnimation("Rotation")
			spin:SetOrder(2)
			spin:SetDuration(PIXEL_PERIOD)
			spin:SetDegrees(-360)
			g.bars[#g.bars + 1] = bar
			groups[#groups + 1] = group
		end
	end
	g.groups.Pixel = groups
end

local function StylePixel(g, cfg)
	-- a band just outside the icon and its border
	local inner = cfg.size / 2 + (cfg.showBorder and cfg.borderSize or 0)
	local th = PIXEL_THICKNESS
	local outer = inner + th
	local s = g.strips
	s.top:ClearAllPoints()
	s.top:SetPoint("TOPLEFT", g.anchor, "CENTER", -outer, outer)
	s.top:SetSize(outer * 2, th)
	s.bottom:ClearAllPoints()
	s.bottom:SetPoint("BOTTOMLEFT", g.anchor, "CENTER", -outer, -outer)
	s.bottom:SetSize(outer * 2, th)
	s.left:ClearAllPoints()
	s.left:SetPoint("TOPLEFT", g.anchor, "CENTER", -outer, inner)
	s.left:SetSize(th, inner * 2)
	s.right:ClearAllPoints()
	s.right:SetPoint("TOPRIGHT", g.anchor, "CENTER", outer, inner)
	s.right:SetSize(th, inner * 2)
	local r, gr, b = Color(cfg)
	for _, bar in ipairs(g.bars) do
		-- long enough to reach the corners, as wide as one visible line
		bar:SetSize(outer * 3, math.max(3, outer * 0.5))
		bar:SetColorTexture(r, gr, b, 1)
	end
end

local BUILD = { Glow = BuildStatic, Proc = BuildProc, Pixel = BuildPixel }
local STYLE = { Glow = StyleStatic, Proc = StyleProc, Pixel = StylePixel }

--------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------

-- A glow drawn around `anchor`, inside `parent`; shown with its parent.
function Glow.Create(parent, anchor)
	local g = { anchor = anchor, groups = {}, built = {} }
	g.host = CreateFrame("Frame", nil, parent)
	g.host:SetAllPoints(anchor)
	-- hidden regions stop animating, so restart when shown again
	g.host:SetScript("OnShow", function() Glow.Play(g) end)
	return g
end

function Glow.Play(g)
	for _, group in ipairs(g.groups[g.style] or {}) do
		if not group:IsPlaying() then pcall(group.Play, group) end
	end
end

-- Switch to the configured style, size and colour.
function Glow.Apply(g, cfg)
	local style = Glow.StyleName(cfg.glowStyle)
	if failed[style] then style = "Glow" end
	if not g.built[style] then
		local ok, err = pcall(BUILD[style], g)
		if ok then
			g.built[style] = true
		else
			-- the client lacks something this style needs: use the plain glow
			g.groups[style] = nil
			failed[style] = true
			ns.Print("glow style " .. style .. " isn't available here, using Glow (" .. tostring(err) .. ")")
			style = "Glow"
			if not g.built.Glow then
				BuildStatic(g)
				g.built.Glow = true
			end
		end
	end
	g.style = style
	if g.static then g.static:SetShown(style == "Glow") end
	if g.proc then g.proc:SetShown(style == "Proc") end
	if g.strips then
		for _, strip in pairs(g.strips) do strip:SetShown(style == "Pixel") end
	end
	for name, groups in pairs(g.groups) do
		if name ~= style then
			for _, group in ipairs(groups) do group:Stop() end
		end
	end
	STYLE[style](g, cfg)
	Glow.Play(g)
end
