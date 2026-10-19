/*
 * gem5_system_shim.c
 *
 * LD_PRELOAD shim for binaries run under gem5 syscall-emulation (SE) mode.
 *
 * gem5 SE mode does not implement fork()/execve() of arbitrary host
 * programs, so any call to the C library's system() crashes the simulated
 * process. BioDynaMo calls system("mkdir -p <dir>") during initialization
 * to create its output directories. This shim overrides system() and
 * special-cases that one call pattern, creating the requested directory
 * tree with direct mkdir() calls instead of shelling out.
 *
 * Any other command passed to system() cannot be honored under SE mode
 * (there is no shell to exec); the shim logs a warning and returns 0
 * rather than crashing the simulation.
 *
 * Build:
 *   gcc -shared -fPIC -o gem5_system_shim.so 03-biodynamo-system-shim.c
 *
 * Use:
 *   LD_PRELOAD=/path/to/gem5_system_shim.so <target-binary> [args...]
 */

#define _GNU_SOURCE

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

#define SHIM_PATH_MAX 4096
#define MKDIR_P_PREFIX "mkdir -p "

/* Recursively create `path` and any missing parent directories,
 * equivalent to `mkdir -p path`. */
static int
mkdir_p(const char *path)
{
    char tmp[SHIM_PATH_MAX];
    size_t len;
    char *p;

    len = strlen(path);
    if (len == 0 || len >= sizeof(tmp))
        return -1;

    memcpy(tmp, path, len + 1);
    if (tmp[len - 1] == '/')
        tmp[len - 1] = '\0';

    for (p = tmp + 1; *p; p++) {
        if (*p != '/')
            continue;
        *p = '\0';
        if (mkdir(tmp, 0755) != 0 && errno != EEXIST)
            return -1;
        *p = '/';
    }

    if (mkdir(tmp, 0755) != 0 && errno != EEXIST)
        return -1;

    return 0;
}

int
system(const char *command)
{
    if (command == NULL)
        return 0;

    if (strncmp(command, MKDIR_P_PREFIX, strlen(MKDIR_P_PREFIX)) == 0) {
        char args[SHIM_PATH_MAX];
        const char *rest = command + strlen(MKDIR_P_PREFIX);
        char *dir, *saveptr = NULL;
        int rc = 0;

        if (strlen(rest) >= sizeof(args)) {
            fprintf(stderr, "[gem5_system_shim] mkdir -p argument too "
                            "long, ignoring: %s\n", command);
            return -1;
        }
        memcpy(args, rest, strlen(rest) + 1);

        dir = strtok_r(args, " \t", &saveptr);
        while (dir != NULL) {
            if (mkdir_p(dir) != 0) {
                fprintf(stderr, "[gem5_system_shim] mkdir -p '%s' "
                                "failed: %s\n", dir, strerror(errno));
                rc = -1;
            }
            dir = strtok_r(NULL, " \t", &saveptr);
        }
        return rc;
    }

    fprintf(stderr,
            "[gem5_system_shim] warning: system(\"%s\") is not supported "
            "under gem5 SE mode (no fork/exec of a shell); ignoring.\n",
            command);
    return 0;
}
