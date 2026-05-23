#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>
#include <fcntl.h>
#include <stdio.h>

FILE *fopen(const char *path, const char *mode) {
    typedef FILE* (*fopen_fn)(const char*, const char*);
    fopen_fn real_fopen = dlsym(RTLD_NEXT, "fopen");

    if (strcmp(path, "/usr/share/42/ft_lock_bkg.jpg") == 0)
        return real_fopen("/home/zsonie/Pictures/Wallpapers/wp7507776-calcifer-wallpapers.jpg", mode);

    return real_fopen(path, mode);
}
