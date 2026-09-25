local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Menu = {
	items = {},
	position = Vector2.new(100, 100),
	size = Vector2.new(220, 100),
	width = 220,
	padding = 12,
	header_h = 22,
	spacing = 10,
	visible = true,
	mouse = Vector2.new(),
	dragging = false,
	drag_offset = Vector2.new(),
	active_dropdown = nil,
}

local function new_rect(filled, z)
	local d = Drawing.new("Square")
	d.Filled, d.Thickness, d.Transparency, d.ZIndex, d.Visible = filled, 1, 1, z, true
	return d
end

local function new_label(z, size)
	local d = Drawing.new("Text")
	d.Size, d.Center, d.Outline, d.ZIndex, d.Visible = size or 14, false, true, z, true
	return d
end

local function in_bounds(p, pos, size)
	return p.X >= pos.X and p.X <= pos.X + size.X
		and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
end

Menu.panel_bg = new_rect(true, 0)
Menu.panel_outline = new_rect(false, 1)
Menu.title = new_label(2, 15)

function Menu:add_checkbox(name, default, callback)
	local it = {
		type = "checkbox", name = name, height = 18,
		value = default or false, callback = callback,
		draw = { new_rect(true, 3), new_rect(false, 4), new_rect(true, 5), new_label(6) },
	}
	table.insert(self.items, it)
	return it
end

function Menu:add_slider(name, min, max, default, callback)
	local it = {
		type = "slider", name = name, height = 36,
		min = min, max = max, value = default or min,
		dragging = false, callback = callback,
		draw = { new_rect(true, 3), new_rect(false, 4), new_rect(true, 5), new_label(6) },
	}
	table.insert(self.items, it)
	return it
end

function Menu:add_combobox(name, options, default, callback)
	local it = {
		type = "combobox", name = name, height = 18,
		options = options, value = default or options[1],
		selected_index = default and self:_find_index(options, default) or 1,
		callback = callback, open = false,
		draw = { new_rect(true, 3), new_rect(false, 4), new_label(5), new_label(6) },
		dropdown_draw = {},
	}
	table.insert(self.items, it)
	return it
end

function Menu:add_multicombobox(name, options, default, callback)
	local selected_values = {}
	if default then
		for _, v in ipairs(default) do
			selected_values[v] = true
		end
	end
	
	local it = {
		type = "multicombobox", name = name, height = 18,
		options = options, selected = selected_values,
		callback = callback, open = false,
		draw = { new_rect(true, 3), new_rect(false, 4), new_label(5), new_label(6) },
		dropdown_draw = {},
	}
	table.insert(self.items, it)
	return it
end

function Menu:add_color_picker(name, default, callback)
	local default_color = default or Color3.new(1, 1, 1)
	local it = {
		type = "color_picker", name = name, height = 70,
		value = default_color, callback = callback,
		r = math.floor(default_color.R * 255),
		g = math.floor(default_color.G * 255),
		b = math.floor(default_color.B * 255),
		r_dragging = false, g_dragging = false, b_dragging = false,
		draw = {
			new_rect(true, 3), new_rect(false, 4), new_label(6),    -- R channel (1, 2, 3)
			new_rect(true, 3), new_rect(false, 4), new_label(6),    -- G channel (4, 5, 6)
			new_rect(true, 3), new_rect(false, 4), new_label(6),    -- B channel (7, 8, 9)
			new_label(6),                                            -- Title label (10)
			new_rect(true, 1),                                       -- Preview (11)
		},
	}
	table.insert(self.items, it)
	return it
end

function Menu:_find_index(tbl, val)
	for i, v in ipairs(tbl) do
		if v == val then return i end
	end
	return 1
end

function Menu:_get_dropdown_height(it)
	return #it.options * 18 + 4
end

function Menu:layout()
	local inner_w = self.width - self.padding * 2
	local y = self.position.Y + self.padding + self.header_h
	local start_y = y

	for i, it in ipairs(self.items) do
		it.position = Vector2.new(self.position.X + self.padding, y)

		if it.type == "checkbox" then
			it.bar_pos, it.bar_size = it.position, Vector2.new(inner_w, 16)
		elseif it.type == "combobox" or it.type == "multicombobox" then
			it.bar_pos, it.bar_size = it.position, Vector2.new(inner_w, 16)
		elseif it.type == "color_picker" then
			it.r_bar_pos = it.position + Vector2.new(0, 18)
			it.r_bar_size = Vector2.new(inner_w, 14)
			it.g_bar_pos = it.position + Vector2.new(0, 36)
			it.g_bar_size = Vector2.new(inner_w, 14)
			it.b_bar_pos = it.position + Vector2.new(0, 54)
			it.b_bar_size = Vector2.new(inner_w, 14)
			it.preview_pos = it.position + Vector2.new(inner_w - 40, 0)
			it.preview_size = Vector2.new(40, 18)
		else
			it.bar_pos = it.position + Vector2.new(0, 20)
			it.bar_size = Vector2.new(inner_w, 16)
		end

		y += it.height
		if i < #self.items then y += self.spacing end
	end

	local content_h = y - start_y
	self.size = Vector2.new(self.width, self.header_h + content_h + self.padding * 2)
end

function Menu:set_slider(it)
	local rel = math.clamp((self.mouse.X - it.bar_pos.X) / it.bar_size.X, 0, 1)
	local v = it.min + (it.max - it.min) * rel
	if v ~= it.value then
		it.value = v
		if it.callback then it.callback(v) end
	end
end

function Menu:set_color_channel(it, channel)
	local val_percent = 0
	if channel == "r" then
		val_percent = math.clamp((self.mouse.X - it.r_bar_pos.X) / it.r_bar_size.X, 0, 1)
		it.r = math.floor(val_percent * 255)
	elseif channel == "g" then
		val_percent = math.clamp((self.mouse.X - it.g_bar_pos.X) / it.g_bar_size.X, 0, 1)
		it.g = math.floor(val_percent * 255)
	elseif channel == "b" then
		val_percent = math.clamp((self.mouse.X - it.b_bar_pos.X) / it.b_bar_size.X, 0, 1)
		it.b = math.floor(val_percent * 255)
	end
	
	it.value = Color3.new(it.r / 255, it.g / 255, it.b / 255)
	if it.callback then it.callback(it.value) end
end

function Menu:set_visible(v)
	self.visible = v
	if not v then
		self.dragging = false
		for _, it in ipairs(self.items) do 
			it.dragging = false
			if it.type == "combobox" or it.type == "multicombobox" then
				it.open = false
			end
		end
	end
	for _, d in ipairs({ self.panel_bg, self.panel_outline, self.title }) do
		d.Visible = v
	end
	for _, it in ipairs(self.items) do
		for _, d in ipairs(it.draw) do d.Visible = v end
	end
	for _, d in ipairs(self:_get_all_dropdown_draws()) do
		d.Visible = v
	end
end

function Menu:_get_all_dropdown_draws()
	local all = {}
	for _, it in ipairs(self.items) do
		if it.dropdown_draw then
			for _, d in ipairs(it.dropdown_draw) do
				table.insert(all, d)
			end
		end
	end
	return all
end

function Menu:draw()
	if not self.visible then return end

	self.panel_bg.Position, self.panel_bg.Size = self.position, self.size
	self.panel_bg.Color = Color3.new(0.07, 0.07, 0.09)

	self.panel_outline.Position, self.panel_outline.Size = self.position, self.size
	self.panel_outline.Color = Color3.new(0.25, 0.25, 0.32)

	self.title.Text = "Menu"
	self.title.Position = self.position + Vector2.new(self.padding, self.padding - 3)
	self.title.Color = Color3.new(1, 1, 1)

	for _, it in ipairs(self.items) do
		if it.type == "checkbox" then
			self:_draw_checkbox(it)
		elseif it.type == "slider" then
			self:_draw_slider(it)
		elseif it.type == "combobox" then
			self:_draw_combobox(it)
		elseif it.type == "multicombobox" then
			self:_draw_multicombobox(it)
		elseif it.type == "color_picker" then
			self:_draw_color_picker(it)
		end
	end
end

function Menu:_draw_checkbox(it)
	local bg, outline, fill, text = table.unpack(it.draw)
	text.Color = Color3.new(0.9, 0.9, 0.95)

	local box = it.bar_pos
	bg.Visible, outline.Visible, text.Visible = true, true, true

	bg.Position, bg.Size = box, Vector2.new(16, 16)
	bg.Color = Color3.new(0.15, 0.15, 0.18)
	outline.Position, outline.Size = box, Vector2.new(16, 16)
	outline.Color = Color3.new(0.3, 0.3, 0.35)

	fill.Visible = it.value
	if it.value then
		fill.Position = box + Vector2.new(4, 4)
		fill.Size = Vector2.new(8, 8)
		fill.Color = Color3.new(0.3, 0.8, 0.4)
	end

	text.Text = it.name
	text.Position = box + Vector2.new(24, 0)
end

function Menu:_draw_slider(it)
	local bg, outline, fill, text = table.unpack(it.draw)

	bg.Visible, outline.Visible, fill.Visible, text.Visible = true, true, true, true

	text.Text = string.format("%s: %.2f", it.name, it.value)
	text.Position = it.position + Vector2.new(0, -4)
	text.Color = Color3.new(0.9, 0.9, 0.95)

	bg.Position, bg.Size = it.bar_pos, it.bar_size
	bg.Color = Color3.new(0.15, 0.15, 0.18)
	outline.Position, outline.Size = it.bar_pos, it.bar_size
	outline.Color = Color3.new(0.3, 0.3, 0.35)

	local pct = (it.value - it.min) / (it.max - it.min)
	fill.Position = it.bar_pos
	fill.Size = Vector2.new(it.bar_size.X * pct, it.bar_size.Y)
	fill.Color = Color3.new(0.3, 0.6, 0.9)
end

function Menu:_draw_combobox(it)
	local bg, outline, text, arrow = table.unpack(it.draw)

	bg.Visible, outline.Visible, text.Visible = true, true, true
	bg.Position, bg.Size = it.bar_pos, it.bar_size
	bg.Color = Color3.new(0.15, 0.15, 0.18)
	outline.Position, outline.Size = it.bar_pos, it.bar_size
	outline.Color = Color3.new(0.3, 0.3, 0.35)

	text.Text = it.value
	text.Position = it.bar_pos + Vector2.new(6, 0)
	text.Color = Color3.new(0.9, 0.9, 0.95)

	arrow.Text = it.open and "▼" or "▶"
	arrow.Position = it.bar_pos + Vector2.new(it.bar_size.X - 12, 0)
	arrow.Color = Color3.new(0.7, 0.7, 0.75)
	arrow.Visible = true

	if it.open then
		self:_draw_dropdown(it)
	end
end

function Menu:_draw_multicombobox(it)
	local bg, outline, text, arrow = table.unpack(it.draw)

	bg.Visible, outline.Visible, text.Visible = true, true, true
	bg.Position, bg.Size = it.bar_pos, it.bar_size
	bg.Color = Color3.new(0.15, 0.15, 0.18)
	outline.Position, outline.Size = it.bar_pos, it.bar_size
	outline.Color = Color3.new(0.3, 0.3, 0.35)

	local selected_count = 0
	for _ in pairs(it.selected) do selected_count = selected_count + 1 end
	text.Text = selected_count == 0 and "None selected" or selected_count .. " selected"
	text.Position = it.bar_pos + Vector2.new(6, 0)
	text.Color = Color3.new(0.9, 0.9, 0.95)

	arrow.Text = it.open and "▼" or "▶"
	arrow.Position = it.bar_pos + Vector2.new(it.bar_size.X - 12, 0)
	arrow.Color = Color3.new(0.7, 0.7, 0.75)
	arrow.Visible = true

	if it.open then
		self:_draw_dropdown_multi(it)
	end
end

function Menu:_draw_dropdown(it)
	local dropdown_h = self:_get_dropdown_height(it)
	local dropdown_pos = it.bar_pos + Vector2.new(0, it.bar_size.Y + 2)

	if #it.dropdown_draw == 0 then
		for i = 1, #it.options do
			table.insert(it.dropdown_draw, new_rect(true, 10))
			table.insert(it.dropdown_draw, new_rect(false, 11))
			table.insert(it.dropdown_draw, new_label(12, 12))
		end
	end

	for i, option in ipairs(it.options) do
		local item_y = dropdown_pos.Y + (i - 1) * 18 + 2
		local bg = it.dropdown_draw[(i - 1) * 3 + 1]
		local outline = it.dropdown_draw[(i - 1) * 3 + 2]
		local text = it.dropdown_draw[(i - 1) * 3 + 3]

		local is_selected = (i == it.selected_index)
		bg.Position = Vector2.new(dropdown_pos.X, item_y)
		bg.Size = Vector2.new(it.bar_size.X, 16)
		bg.Color = is_selected and Color3.new(0.25, 0.5, 0.8) or Color3.new(0.12, 0.12, 0.15)
		bg.Visible = true

		outline.Position, outline.Size = bg.Position, bg.Size
		outline.Color = Color3.new(0.3, 0.3, 0.35)
		outline.Visible = true

		text.Text = option
		text.Position = Vector2.new(dropdown_pos.X + 6, item_y - 2)
		text.Color = Color3.new(0.9, 0.9, 0.95)
		text.Visible = true
	end
end

function Menu:_draw_dropdown_multi(it)
	local dropdown_h = self:_get_dropdown_height(it)
	local dropdown_pos = it.bar_pos + Vector2.new(0, it.bar_size.Y + 2)

	if #it.dropdown_draw == 0 then
		for i = 1, #it.options do
			table.insert(it.dropdown_draw, new_rect(true, 10))
			table.insert(it.dropdown_draw, new_rect(false, 11))
			table.insert(it.dropdown_draw, new_rect(true, 12))
			table.insert(it.dropdown_draw, new_label(13, 12))
		end
	end

	for i, option in ipairs(it.options) do
		local item_y = dropdown_pos.Y + (i - 1) * 18 + 2
		local bg = it.dropdown_draw[(i - 1) * 4 + 1]
		local outline = it.dropdown_draw[(i - 1) * 4 + 2]
		local checkbox = it.dropdown_draw[(i - 1) * 4 + 3]
		local text = it.dropdown_draw[(i - 1) * 4 + 4]

		local is_selected = it.selected[option] or false
		bg.Position = Vector2.new(dropdown_pos.X, item_y)
		bg.Size = Vector2.new(it.bar_size.X, 16)
		bg.Color = Color3.new(0.12, 0.12, 0.15)
		bg.Visible = true

		outline.Position, outline.Size = bg.Position, bg.Size
		outline.Color = Color3.new(0.3, 0.3, 0.35)
		outline.Visible = true

		checkbox.Position = Vector2.new(dropdown_pos.X + 4, item_y + 2)
		checkbox.Size = Vector2.new(10, 10)
		checkbox.Color = Color3.new(0.3, 0.8, 0.4)
		checkbox.Visible = is_selected

		text.Text = option
		text.Position = Vector2.new(dropdown_pos.X + 20, item_y - 2)
		text.Color = Color3.new(0.9, 0.9, 0.95)
		text.Visible = true
	end
end

function Menu:_draw_color_picker(it)
	local title_label = it.draw[10]
	title_label.Text = it.name
	title_label.Position = it.position + Vector2.new(0, -4)
	title_label.Color = Color3.new(0.9, 0.9, 0.95)
	title_label.Visible = true

	local preview = it.draw[11]
	preview.Position = it.preview_pos
	preview.Size = it.preview_size
	preview.Color = it.value
	preview.Visible = true

	self:_draw_color_channel(it, "r", 1, 2, 3)
	self:_draw_color_channel(it, "g", 4, 5, 6)
	self:_draw_color_channel(it, "b", 7, 8, 9)
end

function Menu:_draw_color_channel(it, channel, bg_idx, outline_idx, text_idx)
	local bg = it.draw[bg_idx]
	local outline = it.draw[outline_idx]
	local text = it.draw[text_idx]
	local val = channel == "r" and it.r or (channel == "g" and it.g or it.b)
	local bar_pos = channel == "r" and it.r_bar_pos or (channel == "g" and it.g_bar_pos or it.b_bar_pos)
	local bar_size = channel == "r" and it.r_bar_size or (channel == "g" and it.g_bar_size or it.b_bar_size)

	bg.Position, bg.Size = bar_pos, bar_size
	bg.Color = Color3.new(0.15, 0.15, 0.18)
	bg.Visible = true

	outline.Position, outline.Size = bar_pos, bar_size
	outline.Color = Color3.new(0.3, 0.3, 0.35)
	outline.Visible = true

	local pct = val / 255
	local fill_size = Vector2.new(bar_size.X * pct, bar_size.Y)
	local channel_color = channel == "r" and Color3.new(1, 0.3, 0.3) or (channel == "g" and Color3.new(0.3, 1, 0.3) or Color3.new(0.3, 0.5, 1))
	
	text.Text = string.format("%s: %d", channel:upper(), val)
	text.Position = bar_pos + Vector2.new(0, -16)
	text.Color = channel_color
	text.Visible = true
end

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end

	if input.KeyCode == Enum.KeyCode.RightShift then
		Menu:set_visible(not Menu.visible)
		return
	end

	if not Menu.visible then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	Menu.mouse = UIS:GetMouseLocation()

	for _, it in ipairs(Menu.items) do
		if in_bounds(Menu.mouse, it.bar_pos, it.bar_size) then
			if it.type == "checkbox" then
				it.value = not it.value
				if it.callback then it.callback(it.value) end
			elseif it.type == "slider" then
				it.dragging = true
				Menu:set_slider(it)
			elseif it.type == "combobox" then
				it.open = not it.open
				if it.open and Menu.active_dropdown and Menu.active_dropdown ~= it then
					Menu.active_dropdown.open = false
				end
				Menu.active_dropdown = it.open and it or nil
			elseif it.type == "multicombobox" then
				it.open = not it.open
				if it.open and Menu.active_dropdown and Menu.active_dropdown ~= it then
					Menu.active_dropdown.open = false
				end
				Menu.active_dropdown = it.open and it or nil
			elseif it.type == "color_picker" then
				if in_bounds(Menu.mouse, it.r_bar_pos, it.r_bar_size) then
					it.r_dragging = true
					Menu:set_color_channel(it, "r")
				elseif in_bounds(Menu.mouse, it.g_bar_pos, it.g_bar_size) then
					it.g_dragging = true
					Menu:set_color_channel(it, "g")
				elseif in_bounds(Menu.mouse, it.b_bar_pos, it.b_bar_size) then
					it.b_dragging = true
					Menu:set_color_channel(it, "b")
				end
			end
			return
		end
	end

	-- Handle dropdown clicks
	for _, it in ipairs(Menu.items) do
		if (it.type == "combobox" or it.type == "multicombobox") and it.open then
			local dropdown_pos = it.bar_pos + Vector2.new(0, it.bar_size.Y + 2)
			for i, option in ipairs(it.options) do
				local item_y = dropdown_pos.Y + (i - 1) * 18 + 2
				local item_box = Vector2.new(item_y, item_y + 16)
				if in_bounds(Menu.mouse, Vector2.new(dropdown_pos.X, item_y), Vector2.new(it.bar_size.X, 16)) then
					if it.type == "combobox" then
						it.value = option
						it.selected_index = i
						it.open = false
						Menu.active_dropdown = nil
						if it.callback then it.callback(it.value) end
					elseif it.type == "multicombobox" then
						it.selected[option] = not it.selected[option]
						if it.callback then 
							local selected_list = {}
							for k, v in pairs(it.selected) do
								if v then table.insert(selected_list, k) end
							end
							it.callback(selected_list)
						end
					end
					return
				end
			end
		end
	end

	if in_bounds(Menu.mouse, Menu.position, Menu.size) then
		Menu.dragging = true
		Menu.drag_offset = Menu.mouse - Menu.position
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	Menu.dragging = false
	for _, it in ipairs(Menu.items) do 
		it.dragging = false
		it.r_dragging = false
		it.g_dragging = false
		it.b_dragging = false
	end
end)

RunService.RenderStepped:Connect(function()
	Menu.mouse = UIS:GetMouseLocation()

	if Menu.visible then
		if Menu.dragging then
			local vp = workspace.CurrentCamera.ViewportSize
			local p = Menu.mouse - Menu.drag_offset
			Menu.position = Vector2.new(
				math.clamp(p.X, 0, vp.X - Menu.size.X),
				math.clamp(p.Y, 0, vp.Y - Menu.size.Y)
			)
		end

		Menu:layout()

		for _, it in ipairs(Menu.items) do
			if it.type == "slider" and it.dragging then
				Menu:set_slider(it)
			elseif it.type == "color_picker" then
				if it.r_dragging then
					Menu:set_color_channel(it, "r")
				elseif it.g_dragging then
					Menu:set_color_channel(it, "g")
				elseif it.b_dragging then
					Menu:set_color_channel(it, "b")
				end
			end
		end
	end

	Menu:draw()
end)

return Menu
