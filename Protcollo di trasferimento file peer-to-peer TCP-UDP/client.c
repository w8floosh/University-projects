#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <errno.h>
#include <signal.h>

#define DIM 1024

int main(int argc, char* argv[]){
    int srvcommsockfd, usercommsockfd, transfersockfd, num;
    extern int errno;
    struct sockaddr_in local_addr={0}, remote_server_addr={0}, remote_client_addr={0};
    socklen_t len = sizeof(struct sockaddr_in);
    char sendline[DIM];
    char receiveline[DIM];
    char filename[DIM];
    char checkfile[DIM];
    char sendfile[DIM];
    char recvfile[DIM];
    char remoteuser[DIM];
    char remoteip[DIM];
    char remoteport[DIM];
    char* tokbuf;
    FILE* sharedfiles;
    FILE* filetosend;
    FILE* filereceived;

    if (argc != 5){                                         // uso corretto del programma
        fprintf(stderr, "Use: username remote_ip listening_port dest_port\n");
        exit(1);
    }
    if ((srvcommsockfd=socket(AF_INET, SOCK_DGRAM, 0)) < 0){       // creo la socket UDP per inviare e ricevere messaggi
        fprintf(stderr, "Error in opening socket. Exiting program\n");
        exit(2);
    }
    memset(&remote_server_addr, 0, len);
    remote_server_addr.sin_family = AF_INET;
    inet_pton(AF_INET, argv[2], &(remote_server_addr.sin_addr));
    remote_server_addr.sin_port=htons(atoi(argv[4]));
    system("clear");
    // inizio del login
    printf("\nLogging in as %s...\n", argv[1]);      // uso il primo parametro del comando iniziale per mandare il mio username al server
    strncpy(sendline, "\0", DIM);
    strcpy(sendline, argv[1]);
    strcat(sendline, " ");
    // invio porta di ascolto
    strcat(sendline, argv[3]);
    strcat(sendline, "\0");
    sendto(srvcommsockfd, sendline, strlen(sendline), 0, (struct sockaddr*) &remote_server_addr, len);
    strncpy(sendline, "\0", DIM);
    // ricevo la conferma del login
    struct timeval timeout;
    timeout.tv_sec = 2;
    timeout.tv_usec = 0;
    if (setsockopt(srvcommsockfd, SOL_SOCKET, SO_RCVTIMEO, (char*)&timeout,  sizeof(timeout)) < 0)
        fprintf(stderr, "Failed setting timeout to socket\n");
    num = recvfrom(srvcommsockfd, receiveline, DIM-1, 0, (struct sockaddr*) &remote_server_addr, &len);
    receiveline[num]='\0';
    if (num == -1){
        fprintf(stderr, "Cannot connect to the server. Exiting program...\n");
        killpg(0, SIGKILL);
    }
    timeout.tv_sec = 0;
    timeout.tv_usec = 0;
    if (setsockopt(srvcommsockfd, SOL_SOCKET, SO_RCVTIMEO, (char*)&timeout, sizeof(timeout)) < 0)
        fprintf(stderr, "Failed setting timeout to socket\n");
    printf("%s\n", receiveline);
    if (strcmp(receiveline, "You are not registered yet. Signing up...\n")==0){    // se non sono registrato, aspetto la conferma di registrazione
        strncpy(receiveline, "\0", DIM);
        num = recvfrom(srvcommsockfd, receiveline, DIM-1, 0, (struct sockaddr*) &remote_server_addr, &len);
        receiveline[num]='\0';
        printf("%s\n", receiveline);
        strncpy(receiveline, "\0", DIM);
    }
    // fine del login

    // controllo se esistono file in condivisione
    printf("Checking for currently shared files...\n");
    if ((sharedfiles = fopen("sharedfiles.txt", "r"))!=NULL)    fclose(sharedfiles);
    else fprintf(stderr, "You are not sharing any file.\n");
    
    /*while(1){               // questo while mantiene aperta la comunicazione col server per rispondere al ping con la lista dei file condivisi
        num = recvfrom(srvcommsockfd, receiveline, DIM-1, 0, (struct sockaddr*) &remote_server_addr, &len);
        receiveline[num]='\0';
        printf("num: %d, %s\n", num, receiveline);
        strncpy(receiveline, "\0", DIM);
        printf("Sending shared files list to server...\n");
        filetosend = fopen("sharedfiles.txt", "r");
        strncpy(sendline, "\0", DIM);
        strncpy(sendfile, "\0", DIM);
        while(fgets(sendline, DIM, filetosend)!=NULL){
            sendline[strlen(sendline)]='\0';
            if (sendfile[0]='\0')   strcpy(sendfile, sendline);
            else                    strcat(sendfile, sendline);
        }
        printf("Sending\n");
        sendto(srvcommsockfd, sendfile, strlen(sendfile), 0, (struct sockaddr*) &remote_server_addr, len);
    }*/




    // riservo la porta argv[4] solo alle operazioni di login e ping, la comunicazione avviene attraverso la porta successiva
    remote_server_addr.sin_port=htons(atoi(argv[4])+1); 

    // con la fork creo due processi
    // il padre si occupa di comunicare col server con protocollo UDP e manda richieste di download ai client con protocollo TCP
    if (fork()){
        while(1){
            sleep(3);
            system("clear");
            printf("1. type 'registered' to see the list of registered users and their shared files");
            printf("\n2. type an existing username to get his IP and TCP port");
            printf("\n3. type 'share' to share a new file (the file must exist)");
            printf("\n4. type 'quit' to exit program\n");
            fflush(stdout);
            fflush(stdin);
            strncpy(sendline, "\0", DIM);
            while (scanf("%s", sendline) > 0){
                sendline[strlen(sendline)]='\0';
                if(strcmp(sendline, "share")==0){
                    int shared=0;
                    printf("\nWhich file do you want to share?\n");
                    strncpy(filename, "\0", DIM);
                    fscanf(stdin, "%s", filename);
                    filename[strlen(filename)]='\0';
                    if (fopen(filename, "r")==NULL){
                        fprintf(stderr, "\nCannot find file %s, make sure it does exist and try again\n\n\n", filename);
                        strncpy(filename, "\0", DIM);
                        strncpy(sendline, "\0", DIM);
                        break;
                    }
                    else{
                        if ((sharedfiles = fopen("sharedfiles.txt", "r"))==NULL)
                            sharedfiles = fopen("sharedfiles.txt", "a");
                        strncpy(checkfile, "\0", DIM);
                        while(fgets(checkfile, DIM, sharedfiles) != NULL){
                            checkfile[strlen(checkfile)-1]='\0';
                            if (strcmp(checkfile, filename)==0){
                                fprintf(stderr, "\nFile is already shared. Type another file\n\n\n");
                                shared=1;
                                break;
                            }
                            strncpy(checkfile, "\0", DIM);
                        }
                        if (shared) break;
                        strcat(sendline, " ");
                        strcat(sendline, filename);
                        sharedfiles = fopen("sharedfiles.txt", "a");
                        fputs(filename, sharedfiles);
                        fputs("\n", sharedfiles);
                        fflush(sharedfiles);
                        fclose(sharedfiles);
                        strncpy(filename, "\0", DIM);
                        sendto(srvcommsockfd, sendline, strlen(sendline), 0, (struct sockaddr*) &remote_server_addr, len);
                        strncpy(sendline, "\0", DIM);
                        num = recvfrom(srvcommsockfd, receiveline, DIM-1, 0, (struct sockaddr*) &remote_server_addr, &len);
                        receiveline[num]='\0';
                        printf("%s\n", receiveline);
                        strncpy(receiveline, "\0", DIM);
                        break;
                    }
                }
                else if (strcmp(sendline, "registered")==0){            // se ho inviato il comando "registered" il server si sarà occupato di scrivere la lista e inviarmela tramite receiveline
                    sendto(srvcommsockfd, sendline, strlen(sendline), 0, (struct sockaddr*) &remote_server_addr, len);
                    strncpy(receiveline, "\0", DIM);
                    num = recvfrom(srvcommsockfd, receiveline, DIM-1, 0, (struct sockaddr*) &remote_server_addr, &len);
                    printf("%s\n", receiveline);
                    strncpy(receiveline, "\0", DIM);
                    break;
                }
                else if (strcmp(sendline, "quit")==0){
                    killpg(0, SIGKILL);
                }
                else{                                           // in caso contrario avrò ricevuto IP e porta TCP, che vanno divise tramite la funzione strtok() e inserite nella socket
                    sendto(srvcommsockfd, sendline, strlen(sendline), 0, (struct sockaddr*) &remote_server_addr, len);
                    sendline[strcspn(sendline, "\n")]='\0';
                    strncpy(remoteuser, "\0", DIM);
                    strcpy(remoteuser, sendline);               // conservo però l'username di cui sto richiedendo i dati di rete e trasporto
                    remoteuser[strcspn(remoteuser, "\n")]='\0';
                    strncpy(sendline, "\0", DIM);
                    num = recvfrom(srvcommsockfd, receiveline, DIM-1, 0, (struct sockaddr*) &remote_server_addr, &len); // ricevo ip e porta
                    receiveline[num]='\0';
                    memset(&remote_client_addr, 0, len);
                    remote_client_addr.sin_family = AF_INET;
                    tokbuf = strtok(receiveline, " ");
                    strncpy(remoteip, "\0", DIM);
                    strcpy(remoteip, tokbuf);
                    tokbuf = strtok(NULL, "\n");
                    strncpy(remoteport, "\0", DIM);
                    strcpy(remoteport, tokbuf);
                    inet_pton(AF_INET, remoteip, &remote_client_addr.sin_addr);
                    remote_client_addr.sin_port=htons(atoi(remoteport));
                    printf("\n%s IP: %s, %s port: %s.\nAttempting to connect...\n", remoteuser, remoteip, remoteuser, remoteport);
                    strncpy(receiveline, "\0", DIM);
                    // chiedo di ricevere la lista dei file condivisi

                    num = recvfrom(srvcommsockfd, receiveline, DIM-1, 0, (struct sockaddr*) &remote_server_addr, &len); // ricevo i file condivisi
                    receiveline[num]='\0';
                    char errorstring[DIM];
                    sprintf(errorstring, "%s is not sharing any file. Aborting connection...\n", remoteuser);
                    if (strcmp(receiveline, errorstring)==0){
                        fprintf(stderr, receiveline);
                        break;
                    }

                    if ((transfersockfd=socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0){
                        fprintf(stderr, "Error in opening socket. Exiting program\n");
                        exit(2);
                    }

                    memset(&remote_client_addr, 0, sizeof(local_addr));
                    remote_client_addr.sin_family = AF_INET;
                    remote_client_addr.sin_addr.s_addr = inet_addr(remoteip);
                    remote_client_addr.sin_port = htons(atoi(remoteport));
                    int connected;
                    while(1){
                        if ((connected = connect(transfersockfd, (struct sockaddr*) &remote_client_addr, sizeof(remote_client_addr)))==0){
                            while(connected==0){
                                printf("\nAttempting connection to %s (%s:%s)...\n", remoteuser, remoteip, remoteport);
                                sleep(1);
                                printf("\nShared files:\n%s\n\nConnected to %s. Which file do you want to download?\n", receiveline, remoteuser);
                                scanf("%s", filename);
                                char receivedlist[DIM];
                                strcpy (receivedlist, receiveline);
                                char* chosenfile = strtok(receivedlist, "\n");
                                int found=0;
                                while (chosenfile!=NULL && !found){
                                    if (strcmp(chosenfile, filename) == 0){
                                        found=1;
                                        send(transfersockfd, filename, strlen(filename), 0);
                                        printf("\nDownloading %s from %s...\n", filename, remoteuser);
                                        filereceived = fopen(filename, "a");
                                        while(num = recv(transfersockfd, recvfile, DIM-1, 0)){
                                            recvfile[num]='\0';
                                            fputs(recvfile, filereceived);
                                            strncpy(recvfile, "\0", DIM);
                                        }
                                        fflush(filereceived);
                                        fclose(filereceived);
                                        printf("\nFile %s downloaded from %s (%s:%d) \n", filename, remoteuser, inet_ntoa(remote_client_addr.sin_addr), ntohs(remote_client_addr.sin_port));
                                        strncpy(remoteuser, "\0", DIM);
                                        strncpy(filename, "\0", DIM);
                                        break;
                                    }
                                    chosenfile = strtok(NULL, "\n");
                                }
                                if (!found){
                                    fprintf(stderr, "That file isn't being shared. Please choose another file\n");
                                    continue;
                                }
                                else break;
                            }
                            break;
                        }
                    }
                    close(transfersockfd);
                }
                break;
            }
        }
    }
    else{               // il figlio ascolta continuamente le connessioni TCP in arrivo
        close(srvcommsockfd);
        if ((usercommsockfd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0){      // creo la socket TCP
            fprintf(stderr, "Error in opening socket. Exiting program\n");
            exit(2);
        }
        // inizio a preparare i dati da inserire nella socket
        memset(&local_addr, 0, sizeof(local_addr));
        local_addr.sin_family = AF_INET;
        local_addr.sin_port = htons(atoi(argv[3])); // argv[3] è la porta di ascolto

        if (bind(usercommsockfd, (struct sockaddr*) &local_addr, sizeof(local_addr)) < 0){
            fprintf(stderr, "Error in binding socket. Exiting program\n");
            perror("e che è successo?");
            exit(3);
        }
        // inizio a creare la connessione tcp

        listen(usercommsockfd, 1);
        while(1){
            len = sizeof(remote_client_addr);
            transfersockfd = accept(usercommsockfd, (struct sockaddr*) &remote_client_addr, &len);
            printf("\nIncoming connection from %s:%d!\n", inet_ntoa(remote_client_addr.sin_addr), ntohs(remote_client_addr.sin_port));
            // ho stabilito la connessione tcp
            if (!fork()){
                close(usercommsockfd);
                num = recv(transfersockfd, filename, DIM-1, 0);
                filename[num]='\0';
                printf("\n%s:%d is downloading your file '%s'...\n", inet_ntoa(remote_client_addr.sin_addr), ntohs(remote_client_addr.sin_port), filename);
                filetosend = fopen(filename, "r");
                while(fgets(sendfile, DIM, filetosend) != NULL){
                    send(transfersockfd, sendfile, strlen(sendfile), 0);
                    strncpy(sendfile, "\0", DIM);
                }
                printf("%s:%d downloaded your file '%s'\n", inet_ntoa(remote_client_addr.sin_addr), ntohs(remote_client_addr.sin_port), filename);
                close(transfersockfd);
                break;
            }
            else close(transfersockfd);
        }
    }
}