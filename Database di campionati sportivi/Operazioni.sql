--Operazioni database

--O1: Inserire un campionato
INSERT INTO campionato (nazione, max_giocatori, min_giocatori) 
VALUES ("Italia", 30, 18);

--O2: Inserire una nuova stagione di una divisione
INSERT INTO divisione (nazione, id_divisione, inizio_stagione, fine_stagione, nome, n_promozioni, n_retrocessioni)
VALUES ("Italia", 1, STR_TO_DATE('31-08-2021', '%d-%m-%Y'), NULL, "Serie A", 0, 3);

--O3: Inserire una squadra
INSERT INTO squadra (nome, città, colori, allenatore, nazione, divisione, stadio)
VALUES ("U.S. Sassuolo", "Sassuolo", "nero verde", "Dionisi", "Italia", 1, "MAPEI Stadium");

--O4: Inserire una nuova partita
INSERT INTO partita (stadio, `data`, nazione, divisione, stagione, giornata, casa, trasferta, gol_casa, gol_trasferta)
VALUES ("MAPEI Stadium", "06/12/2021", "Italia", 1, "31/08/2021", 25, "U.S. Sassuolo", "S.S.C. Napoli", 2, 1);

--O5: Inserire una statistica per una partita
INSERT INTO statistichePartita (id_partita, giocatore, tipo_statistica)
VALUES (1, 12345, "gol");

--O6: Inserire un nuovo giocatore
INSERT INTO giocatore (nome, cognome, età, altezza, ruolo, nazionalità, squadra, piede_preferito, valore)
VALUES ("Domenico", "Berardi", 29, 182, "attaccante", "Italia", 123);

--O7: Inserire un trasferimento
INSERT INTO trasferimento (`data`, proprietario, acquirente, giocatore, valore, formula)
VALUES ("18/07/2021", 321, 123, 11111, 30000000, "acquisto");

--O8: Aprire una finestra di calciomercato
INSERT INTO calciomercato (nazione, sessione, data_inizio, data_fine)
VALUES ("Italia", "estiva", "01/07/2021", "01/09/2021")

--O9: Cambiare l'allenatore di una squadra
UPDATE squadra SET allenatore = "Inzaghi" WHERE matricola_squadra = 166

--O10: Visualizzare la bacheca trofei di una squadra
SELECT DISTINCT d.nome, COUNT(t.trofeo) AS trofei_vinti
FROM divisione d JOIN trofei t ON d.nazione = t.nazione AND t.trofeo = d.id_divisione
WHERE squadra = 13
GROUP BY t.trofeo

--O11: Visualizzare le statistiche di un giocatore nella stagione corrente
SELECT nome, cognome, gol, assist, ammonizioni, espulsioni
FROM giocatore
WHERE matricola_giocatore = 11111

--O12: Visualizzare la classifica di una divisione relativa alla stagione corrente
SELECT DISTINCT s.nome, s.punti, s.gol_fatti, s.gol_subiti, (s.gol_fatti-s.gol_subiti) AS diff_reti
FROM squadra s JOIN divisione d ON s.nazione = "Italia" AND s.divisione = 1 AND d.inizio_stagione = "2021-08-29"
ORDER BY s.punti DESC, diff_reti DESC

--O13: Visualizzare la top20 marcatori di una divisione relativa alla stagione corrente
SELECT g.cognome, g.gol
FROM divisione d    JOIN squadra s ON s.nazione = d.nazione AND s.divisione = d.id_divisione AND d.inizio_stagione = "2021-08-29"
                    JOIN giocatore g ON s.matricola_squadra = g.squadra
WHERE s.nazione = "Italia" AND s.divisione = 1
ORDER BY g.gol DESC
LIMIT 20

--O14: Visualizzare la classifica assistmen di una divisione relativa alla stagione corrente
SELECT g.cognome, g.assist
FROM divisione d    JOIN squadra s ON s.nazione = d.nazione AND s.divisione = d.id_divisione AND d.inizio_stagione = "2021-08-29"
                    JOIN giocatore g ON s.matricola_squadra = g.squadra
WHERE s.nazione = "Italia" AND s.divisione = 1
ORDER BY g.assist DESC
LIMIT 20

--O15: Visualizzare l'albo d'oro di una divisione
SELECT s.nome, COUNT(t.trofeo) as vittorie
FROM divisione d    JOIN trofei t ON d.nazione = t.nazione AND d.id_divisione = t.trofeo
                    JOIN squadra s ON t.matricola_squadra = s.matricola_squadra
WHERE d.nazione = "Italia" AND d.id_divisione = 1
GROUP BY s.nome
ORDER BY COUNT(t.trofeo)

--O16: Visualizzare le ultime n partite di una squadra
SELECT p.id_partita, p.stadio, p.data, p.nazione, p.divisione, p.stagione, p.casa, p.trasferta, p.gol_casa, p.gol_trasferta
FROM partita p JOIN squadra s ON p.casa = s.matricola_squadra OR p.trasferta = s.matricola_squadra
WHERE s.nome = "Sassuolo"
ORDER BY p.data DESC
LIMIT 5

--O17: Visualizzare la classifica di una divisione relativa ad una stagione già conclusa
SELECT sd.squadra, sd.punti, sd.gol_fatti, sd.gol_subiti, (sd.gol_fatti-sd.gol_subiti) AS diff_reti
FROM storicoDivisioni sd JOIN divisione d ON sd.nazione = d.nazione AND sd.divisione = d.id_divisione AND sd.stagione = d.inizio_stagione
WHERE sd.nazione = "Italia" AND sd.divisione = 1 AND sd.stagione = "2012-08-29"
ORDER BY sd.punti DESC

--O18: Visualizzare la classifica marcatori di una divisione relativa ad una stagione già conclusa
SELECT sm.giocatore, sm.squadra, sm.n_gol
FROM storicoMarcatori sm JOIN divisione d ON sm.nazione = d.nazione AND sm.divisione = d.id_divisione AND sm.stagione = d.inizio_stagione
WHERE sm.nazione = "Italia" AND sm.divisione = 1 AND sm.stagione = "2012-08-29"
ORDER BY sm.n_gol DESC

--O19: Visualizzare la classifica assistmen di una divisione relativa ad una stagione già conclusa
SELECT sa.giocatore, sa.squadra, sa.n_assist
FROM storicoAssistmen sa JOIN divisione d ON sa.nazione = d.nazione AND sa.divisione = d.id_divisione AND sa.stagione = d.inizio_stagione
WHERE sa.nazione = "Italia" AND sa.divisione = 1 AND sa.stagione = "2012-08-29"
ORDER BY sa.n_assist DESC

--O20: Visualizzare i trasferimenti dell'ultima sessione di calciomercato in ordine discendente di valore
SELECT *
FROM trasferimento t
WHERE t.data    BETWEEN 
                (SELECT data_inizio FROM calciomercato ORDER BY data_inizio DESC LIMIT 1) 
                AND 
                (SELECT data_fine FROM calciomercato ORDER BY data_inizio DESC LIMIT 1)
ORDER BY t.valore DESC

--O21: Visualizzare gli n giocatori con più gol in carriera
SELECT sm.giocatore, g.nome, g.cognome, SUM(sm.n_gol)
FROM storicoMarcatori sm JOIN giocatore g ON sm.giocatore = g.matricola_giocatore
GROUP BY sm.giocatore
LIMIT 5;

--O22: Visualizza le statistiche realizzative della carriera di un giocatore
CREATE VIEW gol_totali AS
SELECT giocatore, SUM(n_gol) AS gol, COUNT(*) AS n_stagioni
FROM storicoMarcatori
WHERE giocatore = 11111

CREATE VIEW assist_totali AS
SELECT giocatore, SUM(n_assist) AS assist
FROM storicoAssistmen
WHERE giocatore = 11111

SELECT g.matricola_giocatore, g.nome, g.cognome, gtot.gol, atot.assist, gtot.n_stagioni
FROM gol_totali gtot NATURAL JOIN assist_totali atot JOIN giocatore g ON g.matricola_giocatore = gtot.giocatore

--O23: Visualizza per quali squadre un giocatore ha giocato
CREATE VIEW player_stats AS
SELECT giocatore, squadra, stagione
FROM storicoMarcatori
WHERE giocatore = 11111 

SELECT ps.giocatore, g.nome, g.cognome, ps.squadra, ps.stagione
FROM player_stats ps NATURAL JOIN giocatore g










