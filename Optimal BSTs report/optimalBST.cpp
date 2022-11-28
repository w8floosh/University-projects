#include <iostream>
#include <fstream>
#include <cmath>
#include <limits>
#include <unistd.h>
using namespace std;

template<class T>class Node{
    private:
        T key;
        Node<T>* left;
        Node<T>* right;
        Node<T>* p;
        float prob;                         // probabilità di estrazione nella search
    public:
        Node(T k, float p){
            key = k;
            left = right = NULL;
            prob = p;
        }
        Node<T>* getLeft()              { return left;      }
        void setLeft(Node<T>* l)        { left = l;         }
        Node<T>* getRight()             { return right;     }
        void setRight(Node<T>* r)       { right = r;        }
        Node<T>* getParent()            { return p;         }
        void setParent(Node<T>* parent) { p = parent;       }
        float getProb()                 { return prob;      }
        T getKey()                      { return key;       }
};

template<class T>class BST{
    private:
        Node<T>* _root;
    public:
        BST(){
            _root = NULL;
        }

        Node<T>* getRoot(){
            return _root;
        }

        void inOrder(Node<T>* p){
            if(p){
                inOrder(p->getLeft());
                cout<<p->getKey()<<endl;
                inOrder(p->getRight());
            }
        }

        void postOrder(Node<T>* p){
            if(p){
                postOrder(p->getLeft());
                postOrder(p->getRight());
                cout<<p->getKey()<<endl;
            }
        }
        
        void preOrder(Node<T>* p){
            if(p){
                cout<<p->getKey()<<endl;
                preOrder(p->getLeft());
                preOrder(p->getRight());
            }
        }

        Node<T>* search(Node<T>* tmp,T x){
            if(tmp == NULL || x == tmp->getKey()){
                return tmp;
            }
            if(x < tmp->getKey()){
                return search(tmp->getLeft(), x);
            }else{
                return search(tmp->getRight(), x);
            }
        }


        void insert(T val, float p){
            Node<T>* nuovo = new Node<T>(val, p);               //nuovo Node istanziato (sarà sempre foglia)
            Node<T>* x = getRoot();                             //assegno a x la _root assoluta
            Node<T>* y = NULL;                                  //variabile d'appoggio, rimane sempre indietro fino a che x è null quindi y punta una foglia
            while(x != NULL){                                   //fino a quando non trovo una foglia
                y = x;                                          //in y sarà presente sempre il padre
                if(val < x->getKey()){
                    x = x->getLeft();                           //se la key da inserire è minore della key del Node puntato da x lo metto a sinistra
                }else{
                    x = x->getRight();                          //se è maggiore a destra
                }
            }
            nuovo->setParent(y);                                //assegno come padre del nuovo Node y, che fino a prima era una foglia
            if(y == NULL){                                      //se quello che faccio è il primo inserimento
                _root = nuovo;   
            }else if(val < y->getKey()){                        //una volta trovata la key, decido se mettere il nuovo Node a sinistra o a destra
                y->setLeft(nuovo);
            }else{
                y->setRight(nuovo);
            }
        }
};

template<class T>class OptimalBST: public BST<T>{
    private:
        float* probK;           // array delle probabilità delle chiavi reali
        float* probD;           // array delle probabilità delle chiavi dummy
        T* keys;                // array di etichette delle chiavi reali
        int dim;                // dimensione orizzontale delle matrici expectedCost e probKDSum
        int n;                  // numero di chiavi reali

        float** expectedCost;   // matrice il cui elemento generico ij è il valore del costo atteso di ricerca dell'optimalBST 
                                // contenente la sequenza di chiavi reali e dummy keys[i,j]

        float** probKDSum;      // matrice il cui elemento generico ij è la sommatoria delle probabilità di estrazione delle chiavi dummy e reali
                                // contenute nella sequenza keys[i,j]

        int** rootTable;        // matrice il cui elemento generico ij è l'indice della radice migliore per la costruzione di un OBST contenente
                                // la sequenza di chiavi reali e dummy keys[i,j]

        float getProbK(int i)                               {   return probK[i];              }
        float getProbD(int i)                               {   return probD[i];              }
        T getKeys(int i)                                    {   return keys[i];               }
        void setExpectedCost(int i, int j, float value)     {   expectedCost[i][j] = value;   }
        float getExpectedCost(int i, int j)                 {   return expectedCost[i][j];    }
        void setProbKDSum(int i, int j, float value)        {   probKDSum[i][j] = value;      }
        float getProbKDSum(int i, int j)                    {   return probKDSum[i][j];       }
        void setRootTable(int i, int j, int index)          {   rootTable[i][j] = index;      }
        int getRootTable(int i, int j)                      {   return rootTable[i][j];       }
        int getDim()                                        {   return dim;                   }

        // La seguente procedura calcola i valori delle matrici expectedCost, probKDSum e rootTable.
        void compute(){      
                                                          // che si troverà nella cella expectedCost[1][n+1];
            float t;                                      // t contiene il valore temporaneo di una cella della matrice expectedCost
            int j;                                        // j è un indice di colonna per lo scorrimento degli array
            for (int i=1; i<= n+1; i++){                  // Scrivo nella diagonale principale i casi base dell'algoritmo, cioè...
                setExpectedCost(i, i-1, getProbD(i-1));   // ...il calcolo del costo degli OBST contenenti la sequenza di chiavi keys[n+1, n]...
                setProbKDSum(i, i-1, getProbD(i-1));      // e la somma delle probabilità delle chiavi keys[n+1, n]     
            }
            for (int l = 1; l <= n+1; l++){               // Questo ciclo visita la k-esima diagonale della matrice expectedCost e probKDSum,
                                                          // dove k è l'indice di colonna del primo elemento della diagonale, a partire dall'alto;
                for (int i = 1; i <= n-l+1; i++){         // Dato che la lunghezza della diagonale decrementa a ogni iterazione del ciclo principale, il limite len-k+1 evita errori
                                                          // di segfault facendo rimanere l'indice di riga dentro i bound, perché len-k+1 sarà sempre minore di len+2;
                    j = i+l-1;
                    setExpectedCost(i, j, numeric_limits<float>::max());                                // Il valore del costo di search atteso e[i,j] viene inizializzato a +INF in attesa del calcolo del valore temporaneo t;
                    setProbKDSum(i, j, getProbKDSum(i, j-1) + getProbK(j) + getProbD(j));               // Viene calcolata la somma delle probabilità delle chiavi dalla i-esima alla j-esima;
                    for (int r = i; r <= j; r++){                                                       // Questo ciclo itera tra gli indici r determinando la chiave di indice r da utilizzare come radice dell'optimal BST
                                                                                                        // contenenti le chiavi dalla i-esima alla j-esima;
                        t = getExpectedCost(i, r-1) + getExpectedCost(r+1, j) + getProbKDSum(i, j);     // Viene calcolato il valore temporaneo del costo e[i,j] e viene controllato se esso è minore del valore contenuto in expectedCost[i][j]
                        if (t < getExpectedCost(i, j)){                                                 // se il valore temporaneo t è minore del valore contenuto in expectedCost[i][j] esso sarà un minimo temporaneo e lo sostituisce,
                            setExpectedCost(i, j, t);                                                   // dato che expectedCost[i][j] contiene il valore minimo del costo atteso di search per l'optimal BST contenente le chiavi dalla i-esima alla j-esima;
                            setRootTable(i, j, r);                                                      // il ciclo salva il valore corrente dell'indice r ogni volta che trova una radice migliore in termini di costo di search atteso;
                                                                                                        // questo valore permette di ricostruire la struttura dell'optimal BST partendo dalla radice migliore
                        }
                    }
                }
            }
        }

        // Questa funzione costruisce un OBST a partire dalla matrice rootTable calcolata dalla funzione compute().

        void build(int** rootTable, int first, int last, int lastRoot, int& dummy){
            usleep(500000);                                                                 
            if (first > last){                                                              // se TRUE ho trovato una chiave fittizia che stampo ma non inserisco nel BST
                cout << "d" << dummy;
                dummy++;                                                                    // mantengo la numerazione delle chiavi dummy, stampandole in ordine di visita
                cout << " is a NULL leaf of " << getKeys(lastRoot) << endl;
                return;
            }

            int optimalRoot = getRootTable(first, last);                                    // inserisco in 3 variabili di supporto l'indice della radice ottimale del BST contenente la sequenza di chiavi keys[first,last]...
            T optimalRootKey = getKeys(optimalRoot);                                        // ...la sua chiave per permettere l'inserimento nel BST...
            float optimalRootProb = getProbK(optimalRoot);                                  // ...e la sua probabilità di estrazione in una ricerca

            if (lastRoot == 0) {                                                            // alla prima chiamata lastRoot è 0, perché partiamo dall'elemento rootTable[1][n]...
                cout << optimalRootKey << " is the root\n";                                 // ...che è la radice dell'OBST
                this->insert(optimalRootKey, optimalRootProb);                              // imposto l'elemento come radice del'OBST
            }

            // se l'indice dell'ultima chiave della sequenza keys[first, last] è minore dell'indice dell'ultima chiave radice...
            else if (last < lastRoot){                                                                            
                cout << optimalRootKey << " is the left child of " << getKeys(lastRoot) << '\n';       // ...quella chiave sarà il suo figlio sinistro...
                this->insert(optimalRootKey, optimalRootProb);                                         // ...e la inserisco nel BST
            }
            else {
                cout << optimalRootKey << " is the right child of " << getKeys(lastRoot) << '\n';       // ...quella chiave sarà il suo figlio destro
                this->insert(optimalRootKey, optimalRootProb);                                          // e la inserisco nel BST
            }
            
            // La funzione viene richiamata per costruire ricorsivamente il sottoalbero sinistro e destro dell'ultimo nodo considerato come radice
            build(rootTable, first, optimalRoot-1, optimalRoot, dummy); 
            build(rootTable, optimalRoot+1, last, optimalRoot, dummy);
        }

    public:
        // Costruttore dell'oggetto OptimalBST
        OptimalBST(T* keys, float* p, float* q, int n){
            this->n = n;
            dim = n+2;
            expectedCost = new float*[dim];
            probKDSum = new float*[dim];
            rootTable = new int*[dim-1];
            for (int i=0; i< dim; i++){
                expectedCost[i] = new float[dim-1];
                probKDSum[i] = new float[dim-1];
            }
            for (int i=0; i< dim-1; i++)   rootTable[i] = new int[dim-1];
            probK = p;
            this->keys = keys;
            probD = q;
        }

        // Questa procedura stampa le tre matrici rootTable, expectedCost, probKDSum
        void printTables(){
            usleep(1000000);
            cout << "ROOT TABLE\n" << endl;
            for (int i=1; i<getDim()-1; i++){
                for (int j=1; j<getDim()-1; j++){
                    cout << getRootTable(i, j) << '\t';
                }
                cout << endl;
            }
            cout << endl;
            usleep(1000000);
            cout << "COST TABLE\n" << endl;
            for (int i=1; i<getDim(); i++){
                for (int j=0; j<getDim()-1; j++){
                    cout << getExpectedCost(i, j) << '\t';
                }
                cout << endl;
            }
            cout << endl;
            usleep(1000000);
            cout << "PROBSUM TABLE\n" << endl;
            for (int i=1; i<getDim(); i++){
                for (int j=0; j<getDim()-1; j++){
                    cout << getProbKDSum(i, j) << '\t';
                }
                cout << endl;
            }
            cout << endl;
        }

        // Questa funzione calcola e costruisce l'OBST a partire dai dati forniti dal costruttore
        void buildOBST(){
            compute();                                // Vengono computate le tre tabelle...
            printTables();                            // vengono stampate le tre tabelle...
            int dummy=0;                              // ...viene inizializzata la variabile contatore dell'indice di chiave dummy...
            build(rootTable, 1, n, 0, dummy);         // ...e viene costruito l'OBST a partire dalla rootTable.
        }

};

int main(){
    ifstream in("input.txt");
    for (int task=1; task<=2; task++){
        cout << "TASK " << task << endl;
        int n;
        in >> n;
        float checksum=0;
        int* keys = new int[n+1];
        float* p = new float[n+1];
        float* q = new float[n+1];
        for (int i=1; i<=n; i++)    in >> keys[i];
        for (int i=1; i<=n; i++){
            in >> p[i];
            checksum+=p[i];
        }
        for (int i=0; i<=n; i++){
            in >> q[i];
            checksum+=q[i];
        }
        if (checksum <= 0.99 || checksum >= 1.01){
            cerr << "La somma delle probabilità non è 100%";
            return 400;
        }
        OptimalBST<int>* OBST = new OptimalBST<int>(keys, p, q, n);
        OBST->buildOBST();
        usleep(500000);
        OBST->preOrder(OBST->getRoot());
        usleep(2000000);
    }
}
