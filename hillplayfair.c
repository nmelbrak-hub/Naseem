/*
Assignment:
hillplayfair - Hill cipher followed by Playfair cipher
Author: Naseem Elbrak
Language: C, C++, or Rust (only)
To Compile:
gcc -O2 -std=c11 -o hillplayfair hillplayfair.c
g++ -O2 -std=c++17 -o hillplayfair hillplayfair.cpp
rustc -O hillplayfair.rs -o hillplayfair
To Execute (on Eustis):
./hillplayfair encrypt key.txt plain.txt keyword.txt
where:
key.txt = key matrix file
plain.txt = plaintext file
keyword.txt = Playfair keyword file
Notes:
- Input is text; process A-Z only (case-insensitive).
- Tested on Eustis.
Class: CIS3360 - Security in Computing - Spring 2026
Instructor: Dr. Jie Lin
Due Date: February 16th 2026
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

void wrap_print(const char *text) {
    int len = strlen(text);
    for (int i = 0; i < len; i++) {
        printf("%c", text[i]);
        if ((i + 1) % 80 == 0 && (i + 1) != len) printf("\n");
    }
    printf("\n");
}

char* read_entire_file(const char *filename) {
    FILE *f = fopen(filename, "r");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = malloc(size + 1);
    if (buf) {
        size_t n = fread(buf, 1, size, f);
        buf[n] = '\0';
    }
    fclose(f);
    return buf;
}

void sanitize_keyword(char *key) {
    int used[26] = {0};
    int write_idx = 0;
    for (int i = 0; key[i]; i++) {
        char c = toupper(key[i]);
        if (isalpha(c)) {
            if (c == 'J') c = 'I';
            if (!used[c - 'A']) {
                key[write_idx++] = c;
                used[c - 'A'] = 1;
            }
        }
    }
    key[write_idx] = '\0';
}

void hill_encrypt(int n, int **matrix, char *text) {
    int len = strlen(text);
    for (int i = 0; i < len; i += n) {
        int temp[n], res[n];
        for (int j = 0; j < n; j++) temp[j] = text[i + j] - 'A';
        for (int j = 0; j < n; j++) {
            int sum = 0;
            for (int k = 0; k < n; k++) sum += matrix[j][k] * temp[k];
            res[j] = (sum % 26) + 'A';
        }
        for (int j = 0; j < n; j++) text[i + j] = (char)res[j];
    }
}

void build_table(const char *key, char table[5][5]) {
    int used[26] = {0};
    used['J' - 'A'] = 1; 
    int r = 0, c = 0;
    for (int i = 0; key[i]; i++) {
        if (!used[key[i] - 'A']) {
            table[r][c++] = key[i];
            used[key[i] - 'A'] = 1;
            if (c == 5) { c = 0; r++; }
        }
    }
    for (int i = 0; i < 26; i++) {
        if (!used[i]) {
            table[r][c++] = (char)(i + 'A');
            used[i] = 1;
            if (c == 5) { c = 0; r++; }
        }
    }
}

char* playfair_preprocess(const char *input) {
    int len = strlen(input);
    char *res = malloc(len * 2 + 1);
    int i = 0, j = 0;
    while (i < len) {
        char a = input[i];
        if (a == 'J') a = 'I';
        res[j++] = a;
        if (i + 1 < len) {
            char b = input[i+1];
            if (b == 'J') b = 'I';
            if (a == b) {
                res[j++] = 'X';
                i++;
            } else {
                res[j++] = b;
                i += 2;
            }
        } else {
            res[j++] = 'X';
            i++;
        }
    }
    res[j] = '\0';
    return res;
}

void playfair_encrypt(char *text, char table[5][5]) {
    int len = strlen(text);
    for (int k = 0; k < len; k += 2) {
        int r1, c1, r2, c2;
        for (int r = 0; r < 5; r++) {
            for (int c = 0; c < 5; c++) {
                if (table[r][c] == text[k]) { r1 = r; c1 = c; }
                if (table[r][c] == text[k+1]) { r2 = r; c2 = c; }
            }
        }
        if (r1 == r2) {
            text[k] = table[r1][(c1 + 1) % 5];
            text[k+1] = table[r2][(c2 + 1) % 5];
        } else if (c1 == c2) {
            text[k] = table[(r1 + 1) % 5][c1];
            text[k+1] = table[(r2 + 1) % 5][c2];
        } else {
            text[k] = table[r1][c2];
            text[k+1] = table[r2][c1];
        }
    }
}

int main(int argc, char *argv[]) {
    if (argc != 5) return 0;
    FILE *kf = fopen(argv[2], "r");
    char *raw_plain = read_entire_file(argv[3]);
    char *keyword_raw = read_entire_file(argv[4]);
    if (!kf || !raw_plain || !keyword_raw) return 0;

    int n;
    fscanf(kf, "%d", &n);
    int **matrix = malloc(n * sizeof(int *));
    for (int i = 0; i < n; i++) {
        matrix[i] = malloc(n * sizeof(int));
        for (int j = 0; j < n; j++) fscanf(kf, "%d", &matrix[i][j]);
    }

    printf("Mode:\nEncryption Mode\n\n");
    printf("Original Plaintext:\n%s\n", raw_plain); 

    char *hill_input = malloc(strlen(raw_plain) * 2 + n + 10);
    int h_idx = 0;
    for (int i = 0; raw_plain[i]; i++) {
        if (isalpha(raw_plain[i])) hill_input[h_idx++] = toupper(raw_plain[i]);
    }
    hill_input[h_idx] = '\0';

    printf("\nPreprocessed Plaintext:\n"); 
    wrap_print(hill_input); 

    printf("\nHill Cipher Key Dimension:\n%d\n\n", n);
    printf("Hill Cipher Key Matrix:\n");
    for (int i = 0; i < n; i++) {
        printf("   "); // The 3-space lead-in
        for (int j = 0; j < n; j++) {
            printf("%d%s", matrix[i][j], (j == n - 1 ? "" : "   "));
        }
        printf("\n");
    }
    printf("\n");

    while (strlen(hill_input) % n != 0) {
        hill_input[h_idx++] = 'X';
        hill_input[h_idx] = '\0';
    }
    printf("Padded Hill Cipher Plaintext:\n"); 
    wrap_print(hill_input); 

    hill_encrypt(n, matrix, hill_input);
    printf("\nCiphertext after Hill Cipher:\n"); 
    wrap_print(hill_input); 

    sanitize_keyword(keyword_raw);
    char pf_table[5][5];
    build_table(keyword_raw, pf_table);
    printf("\nPlayfair Keyword:\n%s\n\n", keyword_raw);
    printf("Playfair Table:\n");
    for (int i = 0; i < 5; i++) {
        for (int j = 0; j < 5; j++) printf("%c%c", pf_table[i][j], (j == 4 ? '\n' : ' '));
    }
    printf("\n");

    char *pf_input = playfair_preprocess(hill_input);
    playfair_encrypt(pf_input, pf_table);

    printf("Ciphertext after Playfair:\n");
    wrap_print(pf_input);

    free(pf_input); free(raw_plain); free(hill_input); free(keyword_raw);
    for(int i=0; i<n; i++) free(matrix[i]); free(matrix);
    fclose(kf);
    return 0;
}