#!/bin/bash

# Assemble the main.asm file
rgbasm -o main.o main.asm

# Link the object file to create the Game Boy ROM
rgblink -o spiel.gb main.o

# Fix the ROM header
rgbfix -v -p 0xFF spiel.gb

