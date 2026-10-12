local Loading={}
function Loading.new()
    local self={ready_after=0}
    function self:blocked(now)
        local reason
        for _, manager in ipairs(api.objects('LoadingScreenManager')) do
            local value=manager:GetDebugReasonForShowingOrHidingLoadingScreen()
            if value~='(nothing wants to show it anymore)' then reason=value end
        end
        for _, hud in ipairs(api.objects('PalHUDService')) do
            if hud:IsAnyFadeWidgetActive() then reason='fade' end
        end
        if reason then self.ready_after=now+.15;return true,reason end
        if now<self.ready_after then return true,'settling' end
        return false
    end
    return self
end
return Loading
