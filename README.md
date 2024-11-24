# assemblo02

use rgbds to make it into a game

``rgbasm -o main.o main.asm``\
``rgblink -o game.gb main.o``\
``rgbfix -v -p 0xFF game.gb``

or run ``./build.sh`` (needs privileges given with ``sudo chmod +x build.sh``)\
(if on termux, keep build.sh in ~/ and then run the command ``~/build.sh`` while in the directory with main.asm)

then launch in any gb emu, i've tried in emulicious and gameroy
