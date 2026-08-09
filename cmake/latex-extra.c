/* Dedicated command-line adapter for the Prote-derived LaTeX engine. */
#include <stdlib.h>
#include <string.h>

#define EXTERN
#include "texd.h"

unsigned int cbufsize = bufsize;

void
topenin(void)
{
    if (argc > 0) {
        int i;

        buffer[first] = '\0';
        if (argc < 2 || argv[1][0] != '&')
            (void)strcpy((char *)&buffer[first], "&latex ");

        for (i = 1;
             i < argc && strlen((char *)&buffer[first]) + strlen(argv[i]) + 2 <= bufsize;
             ++i) {
            (void)strcat((char *)&buffer[first], argv[i]);
            (void)strcat((char *)&buffer[first], " ");
        }

        for (last = first; buffer[last]; ++last)
            ;
        for (--last; last >= first && buffer[last] == ' '; --last)
            ;
        ++last;
        argc = 0;
    }
}

void
putfmtint(integer x)
{
    integer value = x;
    (void)fwrite((char *)&value, sizeof(integer), 1, fmtfile);
}
