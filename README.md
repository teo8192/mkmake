# mkmake

(You need a POSIX compilant shell to use some commands in the generated makefile)

This script will generate a Makefile for a C project. Not flawless but does the job. 
You need a '.targets' file. A line starting with 'target' is the formula for an executable. 
A line beginning with 'flags' is the flags for compiling.
A line beginning with 'clean' is custom files when you call 'make clean'

## Example .targets file

```
target app main.c common.c
target app2 main2.c common.c
clean *.0
flags -lm
```

The makefile generated by this will generate two executables, app and app2.
