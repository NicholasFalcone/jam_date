# FOR DESIGN AND ART

### Debug
Playdate ha un limite a 3 menuitem quindi dobbiamo gestirli manualmente.
In main.lua, nella funzione init() trovate tutti i vari menu item che gestiscono le variabili associate

`
menu:addOptionsMenuItem("N_STm:", sliderOptions, N_ScaleTime, function(value)
    local numericValue = tonumber(value)
    N_ScaleTime = numericValue
    end)
`

Potete anche mutare la variable sliderOptions per inserire ancora piu intervalli nella selezione

Nel caso in cui vi sentiate coraggiosi e ne volete inserire dei nuovi buona fortuna!
Per inserire dei parametri bool usate questa funzione

`
menu:addCheckmarkMenuItem("Tilt Controls", useAccelerometer, function(value)
    useAccelerometer = value
end)
`

Trovate tutto qui
[link](https://sdk.play.date/3.0.3/Inside%20Playdate.html#system-menu)


### Gestione UI

La UI e' gestita unicamente nel file UI.lua
Usa la funzione draw per inserire tutto cio di cui hai bisogno.
Vedi sempio...

[Font](https://sdk.play.date/3.0.3/Inside%20Playdate.html#C-graphics.font)
[TEXT](https://sdk.play.date/3.0.3/Inside%20Playdate.html#_drawing_text)

## Linux build command

``
export PLAYDATE_SDK_PATH=~/SDK/PlaydateSDK-3.0.3 && ~/SDK/PlaydateSDK-3.0.3/bin/pdc source/ jam_date.pdx
``