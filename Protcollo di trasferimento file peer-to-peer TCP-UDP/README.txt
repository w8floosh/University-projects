ATTENZIONE: 
Il programma richiede che i file da condividere siano già fisicamente presenti nella stessa cartella del file client.c.
Ci sono 12 file di testo già pronti che si possono dividere tra i vari client a piacimento.

/-//-//-//-//-/ LOGICA DEL PROGRAMMA /-//-//-//-//-/

CLIENT
Il client prima controlla il numero di argomenti del comando di avvio e poi crea una socket (srvcommsockfd) per controllare se il server è attivo (dopo 2 secondi senza risposta il programma si autoterminerà), per comunicare al server i dati di login e ricevere la conferma di login.

Uso la porta UDP successiva alla porta di ascolto del server per mandargli i comandi e riceverne l’output, dato che la porta di ascolto resterà sempre attiva per accogliere nuove richieste di login.

Uso una sorta di shell per mandare i comandi al server, il server si occupa di fare il parsing della stringa che invio per decidere cosa fare. Posso ricevere la lista degli utenti registrati con i rispettivi file condivisi, posso condividere uno o più file già presenti nella mia cartella, posso connettermi a un utente solamente digitando il suo username oppure uscire dal programma killando il gruppo di processi di appartenenza.

Ogni client salva nella propria cartella la lista dei file condivisi e ogni volta che aggiungerà un file a questa lista. Dato che il server possiede la lista di file condivisi da ciascun client, a ogni nuova modifica, entrambi i file verranno aggiornati, sia in locale sia in remoto.

Il client si collega ad altri client con TCP per scaricare file, c’è un processo che ascolta le connessioni in arrivo su una socket di comunicazione (usercommsockfd) che, all’arrivo di una connessione, farà una fork affidando al figlio il compito di gestire la connessione con una socket specializzata (transfersockfd). Per trasferire il file dal client B al client A, il client B inserisce tutto il file stringa per stringa dentro un buffer di dimensione DIM e poi invia tutto il buffer al client A, che ricopierà il contenuto su un nuovo file che ha lo stesso nome del file richiesto.

Il client in tutto genera un massimo di 4 processi.
Il processo principale si occupa solamente del login dell'utente.
Dopo la fork, si vengono a creare due processi: il padre si occupa della comunicazione UDP con il server, per mandare comandi e ricevere output sulla socket srvcommsockfd, nonché di inviare con il protocollo TCP le richieste di download dei file ai client tramite la socket transfersockfd, invece il figlio si occupa di gestire la comunicazione TCP e a sua volta si sdoppia, lasciando al padre il compito di restare in ascolto sulla socket usercommsockfd e al proprio figlio il compito di gestire la connessione TCP effettiva.

SERVER
Il server usa una socket per il login (sockfd) e una per comunicare con l’utente e quindi ricevere comandi e inviarne l’output (commsockfd). Inizialmente era prevista una socket per pingare la lista degli utenti registrati (pingsockfd), ma per mancanza di tempo il meccanismo di ping è stato male implementato e quindi rimosso (la socket predisposta è ancora presente nel codice). L'idea di base era quella di pingare ogni client richiedendo la sua lista di file condivisi che, se non ricevuta, avrebbe fatto capire al server che il client fosse offline, tuttavia l'idea definitiva sulla gestione dei file condivisi è risultata più semplice da capire e da implementare e quindi non permetteva di applicare questo ragionamento, o comunque non era semplice implementarlo con il poco tempo rimasto.

Il server fa il parsing della stringa e manda l’output dei comandi richiesti dal client. Il server stampa a schermo dei messaggi di debug per capire chi ha fatto il login/signup e l’ultimo comando ricevuto Il server mantiene le liste dei file condivisi dagli utenti tramite dei file di testo che hanno lo stesso nome dell’username del client proprietario della lista.

Il server comunica con i client solo tramite protocollo UDP.

Il server genera un massimo di 3 processi.
Il processo principale è quello che resta in background ad ascoltare e soddisfare nuove richieste di login ricevute sulla socket sockfd, leggendo o modificando il file degli utenti registrati.
Il file degli utenti registrati contiene stringhe del tipo <nome> <ip> <porta>\n.
Dopo la fork, il processo padre continua ad assolvere la sua funzione mentre il figlio riceve dai client i comandi e ne fa il parsing per capire cosa fare.
Il figlio a sua volta fa una fork ma solo esso continua a lavorare, in quanto il suo presunto figlio doveva essere quello che si occupava del ping ai client e dell'aggiornamento della lista dei file condivisi.
