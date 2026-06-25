#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>
#include <fcntl.h>
#include <stdio.h>

//tu peut retirer le bloc la si t'en a pas besoin
int open(const char *path, int flags, ...) {
    typedef int (*open_fn)(const char*, int, ...);
    open_fn real_open = dlsym(RTLD_NEXT, "open");

    if (strcmp(path, "/usr/share/42/ft_lock.conf") == 0)
        return real_open("/home/zsonie/.config/time.conf", O_RDONLY);//a modifier avec le chemin absolu

    return real_open(path, flags);
}

FILE *fopen(const char *path, const char *mode) {
    typedef FILE* (*fopen_fn)(const char*, const char*);
    fopen_fn real_fopen = dlsym(RTLD_NEXT, "fopen");

    if (strcmp(path, "/usr/share/42/ft_lock_bkg.jpg") == 0)
        return real_fopen("/home/zsonie/Pictures/Wallpapers/wp7507776-calcifer-wallpapers.jpg", mode);//a modifier avec le chemin absolu

    return real_fopen(path, mode);
}