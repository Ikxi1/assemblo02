rgbasm -o main.o main.asm
rgblink -o game.gb main.o
rgbfix -v -p 0xFF game.gb
