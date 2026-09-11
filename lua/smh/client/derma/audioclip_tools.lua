--- @class SMHAudioClipTools: DFrame
--- @field BaseClass DFrame
local PANEL = {}
local deleteConfirmColour = Color(255,0,0)

--- @param panel Panel
local function unavailableStatus(panel)
	panel:SetEnabled(false)
	panel:SetTooltip("This is not functional now. We plan to implement this in the near future")
	panel:SetTooltipDelay(0)
end

--- @param button DButton
--- @param callback function
--- @param defaultColor Color
--- @param defaultText string
--- @param timerName string
local function doRequestCallback(button, callback, defaultColor, defaultText, timerName)
	if not button.Confirm then
		button:SetText("Confirm?")
		button:SetColor(deleteConfirmColour)
		button.Confirm = true
		timer.Create(timerName, 3, 0, function()
			button:SetText(defaultText)
			button:SetColor(defaultColor)
			button.Confirm = false
		end)
	else
		button:SetText(defaultText)
		button:SetColor(defaultColor)
		button.Confirm = false
		callback()
	end
end

function PANEL:Init()

	self.Visible = false
	self:SetVisible(false)

    self:SetTitle("Audio Clip Tools")
    self:SetDeleteOnClose(false)
	
	self:SetSize(320, 107)
	
	self.Label = vgui.Create("DLabel",self)
	self.Label:SetText("Actions will apply to clip under playhead.")
	self.Label:SetFont("DefaultSmall")
	
    self.TrimStart = vgui.Create("DButton", self)
    self.TrimStart:SetText("Trim Start")
	self.DefaultColor = self.TrimStart:GetColor()
    self.TrimStart.DoClick = function()
		doRequestCallback(
			self.TrimStart, 
			self.OnRequestAudioClipTrimStart, 
			self.DefaultColor, 
			"TrimStart",
			"SMHTrimStartConfirm"
		)
    end
	
	self.TrimEnd = vgui.Create("DButton", self)
    self.TrimEnd:SetText("Trim End")
    self.TrimEnd.DoClick = function()
		doRequestCallback(
			self.TrimEnd, 
			self.OnRequestAudioClipTrimEnd, 
			self.DefaultColor, 
			"TrimEnd",
			"SMHTrimEndConfirm"
		)
    end
	
	self.Copy = vgui.Create("DButton", self)
    self.Copy:SetText("Copy")
    self.Copy.DoClick = function()
        self:OnRequestAudioClipCopy()
    end
	
	self.Paste = vgui.Create("DButton", self)
    self.Paste:SetText("Paste")
    self.Paste.DoClick = function()
		self:OnRequestAudioClipPaste()
    end
	
	self.Delete = vgui.Create("DButton", self)
    self.Delete:SetText("Delete")
    self.Delete.DoClick = function()
        -- self:DoDelete()
		doRequestCallback(
			self.Delete, 
			self.OnRequestAudioClipDelete, 
			self.DefaultColor, 
			"Delete",
			"SMHDeleteConfirm"
		)
    end
	self.DeleteDefaultColour = self.Delete:GetColor()
	self.DeleteConfirm = false
	
	self.DeleteAll = vgui.Create("DButton", self)
    self.DeleteAll:SetText("Delete All")
    self.DeleteAll.DoClick = function()
        -- self:DoDeleteAll()
		doRequestCallback(
			self.DeleteAll, 
			self.OnRequestAudioClipDeleteAll, 
			self.DefaultColor, 
			"DeleteAll",
			"SMHDeleteAllConfirm"
		)
    end
	self.DeleteAllConfirm = false
	
	self.Hide = vgui.Create("DButton", self)
    self.Hide:SetText("Hide")
    self.Hide.DoClick = function()
		self:OnRequestAudioClipHide()
    end
	
	self.UnhideAll = vgui.Create("DButton", self)
    self.UnhideAll:SetText("Unhide All")
    self.UnhideAll.DoClick = function()
        self:OnRequestAudioClipUnhideAll()
    end
end

function PANEL:PerformLayout(width, height)

    --- @diagnostic disable-next-line
    self.BaseClass.PerformLayout(self, width, height)
	
	self.Label:SetPos(25, 25)
	self.Label:SetSize(280, 20)

    self.TrimStart:SetPos(25, 43)
    self.TrimStart:SetSize(60, 20)
	
	self.TrimEnd:SetPos(25, 68)
    self.TrimEnd:SetSize(60, 20)
	
	self.Copy:SetPos(95, 43)
    self.Copy:SetSize(60, 20)
	
	self.Paste:SetPos(95, 68)
    self.Paste:SetSize(60, 20)
	
	self.Delete:SetPos(165, 43)
    self.Delete:SetSize(60, 20)
	
	self.DeleteAll:SetPos(165, 68)
    self.DeleteAll:SetSize(60, 20)
	
	self.Hide:SetPos(235, 43)
    self.Hide:SetSize(60, 20)
	
	self.UnhideAll:SetPos(235, 68)
    self.UnhideAll:SetSize(60, 20)

end

function PANEL:SetVis(bool)
	self.Visible = bool
	if SMH.State.EditAudioTrack then
		self:SetVisible(bool)
	end
end

function PANEL:SetEnabled(bool)
	if not bool then
		self:SetVisible(false)
	else
		if self.Visible then
			self:SetVisible(true)
		end
	end
end

function PANEL:OnClose()
	self.Visible = false
end

function PANEL:DoDelete()
	if not self.DeleteConfirm then
		self.Delete:SetText("Confirm?")
		self.Delete:SetColor(deleteConfirmColour)
		self.DeleteConfirm = true
		timer.Create("DeleteConfirm", 3, 0, function()
			self.Delete:SetText("Delete")
			self.Delete:SetColor(self.DeleteDefaultColour)
			self.DeleteConfirm = false
		end)
	else
		self.Delete:SetText("Delete")
		self.Delete:SetColor(self.DeleteDefaultColour)
		self.DeleteConfirm = false
		self:OnRequestAudioClipDelete()
	end
end

function PANEL:DoDeleteAll()
	if not self.DeleteAllConfirm then
		self.DeleteAll:SetText("Confirm?")
		self.DeleteAll:SetColor(deleteConfirmColour)
		self.DeleteAllConfirm = true
		timer.Create("DeleteAllConfirm", 3, 0, function()
			self.DeleteAll:SetText("Delete All")
			self.DeleteAll:SetColor(self.DeleteDefaultColour)
			self.DeleteAllConfirm = false
		end)
	else
		self.DeleteAll:SetText("Delete All")
		self.DeleteAll:SetColor(self.DeleteDefaultColour)
		self.DeleteAllConfirm = false
		self:OnRequestAudioClipDeleteAll()
	end
end

function PANEL:OnRequestAudioClipDelete() end
function PANEL:OnRequestAudioClipDeleteAll() end
function PANEL:OnRequestAudioClipTrimStart() end
function PANEL:OnRequestAudioClipTrimEnd() end
function PANEL:OnRequestAudioClipUnhideAll() end
function PANEL:OnRequestAudioClipHide() end
function PANEL:OnRequestAudioClipCopy() end
function PANEL:OnRequestAudioClipPaste() end


vgui.Register("SMHAudioClipTools", PANEL, "DFrame")
