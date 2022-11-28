-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Creato il: Nov 18, 2021 alle 14:31
-- Versione del server: 10.4.20-MariaDB
-- Versione PHP: 8.0.9

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `calcio`
--

-- --------------------------------------------------------

--
-- Struttura stand-in per le viste `assist_totali`
-- (Vedi sotto per la vista effettiva)
--
CREATE TABLE `assist_totali` (
`giocatore` int(10) unsigned
,`assist` decimal(26,0)
);

-- --------------------------------------------------------

--
-- Struttura della tabella `calciomercato`
--

CREATE TABLE `calciomercato` (
  `id_sessione` int(10) UNSIGNED NOT NULL,
  `nazione` varchar(32) NOT NULL,
  `data_inizio` date NOT NULL,
  `data_fine` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dump dei dati per la tabella `calciomercato`
--


-- --------------------------------------------------------

--
-- Struttura della tabella `campionato`
--

CREATE TABLE `campionato` (
  `nazione` varchar(32) NOT NULL,
  `min_giocatori` tinyint(3) UNSIGNED NOT NULL,
  `max_giocatori` tinyint(3) UNSIGNED NOT NULL
) ;

--
-- Dump dei dati per la tabella `campionato`
--


-- --------------------------------------------------------

--
-- Struttura della tabella `divisione`
--

CREATE TABLE `divisione` (
  `nazione` varchar(32) NOT NULL,
  `id_divisione` tinyint(3) UNSIGNED NOT NULL,
  `inizio_stagione` date NOT NULL,
  `fine_stagione` date DEFAULT NULL,
  `nome` varchar(32) NOT NULL,
  `n_partecipanti` tinyint(3) UNSIGNED NOT NULL,
  `n_promozioni` tinyint(3) UNSIGNED NOT NULL,
  `n_retrocessioni` tinyint(3) UNSIGNED NOT NULL,
  `partite_giocate` smallint(5) UNSIGNED NOT NULL,
  `partite_totali` smallint(5) UNSIGNED NOT NULL
) ;

--
-- Dump dei dati per la tabella `divisione`
--

--
-- Trigger `divisione`
--
DELIMITER $$
CREATE TRIGGER `archive_season` BEFORE UPDATE ON `divisione` FOR EACH ROW BEGIN
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
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struttura della tabella `giocatore`
--

CREATE TABLE `giocatore` (
  `matricola_giocatore` int(10) UNSIGNED NOT NULL,
  `cognome` varchar(32) NOT NULL,
  `nome` varchar(32) NOT NULL,
  `età` tinyint(3) UNSIGNED NOT NULL,
  `altezza` tinyint(3) UNSIGNED NOT NULL,
  `ruolo` varchar(20) NOT NULL,
  `nazionalità` varchar(32) NOT NULL,
  `squadra` int(10) UNSIGNED DEFAULT NULL,
  `piede_preferito` varchar(10) NOT NULL,
  `espulsioni` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `ammonizioni` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `gol` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `assist` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `valore` int(10) UNSIGNED NOT NULL DEFAULT 0
) ;

--
-- Dump dei dati per la tabella `giocatore`
--


-- --------------------------------------------------------

--
-- Struttura stand-in per le viste `gol_totali`
-- (Vedi sotto per la vista effettiva)
--
CREATE TABLE `gol_totali` (
`giocatore` int(10) unsigned
,`gol` decimal(32,0)
,`n_stagioni` bigint(21)
);

-- --------------------------------------------------------

--
-- Struttura della tabella `partita`
--

CREATE TABLE `partita` (
  `id_partita` int(10) UNSIGNED NOT NULL,
  `stadio` int(10) UNSIGNED NOT NULL,
  `data` date NOT NULL,
  `nazione` varchar(32) NOT NULL,
  `divisione` tinyint(3) UNSIGNED NOT NULL,
  `stagione` date NOT NULL,
  `giornata` tinyint(3) UNSIGNED NOT NULL,
  `casa` int(10) UNSIGNED NOT NULL,
  `trasferta` int(10) UNSIGNED NOT NULL,
  `gol_casa` tinyint(3) UNSIGNED NOT NULL,
  `gol_trasferta` tinyint(3) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dump dei dati per la tabella `partita`
--

--
-- Trigger `partita`
--
DELIMITER $$
CREATE TRIGGER `end_season` AFTER INSERT ON `partita` FOR EACH ROW BEGIN
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
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `season_management` AFTER INSERT ON `partita` FOR EACH ROW BEGIN
    -- modifico entità divisione
    UPDATE divisione
    SET divisione.partite_giocate = divisione.partite_giocate + 1
    WHERE divisione.nazione = NEW.nazione AND divisione.id_divisione = NEW.divisione;

    -- modifico statistiche squadre
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
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struttura della tabella `squadra`
--

CREATE TABLE `squadra` (
  `matricola_squadra` int(10) UNSIGNED NOT NULL,
  `nome` varchar(40) NOT NULL,
  `città` varchar(40) NOT NULL,
  `colori` varchar(32) NOT NULL,
  `allenatore` varchar(64) NOT NULL,
  `nazione` varchar(32) NOT NULL,
  `divisione` tinyint(3) UNSIGNED NOT NULL,
  `punti` tinyint(4) NOT NULL DEFAULT 0,
  `gol_fatti` smallint(5) NOT NULL DEFAULT 0,
  `gol_subiti` smallint(5) NOT NULL DEFAULT 0
) ;

--
-- Dump dei dati per la tabella `squadra`
--



-- --------------------------------------------------------

--
-- Struttura della tabella `stadio`
--

CREATE TABLE `stadio` (
  `id` int(10) UNSIGNED NOT NULL,
  `nome` varchar(64) NOT NULL,
  `squadra` int(10) UNSIGNED NOT NULL,
  `capienza` int(10) UNSIGNED NOT NULL,
  `città` varchar(40) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dump dei dati per la tabella `stadio`
--



-- --------------------------------------------------------

--
-- Struttura della tabella `statistichepartita`
--

CREATE TABLE `statistichepartita` (
  `id_partita` int(10) UNSIGNED NOT NULL,
  `giocatore` int(10) UNSIGNED NOT NULL,
  `tipo_statistica` varchar(16) NOT NULL,
  `quantità` tinyint(4) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Trigger `statistichepartita`
--
DELIMITER $$
CREATE TRIGGER `update_stats` AFTER INSERT ON `statistichepartita` FOR EACH ROW BEGIN
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
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struttura della tabella `storicoassistmen`
--

CREATE TABLE `storicoassistmen` (
  `nazione` varchar(32) NOT NULL,
  `divisione` tinyint(3) UNSIGNED NOT NULL,
  `stagione` date NOT NULL,
  `giocatore` int(10) UNSIGNED NOT NULL,
  `n_assist` tinyint(4) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dump dei dati per la tabella `storicoassistmen`
--



-- --------------------------------------------------------

--
-- Struttura della tabella `storicodivisioni`
--

CREATE TABLE `storicodivisioni` (
  `nazione` varchar(32) NOT NULL,
  `divisione` tinyint(3) UNSIGNED NOT NULL,
  `stagione` date NOT NULL,
  `squadra` smallint(5) UNSIGNED NOT NULL,
  `punti` tinyint(4) NOT NULL,
  `gol_fatti` tinyint(3) UNSIGNED NOT NULL,
  `gol_subiti` tinyint(3) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dump dei dati per la tabella `storicodivisioni`
--



-- --------------------------------------------------------

--
-- Struttura della tabella `storicomarcatori`
--

CREATE TABLE `storicomarcatori` (
  `nazione` varchar(32) NOT NULL,
  `divisione` tinyint(3) UNSIGNED NOT NULL,
  `stagione` date NOT NULL,
  `giocatore` int(10) UNSIGNED NOT NULL,
  `n_gol` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dump dei dati per la tabella `storicomarcatori`
--



-- --------------------------------------------------------

--
-- Struttura della tabella `trasferimento`
--

CREATE TABLE `trasferimento` (
  `id` int(10) UNSIGNED NOT NULL,
  `id_sessione` int(10) UNSIGNED NOT NULL,
  `data` date NOT NULL,
  `proprietario` int(10) UNSIGNED DEFAULT NULL,
  `acquirente` int(10) UNSIGNED DEFAULT NULL,
  `giocatore` int(10) UNSIGNED NOT NULL,
  `valore` int(10) UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dump dei dati per la tabella `trasferimento`
--


--
-- Trigger `trasferimento`
--
DELIMITER $$
CREATE TRIGGER `validate_transfer` BEFORE INSERT ON `trasferimento` FOR EACH ROW BEGIN
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
        SET formula = 'acquisto'
        WHERE id = NEW.id;
        
        UPDATE trasferimento
        SET valore = 0
        WHERE id = NEW.id;
    END IF; 

    IF (NEW.acquirente IS NULL) THEN 
    	UPDATE trasferimento
        SET formula = 'svincolo'
        WHERE id = NEW.id;
        
        UPDATE trasferimento
        SET valore = 0
        WHERE id = NEW.id;
    END IF; 


    UPDATE giocatore
    SET giocatore.squadra = NEW.acquirente
    WHERE giocatore.matricola_giocatore = NEW.giocatore;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struttura della tabella `trofei`
--

CREATE TABLE `trofei` (
  `matricola_squadra` int(10) UNSIGNED NOT NULL,
  `nazione` varchar(32) NOT NULL,
  `trofeo` tinyint(3) UNSIGNED NOT NULL,
  `stagione` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dump dei dati per la tabella `trofei`
--


-- --------------------------------------------------------

--
-- Struttura per vista `assist_totali`
--
DROP TABLE IF EXISTS `assist_totali`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `assist_totali`  AS SELECT `storicoassistmen`.`giocatore` AS `giocatore`, sum(`storicoassistmen`.`n_assist`) AS `assist` FROM `storicoassistmen` WHERE `storicoassistmen`.`giocatore` = 1 ;

-- --------------------------------------------------------

--
-- Struttura per vista `gol_totali`
--
DROP TABLE IF EXISTS `gol_totali`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `gol_totali`  AS SELECT `storicomarcatori`.`giocatore` AS `giocatore`, sum(`storicomarcatori`.`n_gol`) AS `gol`, count(0) AS `n_stagioni` FROM `storicomarcatori` WHERE `storicomarcatori`.`giocatore` = 1 ;

--
-- Indici per le tabelle scaricate
--

--
-- Indici per le tabelle `calciomercato`
--
ALTER TABLE `calciomercato`
  ADD PRIMARY KEY (`id_sessione`),
  ADD KEY `nazione` (`nazione`,`data_inizio`);

--
-- Indici per le tabelle `campionato`
--
ALTER TABLE `campionato`
  ADD PRIMARY KEY (`nazione`);

--
-- Indici per le tabelle `divisione`
--
ALTER TABLE `divisione`
  ADD PRIMARY KEY (`nazione`,`id_divisione`,`inizio_stagione`);

--
-- Indici per le tabelle `giocatore`
--
ALTER TABLE `giocatore`
  ADD PRIMARY KEY (`matricola_giocatore`),
  ADD KEY `squadra` (`squadra`);

--
-- Indici per le tabelle `partita`
--
ALTER TABLE `partita`
  ADD PRIMARY KEY (`id_partita`),
  ADD KEY `stadio` (`stadio`),
  ADD KEY `casa` (`casa`),
  ADD KEY `trasferta` (`trasferta`),
  ADD KEY `partita_ibfk_2` (`nazione`,`divisione`,`stagione`);

--
-- Indici per le tabelle `squadra`
--
ALTER TABLE `squadra`
  ADD PRIMARY KEY (`matricola_squadra`),
  ADD KEY `nazione` (`nazione`,`divisione`);

--
-- Indici per le tabelle `stadio`
--
ALTER TABLE `stadio`
  ADD PRIMARY KEY (`id`),
  ADD KEY `squadra` (`squadra`);

--
-- Indici per le tabelle `statistichepartita`
--
ALTER TABLE `statistichepartita`
  ADD PRIMARY KEY (`id_partita`,`giocatore`,`tipo_statistica`),
  ADD KEY `giocatore` (`giocatore`);

--
-- Indici per le tabelle `storicoassistmen`
--
ALTER TABLE `storicoassistmen`
  ADD PRIMARY KEY (`nazione`,`divisione`,`stagione`,`giocatore`);

--
-- Indici per le tabelle `storicodivisioni`
--
ALTER TABLE `storicodivisioni`
  ADD PRIMARY KEY (`nazione`,`divisione`,`stagione`,`squadra`);

--
-- Indici per le tabelle `storicomarcatori`
--
ALTER TABLE `storicomarcatori`
  ADD PRIMARY KEY (`nazione`,`divisione`,`stagione`,`giocatore`);

--
-- Indici per le tabelle `trasferimento`
--
ALTER TABLE `trasferimento`
  ADD PRIMARY KEY (`id`),
  ADD KEY `id_sessione` (`id_sessione`),
  ADD KEY `proprietario` (`proprietario`),
  ADD KEY `acquirente` (`acquirente`),
  ADD KEY `giocatore` (`giocatore`);

--
-- Indici per le tabelle `trofei`
--
ALTER TABLE `trofei`
  ADD PRIMARY KEY (`matricola_squadra`,`nazione`,`trofeo`,`stagione`),
  ADD KEY `nazione` (`nazione`,`trofeo`,`stagione`);

--
-- AUTO_INCREMENT per le tabelle scaricate
--

--
-- AUTO_INCREMENT per la tabella `calciomercato`
--
ALTER TABLE `calciomercato`
  MODIFY `id_sessione` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT per la tabella `giocatore`
--
ALTER TABLE `giocatore`
  MODIFY `matricola_giocatore` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT per la tabella `partita`
--
ALTER TABLE `partita`
  MODIFY `id_partita` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=251;

--
-- AUTO_INCREMENT per la tabella `squadra`
--
ALTER TABLE `squadra`
  MODIFY `matricola_squadra` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT per la tabella `stadio`
--
ALTER TABLE `stadio`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT per la tabella `trasferimento`
--
ALTER TABLE `trasferimento`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- Limiti per le tabelle scaricate
--

--
-- Limiti per la tabella `calciomercato`
--
ALTER TABLE `calciomercato`
  ADD CONSTRAINT `calciomercato_ibfk_1` FOREIGN KEY (`nazione`) REFERENCES `campionato` (`nazione`) ON DELETE CASCADE;

--
-- Limiti per la tabella `divisione`
--
ALTER TABLE `divisione`
  ADD CONSTRAINT `divisione_ibfk_1` FOREIGN KEY (`nazione`) REFERENCES `campionato` (`nazione`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limiti per la tabella `giocatore`
--
ALTER TABLE `giocatore`
  ADD CONSTRAINT `giocatore_ibfk_1` FOREIGN KEY (`squadra`) REFERENCES `squadra` (`matricola_squadra`) ON DELETE SET NULL;

--
-- Limiti per la tabella `partita`
--
ALTER TABLE `partita`
  ADD CONSTRAINT `partita_ibfk_1` FOREIGN KEY (`stadio`) REFERENCES `stadio` (`id`),
  ADD CONSTRAINT `partita_ibfk_2` FOREIGN KEY (`nazione`,`divisione`,`stagione`) REFERENCES `divisione` (`nazione`, `id_divisione`, `inizio_stagione`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `partita_ibfk_3` FOREIGN KEY (`casa`) REFERENCES `squadra` (`matricola_squadra`),
  ADD CONSTRAINT `partita_ibfk_4` FOREIGN KEY (`trasferta`) REFERENCES `squadra` (`matricola_squadra`);

--
-- Limiti per la tabella `squadra`
--
ALTER TABLE `squadra`
  ADD CONSTRAINT `squadra_ibfk_1` FOREIGN KEY (`nazione`,`divisione`) REFERENCES `divisione` (`nazione`, `id_divisione`);

--
-- Limiti per la tabella `stadio`
--
ALTER TABLE `stadio`
  ADD CONSTRAINT `stadio_ibfk_1` FOREIGN KEY (`squadra`) REFERENCES `squadra` (`matricola_squadra`);

--
-- Limiti per la tabella `statistichepartita`
--
ALTER TABLE `statistichepartita`
  ADD CONSTRAINT `statistichepartita_ibfk_1` FOREIGN KEY (`id_partita`) REFERENCES `partita` (`id_partita`) ON DELETE CASCADE,
  ADD CONSTRAINT `statistichepartita_ibfk_2` FOREIGN KEY (`giocatore`) REFERENCES `giocatore` (`matricola_giocatore`);

--
-- Limiti per la tabella `trasferimento`
--
ALTER TABLE `trasferimento`
  ADD CONSTRAINT `trasferimento_ibfk_1` FOREIGN KEY (`id_sessione`) REFERENCES `calciomercato` (`id_sessione`) ON DELETE CASCADE,
  ADD CONSTRAINT `trasferimento_ibfk_2` FOREIGN KEY (`proprietario`) REFERENCES `squadra` (`matricola_squadra`) ON DELETE CASCADE,
  ADD CONSTRAINT `trasferimento_ibfk_3` FOREIGN KEY (`acquirente`) REFERENCES `squadra` (`matricola_squadra`) ON DELETE CASCADE,
  ADD CONSTRAINT `trasferimento_ibfk_4` FOREIGN KEY (`giocatore`) REFERENCES `giocatore` (`matricola_giocatore`) ON DELETE CASCADE;

--
-- Limiti per la tabella `trofei`
--
ALTER TABLE `trofei`
  ADD CONSTRAINT `trofei_ibfk_1` FOREIGN KEY (`matricola_squadra`) REFERENCES `squadra` (`matricola_squadra`) ON DELETE CASCADE,
  ADD CONSTRAINT `trofei_ibfk_2` FOREIGN KEY (`nazione`,`trofeo`,`stagione`) REFERENCES `divisione` (`nazione`, `id_divisione`, `inizio_stagione`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
