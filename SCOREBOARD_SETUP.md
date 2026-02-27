# 🏆 Playdate Scoreboard Integration

Il gioco è ora integrato con l'API Scoreboard ufficiale di Playdate, che sincronizza i punteggi con i server di Panic.

## 📋 Setup Iniziale

### 1. Configurare il Bundle ID in `pdxinfo`
Assicurati che il file `jam_date.pdx/pdxinfo` contenga un bundle ID valido:

```
bundle_id=com.yourname.jam_date
```

### 2. Creare il Scoreboard nel Dev Portal
1. Vai su https://play.date/dev/catalog
2. Nel tuo gioco, vai a **Scoreboards**
3. Crea un nuovo scoreboard con:
   - **Board ID**: `highscores` (oppure personalizza in DataManager.lua)
   - **Board Name**: "High Scores"
   - **Sorting**: Descending (high-to-low)
   - **Type**: Regular (o Daily se preferisci)

### 3. Aggiornare il Board ID in DataManager (opzionale)
Se hai usato un Board ID diverso da `highscores`, aggiorna [DataManager.lua](DataManager.lua#L11):

```lua
local SCOREBOARD_ID = "il_tuo_board_id"
```

## 🎮 Come Funziona

### Salvataggio Automatico
- **Locale**: Tutti i risultati delle run vengono salvati in `jam_date_data/leaderboard.json`
- **Server**: I punteggi vengono automaticamente postati al server Playdate quando connesso

### Sincronizzazione
- I punteggi vengono accodati automaticamente se offline
- Vengono inviati al server non appena disponibile la connessione WiFi
- Se offline, viene usata la cache locale

### Leaderboard Screen
Nella schermata leaderboard puoi:
- **[<] [>]**: Cambiare ordinamento (Score, Time, Enemies)
- **[↑]**: Sincronizzare e fetchare i top scores dal server
- **[↓]**: Scorrere la lista
- **Crank**: Navigazione veloce

Quando i dati vengono sincronizzati dal server, vedrai `[SERVER]` nell'header.

## 🔧 Configurazione Avanzata

### Disabilitare la Sincronizzazione Online
Se desideri usare solo il salvataggio locale (senza connessione ai server Playdate), modifica [DataManager.lua](DataManager.lua#L13):

```lua
local USE_PLAYDATE_SCOREBOARD = false
```

### Variabili di Configurazione in DataManager.lua
```lua
local DATA_FOLDER = "jam_date_data"           -- Cartella per salvataggio locale
local LEADERBOARD_FILE = "leaderboard.json"   -- Nome file locale
local MAX_LEADERBOARD_ENTRIES = 50            -- Max entries da mantenere
local SCOREBOARD_ID = "highscores"            -- Board ID dal Dev Portal
local USE_PLAYDATE_SCOREBOARD = true          -- Abilita sincronizzazione
```

## 🧪 Testing

### Nel Simulator
1. **Registra** il simulator con il tuo account Playdate (clicca su "Register")
2. I punteggi postati appariranno nel tuo Dev Portal
3. Nota: Punteggi dal simulator ≠ punteggi da device

### Su Device
1. **Importante**: Carica il gioco via USB, non wireless sideload (alteras il bundle ID!)
2. Il device deve avere WiFi attivo per sincronizzare
3. Se offline, i punteggi vengono accodati localmente
4. Email `catalog-dev@play.date` per resettare i test scores

## 📊 API Methods Disponibili

### DataManager
```lua
-- Salva risultato run e lo posta al server
addRunResult(result)

-- Fetch top scores dal server
fetchScoresFromServer(callback)

-- Sincronizza i punteggi locali al server
syncLocalToServer()

-- Recupera personal best dai server
getPersonalBest(callback)

-- Verifica se sincronizzazione online è disponibile
isOnlineSyncAvailable()

-- Query leaderboard locale
getTopScores(limit)
getTopTimeAlive(limit)
getTopEnemiesDefeated(limit)
```

## ⚠️ Note Importanti

1. **Bundle ID**: Deve essere uguale sia nel simulator che sul device - altrimenti i punteggi non sincronizzeranno
2. **Connection**: La sincronizzazione è asincrona e può prendere fino a 10 secondi su WiFi lento
3. **Offline Mode**: Il fallback locale funziona sempre, anche senza WiFi
4. **Caching**: I dati vengono cachati localmente per performance e offline play
5. **Clearing Scores**: Contatta Panic per resettare i test scores dal Dev Portal

## 🚀 Deploy per Catalog

1. Assicurati che il bundle ID sia corretto
2. Crea i scoreboards nel Dev Portal
3. Testa nel simulator e su device
4. Include il gioco nel tuo submission a Catalog
5. I punteggi appariranno automaticamente nella pagina del gioco su play.date

---

Per documentazione ufficiale, vedi: https://help.play.date/catalog-developer/scoreboard-api/
