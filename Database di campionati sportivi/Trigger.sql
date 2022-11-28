--Triggers per il database

--T1: Archiviare i dati di una stagione conclusa

DELIMITER $$ --questo trigger archivia le statistiche della stagione alla fine di tutte le sue partite e le resetta
CREATE TRIGGER archive_season 
AFTER UPDATE ON divisione
FOR EACH ROW
BEGIN
    IF (OLD.fine_stagione IS NULL AND NEW.fine_stagione IS NOT NULL) THEN
        INSERT INTO storicoDivisioni(nazione, divisione, stagione, squadra, punti, gol_fatti, gol_subiti)
        SELECT s.nazione, s.divisione, NEW.inizio_stagione, s.matricola_squadra, s.punti, s.gol_fatti, s.gol_subiti
        FROM squadra s
        WHERE s.nazione = NEW.nazione AND s.divisione = NEW.id_divisione;

        INSERT INTO storicoMarcatori(nazione, divisione, stagione, giocatore, n_gol)
        SELECT NEW.nazione, NEW.id_divisione, NEW.inizio_stagione, g.matricola_giocatore, g.gol
        FROM giocatore g    JOIN squadra s ON g.squadra = s.matricola_squadra 
        WHERE s.nazione = NEW.nazione AND s.divisione = NEW.id_divisione;

        INSERT INTO storicoAssistmen(nazione, divisione, stagione, giocatore, n_assist)
        SELECT NEW.nazione, NEW.id_divisione, NEW.inizio_stagione, g.matricola_giocatore, g.assist
        FROM giocatore g    JOIN squadra s ON g.squadra = s.matricola_squadra 
        WHERE s.nazione = NEW.nazione AND s.divisione = NEW.id_divisione;

        UPDATE giocatore
        SET giocatore.espulsioni = 0, giocatore.ammonizioni = 0, giocatore.gol = 0, giocatore.assist = 0
        WHERE giocatore.squadra IN (SELECT matricola_squadra FROM squadra WHERE nazione = NEW.nazione AND divisione = NEW.id_divisione);

        UPDATE squadra
        SET squadra.punti = 0, squadra.gol_fatti = 0, squadra.gol_subiti = 0
        WHERE NEW.nazione = squadra.nazione AND NEW.id_divisione = squadra.divisione;
    END IF;
END $$
DELIMITER ;

-- T2: Convalidare un trasferimento

DELIMITER $$ -- questo trigger controlla se un trasferimento può essere completato
CREATE TRIGGER validate_transfer 
BEFORE INSERT ON trasferimento
FOR EACH ROW
BEGIN
    DECLARE last_transfer_window_start date;
    DECLARE last_transfer_window_end date;
    DECLARE n_players tinyint;
    DECLARE min_players tinyint;
    DECLARE max_players tinyint;
    
    SELECT data_inizio, data_fine INTO last_transfer_window_start, last_transfer_window_end
    FROM calciomercato
    ORDER BY data_inizio DESC
    LIMIT 1;

    IF (NEW.data NOT BETWEEN last_transfer_window_start AND last_transfer_window_end) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Il calciomercato è chiuso, non puoi effettuare trasferimenti.";
    END IF;


    IF (NEW.proprietario IS NULL AND NEW.acquirente IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Per effettuare un trasferimento di qualsiasi tipo, almeno uno tra il proprietario e l'acquirente deve essere valido.";
    END IF;

    SELECT COUNT(g.matricola_giocatore) INTO n_players
    FROM giocatore g
    WHERE g.squadra = NEW.acquirente;

    SELECT max_giocatori, min_giocatori INTO max_players, min_players
    FROM campionato c
    WHERE c.nazione =   ( 
                            SELECT nazione
                            FROM squadra
                            WHERE squadra.matricola_squadra = NEW.acquirente
                        );

    IF (NEW.acquirente IS NOT NULL AND n_players = max_players) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Impossibile effettuare il trasferimento: la squadra acquirente ha troppi giocatori secondo le regole del campionato.";
    END IF;

    IF (NEW.acquirente IS NULL AND n_players = min_players) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Impossibile effettuare lo svincolo: la squadra proprietaria rimarrebbe con troppi pochi giocatori secondo le regole del campionato.";
    END IF;

    IF (NEW.proprietario IS NULL) THEN
        
        UPDATE trasferimento
        SET valore = 0
        WHERE id = NEW.id;
    END IF; 

    IF (NEW.acquirente IS NULL) THEN 
        
        UPDATE trasferimento
        SET valore = 0
        WHERE id = NEW.id;
    END IF; 


    UPDATE giocatore
    SET giocatore.squadra = NEW.acquirente
    WHERE giocatore.matricola_giocatore = NEW.giocatore;
END $$
DELIMITER ;


--T3: Aggiornare le statistiche di una divisione

DELIMITER $$
CREATE TRIGGER season_management
AFTER INSERT ON partita
FOR EACH ROW
BEGIN
    --modifico entità divisione
    UPDATE divisione
    SET divisione.partite_giocate = divisione.partite_giocate + 1
    WHERE divisione.nazione = NEW.nazione AND divisione.id_divisione = NEW.divisione;

    --modifico statistiche squadre
    IF(NEW.gol_casa > NEW.gol_trasferta) THEN
        UPDATE squadra
        SET squadra.punti = squadra.punti + 3
        WHERE squadra.matricola_squadra = NEW.casa;
    ELSEIF (NEW.gol_casa = NEW.gol_trasferta) THEN
        UPDATE squadra
        SET squadra.punti = squadra.punti + 1
        WHERE squadra.matricola_squadra = NEW.casa AND squadra.matricola_squadra = NEW.trasferta;
    ELSE
        UPDATE squadra
        SET squadra.punti = squadra.punti + 3
        WHERE squadra.matricola_squadra = NEW.gol_trasferta;
    END IF;

    UPDATE squadra
    SET squadra.gol_fatti = squadra.gol_fatti + NEW.gol_casa, squadra.gol_subiti = squadra.gol_subiti + NEW.gol_trasferta
    WHERE NEW.casa = squadra.matricola_squadra;

    UPDATE squadra
    SET squadra.gol_fatti = squadra.gol_fatti + NEW.gol_trasferta, squadra.gol_subiti = squadra.gol_subiti + NEW.gol_casa
    WHERE NEW.trasferta = squadra.matricola_squadra;
END $$
DELIMITER ;

-- T4: Termina la stagione
DELIMITER $$
CREATE TRIGGER end_season
AFTER INSERT ON partita
FOR EACH ROW
BEGIN
    DECLARE played_matches smallint;
    DECLARE total_matches smallint;
    DECLARE winner int;
    DECLARE winner_nation varchar(32);
    DECLARE winner_trophy tinyint;

    SELECT d.partite_giocate, d.partite_totali INTO played_matches, total_matches
    FROM divisione d
    WHERE d.nazione = NEW.nazione AND d.id_divisione = NEW.divisione AND d.inizio_stagione = NEW.stagione;

    IF (played_matches = total_matches) THEN
        UPDATE divisione
        SET divisione.fine_stagione = NEW.data
        WHERE divisione.nazione = NEW.nazione AND divisione.id_divisione = NEW.divisione AND divisione.inizio_stagione = NEW.stagione;

        SELECT s.matricola_squadra INTO winner
        FROM divisione d JOIN squadra s ON d.nazione = s.nazione AND d.id_divisione = s.divisione
        WHERE d.inizio_stagione = NEW.stagione
        ORDER BY s.punti DESC, s.gol_fatti DESC
        LIMIT 1;

        SELECT nazione INTO winner_nation FROM squadra WHERE matricola_squadra = winner;
        SELECT divisione INTO winner_trophy FROM squadra WHERE matricola_squadra = winner;
        
        INSERT INTO trofei(matricola_squadra, nazione, trofeo, stagione)
        VALUES(winner, winner_nation, winner_trophy, NEW.stagione);
    END IF;
END $$
DELIMITER ;

--T5: Aggiornare le statistiche di un giocatore
DELIMITER $$
CREATE TRIGGER update_stats
AFTER INSERT ON statistichePartita
FOR EACH ROW
BEGIN
    IF (NEW.tipo_statistica = 'assist') THEN
        UPDATE giocatore
        SET giocatore.assist = giocatore.assist + NEW.quantità
        WHERE NEW.giocatore = giocatore.matricola_giocatore;
    END IF;

    IF (NEW.tipo_statistica = 'gol') THEN
        UPDATE giocatore
        SET giocatore.gol = giocatore.gol + NEW.quantità
        WHERE NEW.giocatore = giocatore.matricola_giocatore;
    END IF;

    IF (NEW.tipo_statistica = 'ammonizione') THEN
        UPDATE giocatore
        SET giocatore.ammonizioni = giocatore.ammonizioni + NEW.quantità
        WHERE NEW.giocatore = giocatore.matricola_giocatore;
    END IF;

    IF (NEW.tipo_statistica = 'espulsioni') THEN
        UPDATE giocatore
        SET giocatore.espulsioni = giocatore.espulsioni + NEW.quantità
        WHERE NEW.giocatore = giocatore.matricola_giocatore;
    END IF;
END $$
DELIMITER ;

--T6: Iniziare una nuova stagione applicando promozioni e retrocessioni
DELIMITER $$
CREATE TRIGGER start_new_season
BEFORE INSERT ON divisione
FOR EACH ROW
BEGIN
    DECLARE current_season date;
    DECLARE first_division tinyint DEFAULT 0;
    DECLARE last_division tinyint DEFAULT 254;
    DECLARE promotions tinyint;
    DECLARE relegations tinyint;

    --controllo preliminare per il primo uso del database
    IF (1 <= (SELECT COUNT(*) FROM divisione)) THEN
        SELECT MAX(d.inizio_stagione) INTO current_season
        FROM divisione d
        WHERE NEW.nazione = d.nazione AND NEW.id_divisione = d.id_divisione;
    --controllo se esistono divisioni non ancora concluse: se sì, non posso aggiungere altre divisioni
        IF EXISTS   (  
                    SELECT *
                    FROM divisione d 
                    WHERE NEW.nazione = d.nazione AND d.inizio_stagione = current_season AND d.fine_stagione IS NULL
                    )
        THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Prima di aggiungere nuove divisioni, devono concludersi quelle della stagione corrente.";
        ELSE 

            SELECT MIN(d.id_divisione), MAX(d.id_divisione) INTO first_division, last_division
            FROM divisione d
            WHERE NEW.nazione = d.nazione;
            
            SELECT d.n_promozioni, d.n_retrocessioni INTO promotions, relegations
            FROM divisione d
            WHERE NEW.nazione = d.nazione AND NEW.id_divisione = d.id_divisione AND d.inizio_stagione = current_season;

            IF (first_division != last_division) THEN           --se non c'è una sola stagione in quel campionato
                IF (first_division != NEW.id_divisione) THEN    --se non sto creando una nuova stagione della prima divisione
                                                                --promuovi le squadre di questa divisione in quella superiore
                    
                    UPDATE squadra
                    SET squadra.divisione = squadra.divisione - 1
                    WHERE squadra.nazione = NEW.nazione AND squadra.matricola_squadra IN  ( SELECT * FROM (    
                                                            SELECT s.matricola_squadra
                                                            FROM divisione d JOIN squadra s ON s.nazione = NEW.nazione AND s.divisione = NEW.id_divisione
                                                            WHERE d.inizio_stagione = current_season
                                                            ORDER BY s.punti DESC, (s.gol_fatti-s.gol_subiti) DESC
                                                            LIMIT promotions) promoted_in_upper_division
                                                        );
                                                                --retrocedi le squadre della divisione superiore in quella corrente
                    UPDATE squadra
                    SET squadra.divisione = squadra.divisione + 1
                    WHERE squadra.nazione = NEW.nazione AND squadra.matricola_squadra IN  ( SELECT * FROM ( 
                                                            SELECT s.matricola_squadra
                                                            FROM divisione d JOIN squadra s ON s.nazione = NEW.nazione AND s.divisione = NEW.id_divisione-1
                                                            WHERE d.inizio_stagione = current_season
                                                            ORDER BY s.punti ASC, (s.gol_fatti-s.gol_subiti) ASC
                                                            LIMIT relegations) relegated_in_current_division
                                                        );
                END IF;
                                                                --promuovi le squadre della divisione inferiore in questa divisione
                    UPDATE squadra
                    SET squadra.divisione = squadra.divisione - 1
                    WHERE squadra.nazione = NEW.nazione AND squadra.matricola_squadra IN  ( SELECT * FROM (  
                                                            SELECT s.matricola_squadra
                                                            FROM divisione d JOIN squadra s ON s.nazione = NEW.nazione AND s.divisione = NEW.id_divisione+1
                                                            WHERE d.inizio_stagione = current_season
                                                            ORDER BY s.punti DESC, (s.gol_fatti-s.gol_subiti) DESC
                                                            LIMIT promotions) promoted_in_current_division
                                                        );                     
                                                                --retrocedi le squadre di questa divisione in quella inferiore
                    UPDATE squadra
                    SET squadra.divisione = squadra.divisione + 1
                    WHERE squadra.matricola_squadra IN  (  SELECT * FROM (
                                                            SELECT s.matricola_squadra
                                                            FROM divisione d JOIN squadra s ON s.nazione = NEW.nazione AND s.divisione = NEW.id_divisione+1
                                                            WHERE d.inizio_stagione = current_season
                                                            ORDER BY s.punti ASC, (s.gol_fatti-s.gol_subiti) ASC
                                                            LIMIT relegations) relegated_in_lower_division
                                                        );
            END IF;
        END IF;
    END IF;
END $$
DELIMITER ;







