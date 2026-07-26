#include <windows.h>

#define KERTEX_MAX_COMMAND_LINE 32768
#define KERTEX_MAX_ARGUMENTS 4096

int main(int argc, char **argv);

static char command_line[KERTEX_MAX_COMMAND_LINE];
static char *arguments[KERTEX_MAX_ARGUMENTS];

static int parse_command_line(const char *source)
{
    char *destination = command_line;
    int count = 0;
    while (*source != '\0') {
        int quoted = 0;
        while (*source == ' ' || *source == '\t') source++;
        if (*source == '\0' || count + 1 >= KERTEX_MAX_ARGUMENTS) break;
        arguments[count++] = destination;
        while (*source != '\0') {
            unsigned int slashes = 0;
            while (*source == '\\') { slashes++; source++; }
            if (*source == '"') {
                while (slashes >= 2) { *destination++ = '\\'; slashes -= 2; }
                if (slashes == 1) { *destination++ = '"'; source++; }
                else { quoted = !quoted; source++; }
                continue;
            }
            while (slashes-- > 0) *destination++ = '\\';
            if (*source == '\0' || (!quoted && (*source == ' ' || *source == '\t'))) break;
            *destination++ = *source++;
        }
        *destination++ = '\0';
    }
    arguments[count] = 0;
    return count;
}

void _start(void)
{
    ExitProcess((UINT)main(parse_command_line(GetCommandLineA()), arguments));
}
