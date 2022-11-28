#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <time.h>

#define DIM 1000

int main(int argc, char* argv[]){    
    int sockfd, commsockfd, pingsockfd, num;
    struct sockaddr_in local_addr, remote_addr;
    socklen_t len = sizeof(struct sockaddr_in);
    char sendline[DIM];
    char receivemsg[DIM];
    char username[DIM];
    char checkuser[DIM];
    char ip[DIM];
    char port[DIM];
    char filename[DIM];
    char checkfile[DIM];
    FILE* registeredusers;
    FILE* userfile;

    if (argc < 2){
        fprintf(stderr, "Use: listening_port\n");
        exit(1);
    }

    // quando l'utente fa il login, controllo se il suo nome è nella lista degli utenti registrati
    if (fork()){
        if ((sockfd=socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0){
            fprintf(stderr, "Error in socket opening. Exiting program\n");
            exit(1);
        }
        memset(&local_addr, 0, sizeof(local_addr));
        local_addr.sin_family = AF_INET;
        local_addr.sin_port = htons(atoi(argv[1]));

        if (bind(sockfd, (struct sockaddr*)&local_addr, sizeof(local_addr)) < 0){
            printf("prima bind\n");
            fprintf(stderr, "Error in binding socket. Exiting program\n");
            exit(1);
        }

        while(1){
            num = recvfrom(sockfd, receivemsg, DIM-1, 0, (struct sockaddr*) &remote_addr, &len);    // ricevo l'username e la porta
            receivemsg[num]='\0';
            char* entry = strtok(receivemsg, " ");
            strcpy(username, entry);
            entry = strtok(NULL, " ");
            strcpy(port, entry);
            inet_ntop(AF_INET, &remote_addr.sin_addr, ip, len);
            int registered=0;
            registeredusers = fopen("users.txt", "r");
            while(registeredusers!=NULL && fgets(checkuser, DIM, registeredusers)){
                checkuser[strlen(checkuser)-1]='\0';
                char* user = strtok(checkuser, " ");
                if (strcmp(user, username)==0){
                    strcpy(sendline, "You are already registered, welcome back!\n");
                    sendto(sockfd, sendline, strlen(sendline), 0, (struct sockaddr*)&remote_addr, len);
                    printf("User %s (%s:%s) logged in\n", username, ip, port);
                    registered=1;
                    fclose(registeredusers);
                    strncpy(sendline, "\0", DIM);
                    break;
                }
            }
            if (!registered){           // se non è registrato, viene aggiunto alla lista degli utenti registrati
                strcpy(sendline, "You are not registered yet. Signing up...\n");
                sendto(sockfd, sendline, strlen(sendline), 0, (struct sockaddr*)&remote_addr, len);
                printf("User %s registered with IP %s listening on port %s \n", username, ip, port);
                registeredusers = fopen("users.txt", "a");
                fprintf(registeredusers, "%s %s %d\n", username, ip, atoi(port));
                strncpy(username, "\0", DIM);
                strncpy(ip, "\0", DIM);
                strncpy(port, "\0", DIM);
                fflush(registeredusers);   
                fclose(registeredusers);
                strcpy(sendline, "You are now registered, welcome!\n");
                sendto(sockfd, sendline, strlen(sendline), 0, (struct sockaddr*)&remote_addr, len);
                strncpy(sendline, "\0", DIM);
            }
        }
    }
    else{
            // il figlio riceve dai client i comandi per eseguire le sue azioni e invia l'output
            close(sockfd);
            if ((commsockfd=socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0){
                    fprintf(stderr, "Error in socket opening. Exiting program\n");
                    exit(1);
                }
            memset(&local_addr, 0, sizeof(local_addr));
            local_addr.sin_family = AF_INET;
            local_addr.sin_port = htons(atoi(argv[1])+1);

            if (bind(commsockfd, (struct sockaddr*) &local_addr, sizeof(local_addr)) < 0){
                printf("seconda bind\n");
                fprintf(stderr, "Error in binding socket. Exiting program\n");
                exit(1);
            }
            while (1){
                if (fork()){            
                    strncpy(receivemsg, "\0", DIM);
                    num = recvfrom(commsockfd, receivemsg, DIM-1, 0, (struct sockaddr*) &remote_addr, &len);
                    receivemsg[num]='\0';
                    inet_ntop(AF_INET, &(remote_addr.sin_addr), ip, len);
                    printf("Received command from %s: %s\n", ip, receivemsg);
                    char* option;
                    option = strtok(receivemsg, " ");
                    if (strcmp(receivemsg, "registered")==0){ // se viene ricevuto il comando "registered" il server invia la lista degli utenti registrati 
                        printf("Sending list of registered users and shared files...\n");
                        registeredusers = fopen("users.txt", "r");
                        strcpy(sendline, "Registered users:");
                        strcat(sendline, "\n");
                        strncpy(checkuser, "\0", DIM);
                        while(fgets(checkuser, DIM, registeredusers)!=NULL){
                            char* tok = strtok(checkuser, " ");
                            strcat(sendline, checkuser);
                            strncpy(checkfile, "\0", DIM);
                            strcpy(checkfile, tok);
                            strcat(checkfile, ".txt");
                            if ((userfile = fopen(checkfile, "r"))==NULL)
                                strcat(sendline, ", sharing no files");
                            else{
                                strcat(sendline, ", sharing the following files:\n");
                                strncpy(filename, "\0", DIM);
                                while(fgets(filename, DIM, userfile)!=NULL){
                                    filename[strlen(filename)]='\0';
                                    strcat(sendline, filename);
                                    strncpy(filename, "\0", DIM);
                                }
                            }
                            strcat(sendline, "\n");
                        }
                        sendto(commsockfd, sendline, strlen(sendline), 0, (struct sockaddr*)&remote_addr, len);
                        strncpy(sendline, "\0", DIM);
                        fclose(registeredusers);
                    }
                    else if (strcmp(option, "share")==0){   // se riceve il messaggio "share filename" aggiunge alla lista dei file condivisi il file filename
                        option = strtok(NULL, "\n");
                        strncpy(filename, "\0", DIM);
                        strcpy(filename, option);
                        strncpy(checkfile, "\0", DIM);      // compongo il nome della lista di file condivisi dall'utente
                        registeredusers = fopen("users.txt", "r");
                        strncpy(checkuser, "\0", DIM);
                        while(fgets(checkuser, DIM, registeredusers)!=NULL){    // cerco l'username associato all'ip
                            char* tok = strtok(checkuser, " ");
                            strcpy(checkfile, tok);
                            tok = strtok(NULL, " ");
                            if (strcmp(tok, ip)!=0){
                                strncpy(checkfile, "\n", DIM);
                                continue;
                            }
                            else break;
                        }
                        strcat(checkfile, ".txt");
                        userfile = fopen(checkfile, "a");
                        fputs(filename, userfile);
                        fputc('\n', userfile);
                        fflush(userfile);
                        fclose(userfile);
                        printf("New file shared: %s\n", filename);
                        strcpy(sendline, "File shared successfully\n");
                        sendto(commsockfd, sendline, strlen(sendline), 0, (struct sockaddr*)&remote_addr, len);
                        strncpy(sendline, "\0", DIM);
                    }
                    else{                            // se viene ricevuto un altro messaggio, lo cerco tra gli username e mando ip e porta per connettersi
                        registeredusers = fopen("users.txt", "r");
                        int found=0;
                        while(fgets(checkuser, DIM, registeredusers)!=NULL){            // Martin 192.168.56.109 12345
                            char* tok = strtok(checkuser, " ");                         // Martin
                            if (strcmp(tok, receivemsg)==0){
                                found=1;
                                strncpy(filename, "\0", DIM);
                                strcpy(filename, tok);                                 // serve l'username per aprire la lista dei file condivisi a esso associato
                                strcat(filename, ".txt");
                                tok = strtok(NULL, " ");                                // 192.168.56.109
                                strncpy(sendline, "\0", DIM);
                                strcpy(sendline, tok);
                                tok = strtok(NULL, "\n");                               // 12345
                                strcat(sendline, " ");
                                strcat(sendline, tok);
                                sendto(commsockfd, sendline, strlen(sendline), 0, (struct sockaddr*)&remote_addr, len);
                                strncpy(sendline, "\0", DIM);
                                // invio la lista dei file condivisi da quell'utente
                                if ((userfile = fopen(filename, "r"))==NULL){
                                    tok = strtok(checkuser, " ");
                                    sprintf(sendline,"%s is not sharing any file. Aborting connection...\n", tok);
                                    sendto(commsockfd, sendline, strlen(sendline), 0, (struct sockaddr*)&remote_addr, len);
                                    strncpy(sendline, "\0", DIM);
                                }
                                else{
                                    strncpy(filename, "\0", DIM);
                                    while(fgets(filename, DIM, userfile)!=NULL){
                                        if (sendline[0]=='\0')  strcpy(sendline, filename);
                                        else                    strcat(sendline, filename);
                                    }
                                    sendto(commsockfd, sendline, strlen(sendline), 0, (struct sockaddr*)&remote_addr, len);
                                    strncpy(sendline, "\0", DIM);
                                }
                            }
                            strncpy(checkuser, "\0", DIM);
                        }
                        if (!found){
                            strcpy(sendline, "That user seems to be not registered. Type a different username.\n");
                            sendto(commsockfd, sendline, strlen(sendline), 0, (struct sockaddr*)&remote_addr, len);
                            strncpy(sendline, "\0", DIM);
                        }
                    }
                    strcpy(receivemsg, "\0");
                }
                else{                   // il figlio si occupa di verificare periodicamente lo stato dei client
                    /*close(commsockfd);
                    printf("Ping process will start in 30 seconds...\n");
                    sleep(30);
                    if ((pingsockfd=socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0){
                        fprintf(stderr, "Error in socket opening. Exiting program\n");
                        exit(1);
                    }
                    struct timeval timeout;
                    timeout.tv_sec = 30;
                    if (setsockopt(pingsockfd, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout,  sizeof(timeout)) < 0)
                        fprintf(stderr, "Failed setting timeout to socket\n");


                    while(1){
                        printf("Sleeping 30 seconds...\n");
                        sleep(30);
                        registeredusers = fopen("users.txt", "r");
                        strncpy(checkuser, "\0", DIM);
                        while (fgets(checkuser, DIM, registeredusers)!=NULL){
                            memset(&remote_addr, 0, sizeof(remote_addr));
                            remote_addr.sin_family = AF_INET;
                            char* tokbuf = strtok(checkuser, " ");
                            strncpy(filename, "\0", DIM);
                            strcpy(filename, tokbuf);           // conservo l'username per cancellare il file relativo a esso in caso di timeout
                            strcat(filename, ".txt");
                            tokbuf = strtok(NULL, " ");
                            inet_pton(AF_INET, tokbuf, &remote_addr.sin_addr);
                            printf("tokbuf: %s, remote addr: %d\n", tokbuf, remote_addr.sin_addr);
                            tokbuf = strtok(NULL, "\n");
                            remote_addr.sin_port = htons(atoi(tokbuf));
                            printf("tokbuf: %s\n", tokbuf);
                            printf("Pinging %s with 30s timeout...\n", (tokbuf = strtok(checkuser, " ")));
                            strncpy(sendline, "\0", DIM);
                            strcpy(sendline, "request");
                            printf("sending %s to %d:%d\n", sendline, remote_addr.sin_addr, remote_addr.sin_port);
                            sendto(pingsockfd, sendline, strlen(sendline), 0, (struct sockaddr*) &remote_addr, len);
                            num = recvfrom(pingsockfd, receivemsg, DIM-1, 0, (struct sockaddr*) &remote_addr, &len);
                            receivemsg[num]='\0';
                            printf("num: %d\n", num);
                            if (num == -1)              // se il timeout è scaduto, il client è offline
                                printf("%s is currently offline\n", (tokbuf = strtok(checkuser, " ")));                                     
                            else{                       // se vengono ricevuti 0 o più byte la lista dei file condivisi non esiste/è vuota/contiene elementi
                                printf("%s is currently online. Updating shared files list...\n", (tokbuf = strtok(checkuser, " ")));
                                userfile = fopen(filename, "w");
                                fputs(receivemsg, userfile);
                                fflush(userfile);
                                fclose(userfile);
                            }
                            strncpy(filename, "\0", DIM);
                            strncpy(checkuser, "\0", DIM);
                        }
                        fclose(registeredusers);
                    }*/
                }
            }
        }
    }



