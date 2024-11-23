# assemblo02

use rgbds to make it into a game

rgbasm -o main.o main.asm
rgblink -o game.gb main.o
rgbfix -v -p 0xFF game.gb

then launch in any gb emu, i've tried in emulicious and gameroy
