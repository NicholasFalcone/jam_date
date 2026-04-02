# 🛠️ Configurazione Scoreboard - Checklist

## Passaggi Necessari

### 1️⃣ Aggiornare pdxinfo
Aggiungi il `bundle_id` al file `source/pdxinfo`:

```
name=Rail Gunner
author=4 gatti 
version=1.0.0
imagePath=images/meta_images
contentWarning=This game was made during PlayJam 9
pdxversion=30003
buildtime=824589740
bundle_id=com.4gatti.railgunner
```

**Importante**: 
- Il `bundle_id` deve essere univoco
- Formato tipico: `com.nomestudio.nomedgioco`
- Deve essere coerente tra simulator e device

### 2️⃣ Creare Scoreboard in Dev Portal

Vai su: https://play.date/dev/catalog

1. Seleziona il tuo gioco
2. Clicca su **Scoreboards** / **Leaderboards**
3. Crea nuovo board:
   - **Board ID**: `highscores` (oppure personalizza)
   - **Board Name**: "High Scores"
   - **Sort Direction**: Descending (punteggi più alti in alto)
   - **Board Type**: Regular (o Daily se vuoi reset giornaliero)

### 3️⃣ Personalizzare Board ID (Opzionale)

Se usi un board ID diverso da `highscores`, aggiorna `source/Core/DataManager.lua`:

```lua
local SCOREBOARD_ID = "il_tuo_board_id"
```

### 4️⃣ Test nel Simulator

1. Registra il simulator: 
   - Apri il simulator
   - Clicca su **Register** per associarlo al tuo account Panic
   
2. Gioca alcune partite e osserva come i punteggi vengono sincronizzati

3. Controlla il Dev Portal - vedrai i punteggi nella sezione Scoreboards

### 5️⃣ Test su Device

1. **Carica il gioco via USB** (non wireless sideload!)
   - Wireless sideload modifica il bundle ID, causando desincronizzazione
   
2. Assicurati di avere WiFi attivo

3. Gioca e verifica che i punteggi vengano sincronizzati

---

## 📝 File Modificati

- [source/Core/DataManager.lua](source/Core/DataManager.lua) - ✅ Integrazione API Scoreboard
- [source/Core/LeaderboardScreen.lua](source/Core/LeaderboardScreen.lua) - ✅ UI per fetching dal server
- [source/pdxinfo](source/pdxinfo) - ⚠️ **RICHIESTO**: Aggiungi `bundle_id`

---

## 🎯 Features Implementate

| Feature | Status | Note |
|---------|--------|------|
| Salvataggio locale | ✅ | JSON file `jam_date_data/leaderboard.json` |
| Sincronizzazione server | ✅ | Automatica quando online |
| Fetch top scores | ✅ | Premere `[↑]` nella leaderboard |
| Personal best | ✅ | Metodo disponibile |
| Offline queue | ✅ | Punteggi accodati se offline |
| Multiple sort modes | ✅ | Score / Time / Enemies |
| Fallback locale | ✅ | Funziona sempre senza internet |

---

## 🔍 Debugging

### Controllare lo stato di connessione
Nel file [DataManager.lua](source/Core/DataManager.lua#L203):
```lua
if dataManager:isOnlineSyncAvailable() then
    -- Scoreboard API disponibile
end
```

### Verificare che il bundle ID sia corretto
Nel simulator, controlla la console per eventuali errori di autenticazione.

### Se i punteggi non compaiono nel Dev Portal
1. Verifica il `bundle_id` nel pdxinfo
2. Registra il simulator se non ancora fatto
3. Assicurati che il board ID corrisponda
4. Verifica di avere connessione WiFi

---

## 📚 Documentazione Ufficiale

- [Playdate Scoreboard API Docs](https://help.play.date/catalog-developer/scoreboard-api/)
- [Dev Portal](https://play.date/dev/catalog)
- Contatti con issues: catalog-dev@play.date
