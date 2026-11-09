/*
 * lockbg.c — custom background for 42's ft_lock (LD_PRELOAD)
 *
 * Only swaps the lock screen image: when ft_lock opens its background
 * (/usr/share/42/ft_lock_bkg.jpg), open ~/.config/bspwm/lock-wallpaper.jpg
 * instead, if it exists. Set it from Rice Settings > Lock; delete it to get
 * 42's default image back. ft_lock's own config is left untouched.
 *
 * Build: gcc -shared -fPIC -o /tmp/lockbg.so lockbg.c -ldl
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FT_LOCK_BKG "/usr/share/42/ft_lock_bkg.jpg"
#define LOCK_WALL   "/.config/bspwm/lock-wallpaper.jpg"

FILE *fopen(const char *path, const char *mode) {
    typedef FILE *(*fopen_fn)(const char *, const char *);
    static fopen_fn real_fopen;
    if (!real_fopen)
        real_fopen = (fopen_fn)dlsym(RTLD_NEXT, "fopen");

    if (path && strcmp(path, FT_LOCK_BKG) == 0) {
        const char *home = getenv("HOME");
        char custom[4096];
        if (home && snprintf(custom, sizeof custom, "%s%s", home, LOCK_WALL) < (int)sizeof custom) {
            FILE *f = real_fopen(custom, mode);
            if (f)
                return f;
        }
    }
    return real_fopen(path, mode);
}
